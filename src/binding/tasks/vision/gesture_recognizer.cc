#include "mediapipe/framework/port/status_macros.h"
#include "binding/tasks/vision/gesture_recognizer.h"
#include "binding/packet_creator.h"
#include "binding/packet_getter.h"

namespace {
	using namespace google::protobuf;
	using namespace mediapipe::lua::packet_creator;
	using namespace mediapipe::lua::packet_getter;
	using namespace mediapipe::tasks::lua::components::containers;
	using namespace mediapipe::tasks::lua::components::processors;
	using namespace mediapipe::tasks::lua::core::base_options;
	using namespace mediapipe::tasks::lua::core::task_info;
	using namespace mediapipe::tasks::lua::vision::core::vision_task_running_mode;
	using namespace mediapipe::tasks::lua::vision::gesture_recognizer;
	using namespace mediapipe::tasks::vision::gesture_recognizer::proto;
	using namespace mediapipe;

	using mediapipe::lua::PacketsCallback;
	using mediapipe::tasks::core::PacketMap;

	const std::string _IMAGE_IN_STREAM_NAME = "image_in";
	const std::string _IMAGE_OUT_STREAM_NAME = "image_out";
	const std::string _IMAGE_TAG = "IMAGE";
	const std::string _NORM_RECT_STREAM_NAME = "norm_rect_in";
	const std::string _NORM_RECT_TAG = "NORM_RECT";
	const std::string _HAND_GESTURE_STREAM_NAME = "hand_gestures";
	const std::string _HAND_GESTURE_TAG = "HAND_GESTURES";
	const std::string _HANDEDNESS_STREAM_NAME = "handedness";
	const std::string _HANDEDNESS_TAG = "HANDEDNESS";
	const std::string _HAND_LANDMARKS_STREAM_NAME = "landmarks";
	const std::string _HAND_LANDMARKS_TAG = "LANDMARKS";
	const std::string _HAND_WORLD_LANDMARKS_STREAM_NAME = "world_landmarks";
	const std::string _HAND_WORLD_LANDMARKS_TAG = "WORLD_LANDMARKS";
	const std::string _TASK_GRAPH_NAME = "mediapipe.tasks.vision.gesture_recognizer.GestureRecognizerGraph";
	const int64_t _MICRO_SECONDS_PER_MILLISECOND = 1000;
	const int _GESTURE_DEFAULT_INDEX = -1;

	[[nodiscard]] absl::StatusOr<std::shared_ptr<GestureRecognizerResult>> _build_recognition_result(const PacketMap& output_packets) {
		if (output_packets.at(_HAND_GESTURE_STREAM_NAME).IsEmpty()) {
			return std::make_shared<GestureRecognizerResult>();
		}

		auto gesture_recognizer_result = std::make_shared<GestureRecognizerResult>();

		MP_PACKET_ASSIGN_OR_RETURN(const auto& gestures_proto_list, std::vector<ClassificationList>, output_packets.at(_HAND_GESTURE_STREAM_NAME));
		for (const auto& gesture_classifications : gestures_proto_list) {
			std::vector<std::shared_ptr<category::Category>> gesture_categories;

			for (const auto& gesture : gesture_classifications.classification()) {
				gesture_categories.push_back(std::move(std::make_shared<category::Category>(
					_GESTURE_DEFAULT_INDEX,
					gesture.score(),
					gesture.display_name(),
					gesture.label()
				)));
			}

			gesture_recognizer_result->gestures.push_back(std::move(gesture_categories));
		}

		MP_PACKET_ASSIGN_OR_RETURN(const auto& handedness_proto_list, std::vector<ClassificationList>, output_packets.at(_HANDEDNESS_STREAM_NAME));
		for (const auto& handedness_classifications : handedness_proto_list) {
			std::vector<std::shared_ptr<category::Category>> handedness_categories;

			for (const auto& handedness : handedness_classifications.classification()) {
				handedness_categories.push_back(std::move(std::make_shared<category::Category>(
					handedness.index(),
					handedness.score(),
					handedness.display_name(),
					handedness.label()
				)));
			}

			gesture_recognizer_result->handedness.push_back(std::move(handedness_categories));
		}

		MP_PACKET_ASSIGN_OR_RETURN(const auto& hand_landmarks_proto_list, std::vector<NormalizedLandmarkList>, output_packets.at(_HAND_LANDMARKS_STREAM_NAME));
		for (const auto& hand_landmarks : hand_landmarks_proto_list) {
			std::vector<std::shared_ptr<landmark::NormalizedLandmark>> hand_landmarks_list;

			for (const auto& hand_landmark : hand_landmarks.landmark()) {
				hand_landmarks_list.push_back(std::move(landmark::NormalizedLandmark::create_from_pb2(hand_landmark)));
			}

			gesture_recognizer_result->hand_landmarks.push_back(std::move(hand_landmarks_list));
		}

		MP_PACKET_ASSIGN_OR_RETURN(const auto& hand_world_landmarks_proto_list, std::vector<LandmarkList>, output_packets.at(_HAND_WORLD_LANDMARKS_STREAM_NAME));
		for (const auto& hand_world_landmarks : hand_world_landmarks_proto_list) {
			std::vector<std::shared_ptr<landmark::Landmark>> hand_world_landmarks_list;

			for (const auto& hand_world_landmark : hand_world_landmarks.landmark()) {
				hand_world_landmarks_list.push_back(std::move(landmark::Landmark::create_from_pb2(hand_world_landmark)));
			}

			gesture_recognizer_result->hand_world_landmarks.push_back(std::move(hand_world_landmarks_list));
		}

		return gesture_recognizer_result;
	}
}

