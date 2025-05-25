#include <lua_bridge.hpp>
namespace {
	constexpr auto _BINARYPB_FILE_PATH = "mediapipe/modules/holistic_landmark/holistic_landmark_cpu.binarypb";

	constexpr auto _HOLISTIC_LANDMARK_HAND_RECROP_TFLITE_FILE_PATH = "mediapipe/modules/holistic_landmark/hand_recrop.tflite";
	constexpr auto _HOLISTIC_LANDMARK_HAND_RECROP_TFLITE_FILE_HASH = ""; // Google model files change over time, therefore, a specific hash will not be always // "sha256=67d996ce96f9d36fe17d2693022c6da93168026ab2f028f9e2365398d8ac7d5d";

	constexpr auto _FACE_LANDMARK_TFLITE_FILE_PATH = "mediapipe/modules/face_landmark/face_landmark.tflite";
	constexpr auto _FACE_LANDMARK_TFLITE_FILE_HASH = ""; // Google model files change over time, therefore, a specific hash will not be always // "sha256=1055cb9d4a9ca8b8c688902a3a5194311138ba256bcc94e336d8373a5f30c814";
	constexpr auto _FACE_LANDMARK_WITH_ATTENTION_TFLITE_FILE_PATH = "mediapipe/modules/face_landmark/face_landmark_with_attention.tflite";
	constexpr auto _FACE_LANDMARK_WITH_ATTENTION_TFLITE_FILE_HASH = ""; // Google model files change over time, therefore, a specific hash will not be always // "sha256=883b7411747bac657c30c462d305d312e9dec6adbf8b85e2f5d8d722fca9455d";

	constexpr auto _SHORT_RANGE_TFLITE_FILE_PATH = "mediapipe/modules/face_detection/face_detection_short_range.tflite";
	constexpr auto _SHORT_RANGE_TFLITE_FILE_HASH = ""; // Google model files change over time, therefore, a specific hash will not be always // "sha256=3bc182eb9f33925d9e58b5c8d59308a760f4adea8f282370e428c51212c26633";
	constexpr auto _FULL_RANGE_TFLITE_FILE_PATH = "mediapipe/modules/face_detection/face_detection_full_range_sparse.tflite";
	constexpr auto _FULL_RANGE_TFLITE_FILE_HASH = ""; // Google model files change over time, therefore, a specific hash will not be always // "sha256=2c3728e6da56f21e21a320433396fb06d40d9088f2247c05e5635a688d45dfe1";

	constexpr auto _HAND_LANDMARK_LITE_TFLITE_FILE_PATH = "mediapipe/modules/hand_landmark/hand_landmark_lite.tflite";
	constexpr auto _HAND_LANDMARK_LITE_TFLITE_FILE_HASH = ""; // Google model files change over time, therefore, a specific hash will not be always // "sha256=d7fde8ac11f8ce03f8663775bfc323f4fc9f2a38062b4f4efa142874ef5b2a48";
	constexpr auto _HAND_LANDMARK_FULL_RANGE_TFLITE_FILE_PATH = "mediapipe/modules/hand_landmark/hand_landmark_full.tflite";
	constexpr auto _HAND_LANDMARK_FULL_RANGE_TFLITE_FILE_HASH = ""; // Google model files change over time, therefore, a specific hash will not be always // "sha256=11c272b891e1a99ab034208e23937a8008388cf11ed2a9d776ed3d01d0ba00e3";

