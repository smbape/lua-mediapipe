#pragma once

#include "mediapipe/framework/formats/classification.pb.h"
#include "mediapipe/framework/formats/landmark.pb.h"
#include "mediapipe/tasks/cc/vision/gesture_recognizer/proto/gesture_recognizer_graph_options.pb.h"
#include "binding/tasks/components/containers/category.h"
#include "binding/tasks/components/containers/landmark.h"
#include "binding/tasks/components/processors/classifier_options.h"
#include "binding/tasks/core/base_options.h"
#include "binding/tasks/core/task_info.h"
#include "binding/tasks/vision/core/base_vision_task_api.h"
#include "binding/tasks/vision/core/image_processing_options.h"
#include "binding/tasks/vision/core/vision_task_running_mode.h"
#include <functional>

namespace mediapipe::tasks::lua::vision::gesture_recognizer {
	struct CV_EXPORTS_W_SIMPLE GestureRecognizerResult {
		CV_WRAP GestureRecognizerResult(const GestureRecognizerResult& other) = default;
		GestureRecognizerResult& operator=(const GestureRecognizerResult& other) = default;

		CV_WRAP GestureRecognizerResult(
			const std::vector<std::vector<std::shared_ptr<components::containers::category::Category>>>& gestures = std::vector<std::vector<std::shared_ptr<components::containers::category::Category>>>(),
			const std::vector<std::vector<std::shared_ptr<components::containers::category::Category>>>& handedness = std::vector<std::vector<std::shared_ptr<components::containers::category::Category>>>(),
			const std::vector<std::vector<std::shared_ptr<components::containers::landmark::NormalizedLandmark>>>& hand_landmarks = std::vector<std::vector<std::shared_ptr<components::containers::landmark::NormalizedLandmark>>>(),
			const std::vector<std::vector<std::shared_ptr<components::containers::landmark::Landmark>>>& hand_world_landmarks = std::vector<std::vector<std::shared_ptr<components::containers::landmark::Landmark>>>()
		) :
			gestures(gestures),
			handedness(handedness),
			hand_landmarks(hand_landmarks),
			hand_world_landmarks(hand_world_landmarks)
		{}

		bool operator== (const GestureRecognizerResult& other) const {
			return ::mediapipe::lua::__eq__(gestures, other.gestures) &&
				::mediapipe::lua::__eq__(handedness, other.handedness) &&
				::mediapipe::lua::__eq__(hand_landmarks, other.hand_landmarks) &&
				::mediapipe::lua::__eq__(hand_world_landmarks, other.hand_world_landmarks);
		}

		CV_PROP_RW std::vector<std::vector<std::shared_ptr<components::containers::category::Category>>> gestures;
		CV_PROP_RW std::vector<std::vector<std::shared_ptr<components::containers::category::Category>>> handedness;
		CV_PROP_RW std::vector<std::vector<std::shared_ptr<components::containers::landmark::NormalizedLandmark>>> hand_landmarks;
		CV_PROP_RW std::vector<std::vector<std::shared_ptr<components::containers::landmark::Landmark>>> hand_world_landmarks;
	};

	using GestureRecognizerResultCallback = std::function<void(const GestureRecognizerResult&, const Image&, int64_t)>;

	struct CV_EXPORTS_W_SIMPLE GestureRecognizerOptions {
		CV_WRAP GestureRecognizerOptions(const GestureRecognizerOptions& other) = default;
		GestureRecognizerOptions& operator=(const GestureRecognizerOptions& other) = default;

