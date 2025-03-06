#include "binding/solutions/hands.h"
#include "binding/solutions/download_utils.h"

namespace {
	constexpr auto _BINARYPB_FILE_PATH = "mediapipe/modules/hand_landmark/hand_landmark_tracking_cpu.binarypb";

	constexpr auto _HAND_LANDMARK_LITE_TFLITE_FILE_PATH = "mediapipe/modules/hand_landmark/hand_landmark_lite.tflite";
	constexpr auto _HAND_LANDMARK_LITE_TFLITE_FILE_HASH = ""; // Google model files change over time, therefore, a specific hash will not be always // "sha256=d7fde8ac11f8ce03f8663775bfc323f4fc9f2a38062b4f4efa142874ef5b2a48";
	constexpr auto _HAND_LANDMARK_FULL_RANGE_TFLITE_FILE_PATH = "mediapipe/modules/hand_landmark/hand_landmark_full.tflite";
	constexpr auto _HAND_LANDMARK_FULL_RANGE_TFLITE_FILE_HASH = ""; // Google model files change over time, therefore, a specific hash will not be always // "sha256=11c272b891e1a99ab034208e23937a8008388cf11ed2a9d776ed3d01d0ba00e3";

	constexpr auto _PALM_DETECTION_LITE_TFLITE_FILE_PATH = "mediapipe/modules/palm_detection/palm_detection_lite.tflite";
	constexpr auto _PALM_DETECTION_LITE_TFLITE_FILE_HASH = ""; // Google model files change over time, therefore, a specific hash will not be always // "sha256=e9a4aaddf90dda56a87235303cf00e4c2d3fb28725f68fd88772997dac905c18";
	constexpr auto _PALM_DETECTION_FULL_RANGE_TFLITE_FILE_PATH = "mediapipe/modules/palm_detection/palm_detection_full.tflite";
	constexpr auto _PALM_DETECTION_FULL_RANGE_TFLITE_FILE_HASH = ""; // Google model files change over time, therefore, a specific hash will not be always // "sha256=1b14e9422c6ad006cde6581a46c8b90dd573c07ab7f3934b5589e7cea3f89a54";
}

namespace mediapipe::lua::solutions::hands {
	absl::StatusOr<std::shared_ptr<Hands>> Hands::create(
		bool static_image_mode,
		int max_num_hands,
		uint8_t model_complexity,
		float min_detection_confidence,
		float min_tracking_confidence
	) {
		MP_RETURN_IF_ERROR(download_utils::download_oss_model(
			model_complexity == 0 ? _HAND_LANDMARK_LITE_TFLITE_FILE_PATH : _HAND_LANDMARK_FULL_RANGE_TFLITE_FILE_PATH,
			model_complexity == 0 ? _HAND_LANDMARK_LITE_TFLITE_FILE_HASH : _HAND_LANDMARK_FULL_RANGE_TFLITE_FILE_HASH
		));

		MP_RETURN_IF_ERROR(download_utils::download_oss_model(
			model_complexity == 0 ? _PALM_DETECTION_LITE_TFLITE_FILE_PATH : _PALM_DETECTION_FULL_RANGE_TFLITE_FILE_PATH,
			model_complexity == 0 ? _PALM_DETECTION_LITE_TFLITE_FILE_HASH : _PALM_DETECTION_FULL_RANGE_TFLITE_FILE_HASH
		));

		return SolutionBase::create(
			_BINARYPB_FILE_PATH,
			{
				{"palmdetectioncpu__TensorsToDetectionsCalculator.min_score_thresh", ::LUA_MODULE_NAME::Object(min_detection_confidence)},
				{"handlandmarkcpu__ThresholdingCalculator.threshold", ::LUA_MODULE_NAME::Object(min_tracking_confidence)},
			},
			std::shared_ptr<google::protobuf::Message>(),
			{
				{"model_complexity", ::LUA_MODULE_NAME::Object(model_complexity)},
				{"num_hands", ::LUA_MODULE_NAME::Object(max_num_hands)},
				{"use_prev_landmarks", ::LUA_MODULE_NAME::Object(!static_image_mode)},
			},
			{ "multi_hand_landmarks", "multi_hand_world_landmarks", "multi_handedness" },
			noTypeMap(),
			static_cast<Hands*>(nullptr)
		);
	}

	absl::Status Hands::process(const cv::Mat& image, CV_OUT std::map<std::string, ::LUA_MODULE_NAME::Object>& solution_outputs) {
		return SolutionBase::process({
			{ "image", ::LUA_MODULE_NAME::Object(image) }
		}, solution_outputs);
	}
}
