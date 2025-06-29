#include "mediapipe/framework/port/status_macros.h"
#include "binding/tasks/vision/image_classifier.h"

namespace {
	using namespace mediapipe::lua::packet_creator;
	using namespace mediapipe::lua::packet_getter;
	using namespace mediapipe::tasks::lua::components::containers::classification_result;
	using namespace mediapipe::tasks::lua::core::base_options;
	using namespace mediapipe::tasks::lua::core::task_info;
	using namespace mediapipe::tasks::lua::vision::core::vision_task_running_mode;
	using namespace mediapipe::tasks::lua::vision::image_classifier;
	using namespace mediapipe::tasks::vision::image_classifier::proto;

	using mediapipe::lua::PacketsCallback;
	using mediapipe::tasks::core::PacketMap;

	const std::string _CLASSIFICATIONS_STREAM_NAME = "classifications_out";
	const std::string _CLASSIFICATIONS_TAG = "CLASSIFICATIONS";
	const std::string _IMAGE_IN_STREAM_NAME = "image_in";
	const std::string _IMAGE_OUT_STREAM_NAME = "image_out";
	const std::string _IMAGE_TAG = "IMAGE";
	const std::string _NORM_RECT_STREAM_NAME = "norm_rect_in";
	const std::string _NORM_RECT_TAG = "NORM_RECT";
	const std::string _TASK_GRAPH_NAME = "mediapipe.tasks.vision.image_classifier.ImageClassifierGraph";
	const int64_t _MICRO_SECONDS_PER_MILLISECOND = 1000;

	[[nodiscard]] absl::StatusOr<std::shared_ptr<ImageClassifierResult>> _build_classification_result(const PacketMap& output_packets) {
		const auto& detector_out_packet = output_packets.at(_CLASSIFICATIONS_STREAM_NAME);
		if (detector_out_packet.IsEmpty()) {
			return std::make_shared<ImageClassifierResult>();
		}

		MP_PACKET_ASSIGN_OR_RETURN(const auto& classification_result_proto, mediapipe::tasks::components::containers::proto::ClassificationResult, output_packets.at(_CLASSIFICATIONS_STREAM_NAME));
		return ImageClassifierResult::create_from_pb2(classification_result_proto);
	}
}

namespace mediapipe::tasks::lua::vision::image_classifier {
	using core::image_processing_options::ImageProcessingOptions;

	absl::StatusOr<std::shared_ptr<ImageClassifierGraphOptions>> ImageClassifierOptions::to_pb2() const {
		auto pb2_obj = std::make_shared<ImageClassifierGraphOptions>();
		if (base_options) {
			MP_ASSIGN_OR_RETURN(auto base_options_proto, base_options->to_pb2());
			pb2_obj->mutable_base_options()->CopyFrom(*base_options_proto);
		}
		pb2_obj->mutable_base_options()->set_use_stream_mode(running_mode != VisionTaskRunningMode::IMAGE);

		if (score_threshold) pb2_obj->mutable_classifier_options()->set_score_threshold(*score_threshold);
		if (!category_allowlist.empty()) pb2_obj->mutable_classifier_options()->mutable_category_allowlist()->Add(category_allowlist.begin(), category_allowlist.end());
		if (!category_denylist.empty()) pb2_obj->mutable_classifier_options()->mutable_category_denylist()->Add(category_denylist.begin(), category_denylist.end());
		if (display_names_locale) pb2_obj->mutable_classifier_options()->set_display_names_locale(*display_names_locale);
		if (max_results) pb2_obj->mutable_classifier_options()->set_max_results(*max_results);

		return pb2_obj;
	}

	absl::StatusOr<std::shared_ptr<ImageClassifier>> ImageClassifier::create(
		const CalculatorGraphConfig& graph_config,
		VisionTaskRunningMode running_mode,
		mediapipe::lua::PacketsCallback packet_callback
	) {
		using BaseVisionTaskApi = core::base_vision_task_api::BaseVisionTaskApi;
		return BaseVisionTaskApi::create(graph_config, running_mode, std::move(packet_callback), static_cast<ImageClassifier*>(nullptr));
	}

	absl::StatusOr<std::shared_ptr<ImageClassifier>> ImageClassifier::create_from_model_path(const std::string& model_path) {
		auto base_options = std::make_shared<BaseOptions>(model_path);
		return create_from_options(std::make_shared<ImageClassifierOptions>(base_options, VisionTaskRunningMode::IMAGE));
	}