	constexpr auto _POSE_LANDMARK_LITE_TFLITE_FILE_PATH = "mediapipe/modules/pose_landmark/pose_landmark_lite.tflite";
	constexpr auto _POSE_LANDMARK_LITE_TFLITE_FILE_HASH = ""; // Google model files change over time, therefore, a specific hash will not be always // "sha256=1150dc68a713b80660b90ef46ce4e85c1c781bb88b6e3512cc64e6a685ba5588";
	constexpr auto _POSE_LANDMARK_FULL_RANGE_TFLITE_FILE_PATH = "mediapipe/modules/pose_landmark/pose_landmark_full.tflite";
	constexpr auto _POSE_LANDMARK_FULL_RANGE_TFLITE_FILE_HASH = ""; // Google model files change over time, therefore, a specific hash will not be always // "sha256=e9a5c5cb17f736fafd4c2ec1da3b3d331d6edbe8a0d32395855aeb2cdfd64b9f";
	constexpr auto _POSE_LANDMARK_HEAVY_RANGE_TFLITE_FILE_PATH = "mediapipe/modules/pose_landmark/pose_landmark_heavy.tflite";
	constexpr auto _POSE_LANDMARK_HEAVY_RANGE_TFLITE_FILE_HASH = ""; // Google model files change over time, therefore, a specific hash will not be always // "sha256=59e42d71bcd44cbdbabc419f0ff76686595fd265419566bd4009ef703ea8e1fe";

	constexpr auto _POSE_DETECTION_TFLITE_FILE_PATH = "mediapipe/modules/pose_detection/pose_detection.tflite";
	constexpr auto _POSE_DETECTION_TFLITE_FILE_HASH = ""; // Google model files change over time, therefore, a specific hash will not be always // "sha256=9ba9dd3d42efaaba86b4ff0122b06f29c4122e756b329d89dca1e297fd8f866c";
}

namespace mediapipe::lua::solutions::holistic {
	using namespace google::protobuf::lua::cmessage;

	absl::StatusOr<std::shared_ptr<Holistic>> Holistic::create(
		bool static_image_mode,
		uint8_t model_complexity,
		bool smooth_landmarks,
		bool enable_segmentation,
		bool smooth_segmentation,
		bool refine_face_landmarks,
		float min_detection_confidence,
		float min_tracking_confidence
	) {
		MP_RETURN_IF_ERROR(download_utils::download_oss_model(
			refine_face_landmarks ? _FACE_LANDMARK_WITH_ATTENTION_TFLITE_FILE_PATH : _FACE_LANDMARK_TFLITE_FILE_PATH,
			refine_face_landmarks ? _FACE_LANDMARK_WITH_ATTENTION_TFLITE_FILE_HASH : _FACE_LANDMARK_TFLITE_FILE_HASH
		));
		MP_RETURN_IF_ERROR(download_utils::download_oss_model(
			refine_face_landmarks ? _FULL_RANGE_TFLITE_FILE_PATH : _SHORT_RANGE_TFLITE_FILE_PATH,
			refine_face_landmarks ? _FULL_RANGE_TFLITE_FILE_HASH : _SHORT_RANGE_TFLITE_FILE_HASH
		));

		MP_RETURN_IF_ERROR(download_utils::download_oss_model(
			model_complexity == 0 ? _HAND_LANDMARK_LITE_TFLITE_FILE_PATH : _HAND_LANDMARK_FULL_RANGE_TFLITE_FILE_PATH,
			model_complexity == 0 ? _HAND_LANDMARK_LITE_TFLITE_FILE_HASH : _HAND_LANDMARK_FULL_RANGE_TFLITE_FILE_HASH
		));

		MP_RETURN_IF_ERROR(download_utils::download_oss_model(
			_POSE_DETECTION_TFLITE_FILE_PATH,
			_POSE_DETECTION_TFLITE_FILE_HASH
		));
		MP_RETURN_IF_ERROR(download_utils::download_oss_model(
			model_complexity == 1 ? _POSE_LANDMARK_FULL_RANGE_TFLITE_FILE_PATH :
			model_complexity == 2 ? _POSE_LANDMARK_HEAVY_RANGE_TFLITE_FILE_PATH :
			_POSE_LANDMARK_LITE_TFLITE_FILE_PATH,
			model_complexity == 1 ? _POSE_LANDMARK_FULL_RANGE_TFLITE_FILE_HASH :
			model_complexity == 2 ? _POSE_LANDMARK_HEAVY_RANGE_TFLITE_FILE_HASH :
			_POSE_LANDMARK_LITE_TFLITE_FILE_HASH
		));

		MP_RETURN_IF_ERROR(download_utils::download_oss_model(
			_HOLISTIC_LANDMARK_HAND_RECROP_TFLITE_FILE_PATH,
			_HOLISTIC_LANDMARK_HAND_RECROP_TFLITE_FILE_HASH
		));

		return SolutionBase::create(
			_BINARYPB_FILE_PATH,
			{
				{"poselandmarkcpu__posedetectioncpu__TensorsToDetectionsCalculator.min_score_thresh", ::LUA_MODULE_NAME::Object(min_detection_confidence)},
				{"poselandmarkcpu__poselandmarkbyroicpu__tensorstoposelandmarksandsegmentation__ThresholdingCalculator.threshold", ::LUA_MODULE_NAME::Object(min_tracking_confidence)},
			},
			std::shared_ptr<google::protobuf::Message>(),
			{
				{"model_complexity", ::LUA_MODULE_NAME::Object(model_complexity)},
				{"smooth_landmarks", ::LUA_MODULE_NAME::Object(smooth_landmarks && !static_image_mode)},
				{"enable_segmentation", ::LUA_MODULE_NAME::Object(enable_segmentation)},
				{"smooth_segmentation", ::LUA_MODULE_NAME::Object(smooth_segmentation && !static_image_mode)},
				{"refine_face_landmarks", ::LUA_MODULE_NAME::Object(refine_face_landmarks)},
				{"use_prev_landmarks", ::LUA_MODULE_NAME::Object(!static_image_mode)},
			},
			{
				"pose_landmarks", "pose_world_landmarks", "left_hand_landmarks",
				"right_hand_landmarks", "face_landmarks", "segmentation_mask"
			},
			noTypeMap(),
			noTypeMap(),
			std::nullopt,
			static_cast<Holistic*>(nullptr)
		);
	}