		CV_WRAP GestureRecognizerOptions(
			std::shared_ptr<lua::core::base_options::BaseOptions> base_options = std::shared_ptr<lua::core::base_options::BaseOptions>(),
			core::vision_task_running_mode::VisionTaskRunningMode running_mode = tasks::lua::vision::core::vision_task_running_mode::VisionTaskRunningMode::IMAGE,
			int num_hands = 1,
			float min_hand_detection_confidence = 0.5f,
			float min_hand_presence_confidence = 0.5f,
			float min_tracking_confidence = 0.5f,
			std::shared_ptr<components::processors::classifier_options::ClassifierOptions> canned_gesture_classifier_options = std::shared_ptr<components::processors::classifier_options::ClassifierOptions>(),
			std::shared_ptr<components::processors::classifier_options::ClassifierOptions> custom_gesture_classifier_options = std::shared_ptr<components::processors::classifier_options::ClassifierOptions>(),
			GestureRecognizerResultCallback result_callback = nullptr
		) :
			base_options(base_options),
			running_mode(running_mode),
			num_hands(num_hands),
			min_hand_detection_confidence(min_hand_detection_confidence),
			min_hand_presence_confidence(min_hand_presence_confidence),
			min_tracking_confidence(min_tracking_confidence),
			canned_gesture_classifier_options(canned_gesture_classifier_options),
			custom_gesture_classifier_options(custom_gesture_classifier_options),
			result_callback(result_callback)
		{}

		CV_WRAP [[nodiscard]] absl::StatusOr<std::shared_ptr<mediapipe::tasks::vision::gesture_recognizer::proto::GestureRecognizerGraphOptions>> to_pb2() const;

		CV_PROP_RW std::shared_ptr<lua::core::base_options::BaseOptions> base_options;
		CV_PROP_RW core::vision_task_running_mode::VisionTaskRunningMode running_mode;
		CV_PROP_RW int num_hands;
		CV_PROP_RW float min_hand_detection_confidence;
		CV_PROP_RW float min_hand_presence_confidence;
		CV_PROP_RW float min_tracking_confidence;
		CV_PROP_RW std::shared_ptr<components::processors::classifier_options::ClassifierOptions> canned_gesture_classifier_options;
		CV_PROP_RW std::shared_ptr<components::processors::classifier_options::ClassifierOptions> custom_gesture_classifier_options;
		CV_PROP_W  GestureRecognizerResultCallback result_callback;
	};

	class CV_EXPORTS_W GestureRecognizer : public ::mediapipe::tasks::lua::vision::core::base_vision_task_api::BaseVisionTaskApi {
	public:
		using core::base_vision_task_api::BaseVisionTaskApi::BaseVisionTaskApi;

		CV_WRAP [[nodiscard]] static absl::StatusOr<std::shared_ptr<GestureRecognizer>> create(
			const CalculatorGraphConfig& graph_config,
			core::vision_task_running_mode::VisionTaskRunningMode running_mode,
			mediapipe::lua::PacketsCallback packet_callback = nullptr
		);
		CV_WRAP [[nodiscard]] static absl::StatusOr<std::shared_ptr<GestureRecognizer>> create_from_model_path(const std::string& model_path);
		CV_WRAP [[nodiscard]] static absl::StatusOr<std::shared_ptr<GestureRecognizer>> create_from_options(std::shared_ptr<GestureRecognizerOptions> options);
		CV_WRAP [[nodiscard]] absl::StatusOr<std::shared_ptr<GestureRecognizerResult>> recognize(
			const Image& image,
			std::shared_ptr<core::image_processing_options::ImageProcessingOptions> image_processing_options = std::shared_ptr<core::image_processing_options::ImageProcessingOptions>()
		);
		CV_WRAP [[nodiscard]] absl::StatusOr<std::shared_ptr<GestureRecognizerResult>> recognize_for_video(
			const Image& image,
			int64_t timestamp_ms,
			std::shared_ptr<core::image_processing_options::ImageProcessingOptions> image_processing_options = std::shared_ptr<core::image_processing_options::ImageProcessingOptions>()
		);
		CV_WRAP [[nodiscard]] absl::Status recognize_async(
			const Image& image,
			int64_t timestamp_ms,
			std::shared_ptr<core::image_processing_options::ImageProcessingOptions> image_processing_options = std::shared_ptr<core::image_processing_options::ImageProcessingOptions>()
		);
	};
}
