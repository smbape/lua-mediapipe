#include "mediapipe/framework/port/status_macros.h"
#include "binding/tasks/audio/audio_embedder.h"
#include "binding/packet_getter.h"
#include "binding/packet_creator.h"
#include <opencv2/core/eigen.hpp>

namespace {
	using namespace google::protobuf;
	using namespace mediapipe::lua::packet_creator;
	using namespace mediapipe::lua::packet_getter;
	using namespace mediapipe::tasks::audio::audio_embedder::proto;
	using namespace mediapipe::tasks::lua::audio::core::audio_task_running_mode;
	using namespace mediapipe::tasks::lua::components::containers::audio_data;
	using namespace mediapipe::tasks::lua::components::containers::embedding_result;
	using namespace mediapipe::tasks::lua::components::utils;
	using namespace mediapipe::tasks::lua::core::base_options;
	using namespace mediapipe::tasks::lua::core::task_info;

	using mediapipe::lua::PacketsCallback;
	using mediapipe::tasks::core::PacketMap;

	const std::string _AUDIO_IN_STREAM_NAME = "audio_in";
	const std::string _AUDIO_TAG = "AUDIO";
	const std::string _EMBEDDINGS_STREAM_NAME = "embeddings_out";
	const std::string _EMBEDDINGS_TAG = "EMBEDDINGS";
	const std::string _SAMPLE_RATE_IN_STREAM_NAME = "sample_rate_in";
	const std::string _SAMPLE_RATE_TAG = "SAMPLE_RATE";
	const std::string _TASK_GRAPH_NAME = "mediapipe.tasks.audio.audio_embedder.AudioEmbedderGraph";
	const std::string _TIMESTAMPED_EMBEDDINGS_STREAM_NAME = "timestamped_embeddings_out";
	const std::string _TIMESTAMPED_EMBEDDINGS_TAG = "TIMESTAMPED_EMBEDDINGS";
	const int64_t _MICRO_SECONDS_PER_MILLISECOND = 1000;

	const std::string optional_to_string(const std::optional<float>& v) {
		std::ostringstream ss;
		if (v.has_value()) {
			ss << *v;
		}
		else {
			ss << "None";
		}
		return ss.str();
	}
}

namespace mediapipe::tasks::lua::audio::audio_embedder {
	using EmbeddingResult = mediapipe::tasks::components::containers::proto::EmbeddingResult;

	absl::StatusOr<std::shared_ptr<AudioEmbedderGraphOptions>> AudioEmbedderOptions::to_pb2() const {
		auto pb2_obj = std::make_shared<AudioEmbedderGraphOptions>();

		if (base_options) {
			MP_ASSIGN_OR_RETURN(auto base_options_proto, base_options->to_pb2());
			pb2_obj->mutable_base_options()->CopyFrom(*base_options_proto);
		}
		pb2_obj->mutable_base_options()->set_use_stream_mode(running_mode != AudioTaskRunningMode::AUDIO_CLIPS);
		if (l2_normalize) pb2_obj->mutable_embedder_options()->set_l2_normalize(*l2_normalize);
		if (quantize) pb2_obj->mutable_embedder_options()->set_quantize(*quantize);

		return pb2_obj;
	}

	absl::StatusOr<std::shared_ptr<AudioEmbedder>> AudioEmbedder::create(
		const CalculatorGraphConfig& graph_config,
		AudioTaskRunningMode running_mode,
		mediapipe::lua::PacketsCallback packet_callback
	) {
		using BaseAudioTaskApi = core::base_audio_task_api::BaseAudioTaskApi;
		return BaseAudioTaskApi::create(graph_config, running_mode, std::move(packet_callback), static_cast<AudioEmbedder*>(nullptr));
	}

	absl::StatusOr<std::shared_ptr<AudioEmbedder>> AudioEmbedder::create_from_model_path(const std::string& model_path) {
		auto base_options = std::make_shared<BaseOptions>(model_path);
		return create_from_options(std::make_shared<AudioEmbedderOptions>(base_options, AudioTaskRunningMode::AUDIO_CLIPS));
	}