	absl::StatusOr<std::shared_ptr<ImageClassifier>> ImageClassifier::create_from_options(std::shared_ptr<ImageClassifierOptions> options) {
		PacketsCallback packet_callback = nullptr;

		if (options->result_callback) {
			packet_callback = [options](const PacketMap& output_packets) {
				const auto& image_out_packet = output_packets.at(_IMAGE_OUT_STREAM_NAME);
				if (image_out_packet.IsEmpty()) {
					return;
				}

				MP_ASSIGN_OR_THROW(auto classification_result, _build_classification_result(output_packets)); // There is no other choice than throw in a callback to stop the execution
				MP_PACKET_ASSIGN_OR_THROW(const auto& image, Image, image_out_packet); // There is no other choice than throw in a callback to stop the execution
				auto timestamp_ms = output_packets.at(_CLASSIFICATIONS_STREAM_NAME).Timestamp().Value() / _MICRO_SECONDS_PER_MILLISECOND;

				options->result_callback(*classification_result, image, timestamp_ms);
			};
		}

		TaskInfo task_info;
		task_info.task_graph = _TASK_GRAPH_NAME;
		task_info.input_streams = {
			_IMAGE_TAG + ":" + _IMAGE_IN_STREAM_NAME,
			_NORM_RECT_TAG + ":" + _NORM_RECT_STREAM_NAME
		};
		task_info.output_streams = {
			_CLASSIFICATIONS_TAG + ":" + _CLASSIFICATIONS_STREAM_NAME,
			_IMAGE_TAG + ":" + _IMAGE_OUT_STREAM_NAME
		};
		MP_ASSIGN_OR_RETURN(task_info.task_options, options->to_pb2());

		MP_ASSIGN_OR_RETURN(auto config, task_info.generate_graph_config(options->running_mode == VisionTaskRunningMode::LIVE_STREAM));

		return create(
			*config,
			options->running_mode,
			std::move(packet_callback)
		);
	}

	absl::StatusOr<std::shared_ptr<ImageClassifierResult>> ImageClassifier::classify(
		const Image& image,
		std::shared_ptr<core::image_processing_options::ImageProcessingOptions> image_processing_options
	) {
		MP_ASSIGN_OR_RETURN(auto normalized_rect, convert_to_normalized_rect(image_processing_options, image));

		MP_ASSIGN_OR_RETURN(auto output_packets, _process_image_data({
			{ _IMAGE_IN_STREAM_NAME, std::move(*std::move(create_image(image))) },
			{ _NORM_RECT_STREAM_NAME, std::move(*std::move(create_proto(*normalized_rect.to_pb2()))) },
			}));

		return _build_classification_result(output_packets);
	}

	absl::StatusOr<std::shared_ptr<ImageClassifierResult>> ImageClassifier::classify_for_video(
		const Image& image,
		int64_t timestamp_ms,
		std::shared_ptr<core::image_processing_options::ImageProcessingOptions> image_processing_options
	) {
		MP_ASSIGN_OR_RETURN(auto normalized_rect, convert_to_normalized_rect(image_processing_options, image));

		MP_ASSIGN_OR_RETURN(auto output_packets, _process_video_data({
			{ _IMAGE_IN_STREAM_NAME, std::move(std::move(create_image(image))->At(
				Timestamp(timestamp_ms * _MICRO_SECONDS_PER_MILLISECOND)
			)) },
			{ _NORM_RECT_STREAM_NAME, std::move(std::move(create_proto(*normalized_rect.to_pb2()))->At(
				Timestamp(timestamp_ms * _MICRO_SECONDS_PER_MILLISECOND)
			)) },
			}));

		return _build_classification_result(output_packets);
	}

	absl::Status ImageClassifier::classify_async(
		const Image& image,
		int64_t timestamp_ms,
		std::shared_ptr<core::image_processing_options::ImageProcessingOptions> image_processing_options
	) {
		MP_ASSIGN_OR_RETURN(auto normalized_rect, convert_to_normalized_rect(image_processing_options, image));

		return _send_live_stream_data({
			{ _IMAGE_IN_STREAM_NAME, std::move(std::move(create_image(image))->At(
				Timestamp(timestamp_ms * _MICRO_SECONDS_PER_MILLISECOND)
			)) },
			{ _NORM_RECT_STREAM_NAME, std::move(std::move(create_proto(*normalized_rect.to_pb2()))->At(
				Timestamp(timestamp_ms * _MICRO_SECONDS_PER_MILLISECOND)
			)) },
			});
	}
}