	absl::Status Holistic::process(const cv::Mat& image, CV_OUT std::map<std::string, ::LUA_MODULE_NAME::Object>& solution_outputs) {
		MP_RETURN_IF_ERROR(SolutionBase::process({
			{ "image", ::LUA_MODULE_NAME::Object(image) }
		}, solution_outputs));

		bool is_valid;

		if (
			solution_outputs.count("pose_landmarks")
			&& !solution_outputs["pose_landmarks"].isnil()
		) {
			auto pose_landmarks_holder = ::LUA_MODULE_NAME::lua_to(solution_outputs["pose_landmarks"], static_cast<NormalizedLandmarkList*>(nullptr), is_valid);
			MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting a NormalizedLandmarkList at pose_landmarks");
			decltype(auto) pose_landmarks = ::LUA_MODULE_NAME::extract_holder(pose_landmarks_holder, static_cast<NormalizedLandmarkList*>(nullptr));
			for (auto& landmark : *pose_landmarks.mutable_landmark()) {
				MP_RETURN_IF_ERROR(ClearField(landmark, "presence"));
			}
		}

		if (
			solution_outputs.count("pose_world_landmarks")
			&& !solution_outputs["pose_world_landmarks"].isnil()
		) {
			auto pose_world_landmarks_holder = ::LUA_MODULE_NAME::lua_to(solution_outputs["pose_world_landmarks"], static_cast<LandmarkList*>(nullptr), is_valid);
			MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting a LandmarkList at pose_world_landmarks");
			decltype(auto) pose_world_landmarks = ::LUA_MODULE_NAME::extract_holder(pose_world_landmarks_holder, static_cast<LandmarkList*>(nullptr));
			for (auto& landmark : *pose_world_landmarks.mutable_landmark()) {
				MP_RETURN_IF_ERROR(ClearField(landmark, "presence"));
			}
		}

		return absl::OkStatus();
	}
}
