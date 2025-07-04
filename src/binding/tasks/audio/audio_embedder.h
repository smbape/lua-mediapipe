#pragma once

#include "mediapipe/tasks/cc/audio/audio_embedder/proto/audio_embedder_graph_options.pb.h"
#include "mediapipe/tasks/cc/components/containers/proto/embeddings.pb.h"
#include "mediapipe/tasks/cc/components/processors/proto/embedder_options.pb.h"
#include "binding/packet.h"
#include "binding/tasks/audio/core/audio_task_running_mode.h"
#include "binding/tasks/audio/core/base_audio_task_api.h"
#include "binding/tasks/components/containers/audio_data.h"
#include "binding/tasks/components/containers/embedding_result.h"
#include "binding/tasks/components/utils/cosine_similarity.h"
#include "binding/tasks/core/base_options.h"
#include "binding/tasks/core/task_info.h"
#include <functional>

namespace mediapipe::tasks::lua::audio::audio_embedder {
	using AudioEmbedderResult = components::containers::embedding_result::EmbeddingResult;
	using AudioEmbedderResultCallback = std::function<void(const AudioEmbedderResult&, int64_t)>;

	struct CV_EXPORTS_W_SIMPLE AudioEmbedderOptions {
		CV_WRAP AudioEmbedderOptions(const AudioEmbedderOptions& other) = default;
		AudioEmbedderOptions& operator=(const AudioEmbedderOptions& other) = default;

		CV_WRAP AudioEmbedderOptions(
			std::shared_ptr<lua::core::base_options::BaseOptions> base_options = std::shared_ptr<lua::core::base_options::BaseOptions>(),
			core::audio_task_running_mode::AudioTaskRunningMode running_mode = tasks::lua::audio::core::audio_task_running_mode::AudioTaskRunningMode::AUDIO_CLIPS,
			const std::optional<bool>& l2_normalize = std::nullopt,
			const std::optional<bool>& quantize = std::nullopt,
			AudioEmbedderResultCallback result_callback = nullptr
		)
			:
			base_options(base_options),
			running_mode(running_mode),
			l2_normalize(l2_normalize),
			quantize(quantize),
			result_callback(result_callback)
		{}

		CV_WRAP [[nodiscard]] absl::StatusOr<std::shared_ptr<mediapipe::tasks::audio::audio_embedder::proto::AudioEmbedderGraphOptions>> to_pb2() const;

		CV_PROP_RW std::shared_ptr<lua::core::base_options::BaseOptions> base_options;
		CV_PROP_RW core::audio_task_running_mode::AudioTaskRunningMode running_mode;
		CV_PROP_RW std::optional<bool> l2_normalize;
		CV_PROP_RW std::optional<bool> quantize;
		CV_PROP_W  AudioEmbedderResultCallback result_callback;
	};

	class CV_EXPORTS_W AudioEmbedder : public ::mediapipe::tasks::lua::audio::core::base_audio_task_api::BaseAudioTaskApi {
	public:
		using core::base_audio_task_api::BaseAudioTaskApi::BaseAudioTaskApi;

		CV_WRAP [[nodiscard]] static absl::StatusOr<std::shared_ptr<AudioEmbedder>> create(
			const CalculatorGraphConfig& graph_config,
			core::audio_task_running_mode::AudioTaskRunningMode running_mode,
			mediapipe::lua::PacketsCallback packet_callback = nullptr
		);
		CV_WRAP [[nodiscard]] static absl::StatusOr<std::shared_ptr<AudioEmbedder>> create_from_model_path(const std::string& model_path);
		CV_WRAP [[nodiscard]] static absl::StatusOr<std::shared_ptr<AudioEmbedder>> create_from_options(std::shared_ptr<AudioEmbedderOptions> options);
		CV_WRAP [[nodiscard]] absl::Status embed(CV_OUT std::vector<std::shared_ptr<AudioEmbedderResult>>& output_list, const components::containers::audio_data::AudioData& audio_clip);
		CV_WRAP [[nodiscard]] absl::Status embed_async(const components::containers::audio_data::AudioData& audio_block, int64_t timestamp_ms);
		CV_WRAP [[nodiscard]] static absl::StatusOr<float> cosine_similarity(const components::containers::embedding_result::Embedding& u, const components::containers::embedding_result::Embedding& v);
	};
}