namespace mediapipe::tasks::lua::vision::gesture_recognizer {
	using core::image_processing_options::ImageProcessingOptions;

	absl::StatusOr<std::shared_ptr<GestureRecognizerGraphOptions>> GestureRecognizerOptions::to_pb2() const {
		auto gesture_recognizer_options_proto = std::make_shared<GestureRecognizerGraphOptions>();

		// Initialize gesture recognizer options from base options.
		if (base_options) {
			MP_ASSIGN_OR_RETURN(auto base_options_proto, base_options->to_pb2());
			gesture_recognizer_options_proto->mutable_base_options()->CopyFrom(*base_options_proto);
		}
		gesture_recognizer_options_proto->mutable_base_options()->set_use_stream_mode(running_mode != VisionTaskRunningMode::IMAGE);

		// Configure hand detector and hand landmarker options.
		auto hand_landmarker_options_proto = gesture_recognizer_options_proto->mutable_hand_landmarker_graph_options();
		hand_landmarker_options_proto->set_min_tracking_confidence(min_tracking_confidence);
		hand_landmarker_options_proto->mutable_hand_detector_graph_options()->set_num_hands(num_hands);
		hand_landmarker_options_proto->mutable_hand_detector_graph_options()->set_min_detection_confidence(min_hand_detection_confidence);
		hand_landmarker_options_proto->mutable_hand_landmarks_detector_graph_options()->set_min_detection_confidence(min_hand_presence_confidence);

		// Configure hand gesture recognizer options.
		auto hand_gesture_recognizer_options_proto = gesture_recognizer_options_proto->mutable_hand_gesture_recognizer_graph_options();
		if (canned_gesture_classifier_options) {
			hand_gesture_recognizer_options_proto->mutable_canned_gesture_classifier_graph_options()->mutable_classifier_options()->CopyFrom(
				*canned_gesture_classifier_options->to_pb2());
		}
		if (custom_gesture_classifier_options) {
			hand_gesture_recognizer_options_proto->mutable_custom_gesture_classifier_graph_options()->mutable_classifier_options()->CopyFrom(
				*custom_gesture_classifier_options->to_pb2());
		}

		return gesture_recognizer_options_proto;
	}

	absl::StatusOr<std::shared_ptr<GestureRecognizer>> GestureRecognizer::create(
		const CalculatorGraphConfig& graph_config,
		VisionTaskRunningMode running_mode,
		mediapipe::lua::PacketsCallback packet_callback
	) {
		using BaseVisionTaskApi = core::base_vision_task_api::BaseVisionTaskApi;
		return BaseVisionTaskApi::create(graph_config, running_mode, std::move(packet_callback), static_cast<GestureRecognizer*>(nullptr));
	}