	absl::StatusOr<std::shared_ptr<AudioEmbedder>> AudioEmbedder::create_from_options(std::shared_ptr<AudioEmbedderOptions> options) {
		PacketsCallback packet_callback = nullptr;

		if (options->result_callback) {
			packet_callback = [options](const PacketMap& output_packets) {
				auto timestamp_ms = output_packets.at(_EMBEDDINGS_STREAM_NAME).Timestamp().Value() / _MICRO_SECONDS_PER_MILLISECOND;

				if (output_packets.at(_EMBEDDINGS_STREAM_NAME).IsEmpty()) {
					options->result_callback(AudioEmbedderResult(), timestamp_ms);
					return;
				}

				MP_PACKET_ASSIGN_OR_THROW(const auto& embedding_result_proto, EmbeddingResult, output_packets.at(_EMBEDDINGS_STREAM_NAME)); // There is no other choice than throw in a callback to stop the execution
				options->result_callback(
					*AudioEmbedderResult::create_from_pb2(embedding_result_proto),
					timestamp_ms
				);
			};
		}

		TaskInfo task_info;
		task_info.task_graph = _TASK_GRAPH_NAME;
		task_info.input_streams = {
			_AUDIO_TAG + ":" + _AUDIO_IN_STREAM_NAME,
			_SAMPLE_RATE_TAG + ":" + _SAMPLE_RATE_IN_STREAM_NAME
		};
		task_info.output_streams = {
			_EMBEDDINGS_TAG + ":" + _EMBEDDINGS_STREAM_NAME,
			_TIMESTAMPED_EMBEDDINGS_TAG + ":" + _TIMESTAMPED_EMBEDDINGS_STREAM_NAME
		};
		MP_ASSIGN_OR_RETURN(task_info.task_options, options->to_pb2());

		MP_ASSIGN_OR_RETURN(auto config, task_info.generate_graph_config(false));

		return create(
			*config,
			options->running_mode,
			std::move(packet_callback)
			);
	}

	absl::Status AudioEmbedder::embed(std::vector<std::shared_ptr<AudioEmbedderResult>>& output_list, const AudioData& audio_clip) {
		MP_ASSERT_RETURN_IF_ERROR(audio_clip.audio_format().sample_rate, "Must provide the audio sample rate in audio data.");
		auto packet = create_matrix(audio_clip.buffer(), true);

		MP_ASSIGN_OR_RETURN(auto output_packets, _process_audio_clip({
			{ _AUDIO_IN_STREAM_NAME, std::move(*std::move(packet)) },
			{ _SAMPLE_RATE_IN_STREAM_NAME, std::move(MakePacket<double>(*audio_clip.audio_format().sample_rate)) },
			}));

		MP_PACKET_ASSIGN_OR_RETURN(const auto& embedding_result_proto_list, std::vector<EmbeddingResult>, output_packets.at(_TIMESTAMPED_EMBEDDINGS_STREAM_NAME));
		for (const auto& embedding_result_proto : embedding_result_proto_list) {
			output_list.push_back(AudioEmbedderResult::create_from_pb2(embedding_result_proto));
		}
	}

	absl::Status AudioEmbedder::embed_async(const AudioData& audio_block, int64_t timestamp_ms) {
		MP_ASSERT_RETURN_IF_ERROR(audio_block.audio_format().sample_rate, "Must provide the audio sample rate in audio data.");
		if (!_default_sample_rate) {
			_default_sample_rate = audio_block.audio_format().sample_rate;
			MP_RETURN_IF_ERROR(_set_sample_rate(_SAMPLE_RATE_IN_STREAM_NAME, *_default_sample_rate));
		}
		else {
			MP_ASSERT_RETURN_IF_ERROR(_default_sample_rate == audio_block.audio_format().sample_rate,
				"The audio sample rate provided in audio data: "
				<< optional_to_string(audio_block.audio_format().sample_rate) << " is inconsistent with "
				"the previously received: " << optional_to_string(_default_sample_rate) << "."
			);
		}

		auto packet = create_matrix(audio_block.buffer(), true);

		return _send_audio_stream_data({
			{ _AUDIO_IN_STREAM_NAME, std::move(std::move(packet)->At(Timestamp(timestamp_ms * _MICRO_SECONDS_PER_MILLISECOND))) }
			});
	}

	absl::StatusOr<float> AudioEmbedder::cosine_similarity(const Embedding& u, const Embedding& v) {
		return cosine_similarity::cosine_similarity(u, v);
	}
}