	absl::StatusOr<std::shared_ptr<GestureRecognizer>> GestureRecognizer::create_from_model_path(const std::string& model_path) {
		auto base_options = std::make_shared<BaseOptions>(model_path);
		return create_from_options(std::make_shared<GestureRecognizerOptions>(base_options, VisionTaskRunningMode::IMAGE));
	}

	absl::StatusOr<std::shared_ptr<GestureRecognizer>> GestureRecognizer::create_from_options(std::shared_ptr<GestureRecognizerOptions> options) {
		PacketsCallback packet_callback = nullptr;

		if (options->result_callback) {
			packet_callback = [options](const PacketMap& output_packets) {
				const auto& image_out_packet = output_packets.at(_IMAGE_OUT_STREAM_NAME);
				if (image_out_packet.IsEmpty()) {
					return;
				}

				MP_ASSIGN_OR_THROW(auto gesture_recognizer_result, _build_recognition_result(output_packets)); // There is no other choice than throw in a callback to stop the execution
				MP_PACKET_ASSIGN_OR_THROW(const auto& image, Image, image_out_packet); // There is no other choice than throw in a callback to stop the execution
				auto timestamp_ms = output_packets.at(_HAND_GESTURE_STREAM_NAME).Timestamp().Value() / _MICRO_SECONDS_PER_MILLISECOND;

				options->result_callback(*gesture_recognizer_result, image, timestamp_ms);
			};
		}

		TaskInfo task_info;
		task_info.task_graph = _TASK_GRAPH_NAME;
		task_info.input_streams = {
			_IMAGE_TAG + ":" + _IMAGE_IN_STREAM_NAME,
			_NORM_RECT_TAG + ":" + _NORM_RECT_STREAM_NAME
		};
		task_info.output_streams = {
			_HAND_GESTURE_TAG + ":" + _HAND_GESTURE_STREAM_NAME,
			_HANDEDNESS_TAG + ":" + _HANDEDNESS_STREAM_NAME,
			_HAND_LANDMARKS_TAG + ":" + _HAND_LANDMARKS_STREAM_NAME,
			_HAND_WORLD_LANDMARKS_TAG + ":" + _HAND_WORLD_LANDMARKS_STREAM_NAME,
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

	absl::StatusOr<std::shared_ptr<GestureRecognizerResult>> GestureRecognizer::recognize(
		const Image& image,
		std::shared_ptr<ImageProcessingOptions> image_processing_options
	) {
		MP_ASSIGN_OR_RETURN(auto normalized_rect, convert_to_normalized_rect(image_processing_options, image, false));

		MP_ASSIGN_OR_RETURN(auto output_packets, _process_image_data({
			{ _IMAGE_IN_STREAM_NAME, std::move(*std::move(create_image(image))) },
			{ _NORM_RECT_STREAM_NAME, std::move(*std::move(create_proto(*normalized_rect.to_pb2()))) },
			}));

		return _build_recognition_result(output_packets);
	}

	absl::StatusOr<std::shared_ptr<GestureRecognizerResult>> GestureRecognizer::recognize_for_video(
		const Image& image,
		int64_t timestamp_ms,
		std::shared_ptr<ImageProcessingOptions> image_processing_options
	) {
		MP_ASSIGN_OR_RETURN(auto normalized_rect, convert_to_normalized_rect(image_processing_options, image, false));

		MP_ASSIGN_OR_RETURN(auto output_packets, _process_video_data({
			{ _IMAGE_IN_STREAM_NAME, std::move(std::move(create_image(image))->At(
				Timestamp(timestamp_ms * _MICRO_SECONDS_PER_MILLISECOND)
			)) },
			{ _NORM_RECT_STREAM_NAME, std::move(std::move(create_proto(*normalized_rect.to_pb2()))->At(
				Timestamp(timestamp_ms * _MICRO_SECONDS_PER_MILLISECOND)
			)) },
			}));

		return _build_recognition_result(output_packets);
	}

	absl::Status GestureRecognizer::recognize_async(
		const Image& image,
		int64_t timestamp_ms,
		std::shared_ptr<ImageProcessingOptions> image_processing_options
	) {
		MP_ASSIGN_OR_RETURN(auto normalized_rect, convert_to_normalized_rect(image_processing_options, image, false));

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
