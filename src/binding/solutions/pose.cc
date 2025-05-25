#include <lua_bridge.hpp>

namespace {
	constexpr auto _BINARYPB_FILE_PATH = "mediapipe/modules/pose_landmark/pose_landmark_cpu.binarypb";

	constexpr auto _POSE_LANDMARK_LITE_TFLITE_FILE_PATH = "mediapipe/modules/pose_landmark/pose_landmark_lite.tflite";
	constexpr auto _POSE_LANDMARK_LITE_TFLITE_FILE_HASH = ""; // Google model files change over time, therefore, a specific hash will not be always // "sha256=1150dc68a713b80660b90ef46ce4e85c1c781bb88b6e3512cc64e6a685ba5588";
	constexpr auto _POSE_LANDMARK_FULL_RANGE_TFLITE_FILE_PATH = "mediapipe/modules/pose_landmark/pose_landmark_full.tflite";
	constexpr auto _POSE_LANDMARK_FULL_RANGE_TFLITE_FILE_HASH = ""; // Google model files change over time, therefore, a specific hash will not be always // "sha256=e9a5c5cb17f736fafd4c2ec1da3b3d331d6edbe8a0d32395855aeb2cdfd64b9f";
	constexpr auto _POSE_LANDMARK_HEAVY_RANGE_TFLITE_FILE_PATH = "mediapipe/modules/pose_landmark/pose_landmark_heavy.tflite";
	constexpr auto _POSE_LANDMARK_HEAVY_RANGE_TFLITE_FILE_HASH = ""; // Google model files change over time, therefore, a specific hash will not be always // "sha256=59e42d71bcd44cbdbabc419f0ff76686595fd265419566bd4009ef703ea8e1fe";

	constexpr auto _POSE_DETECTION_TFLITE_FILE_PATH = "mediapipe/modules/pose_detection/pose_detection.tflite";
}

namespace mediapipe::lua::solutions::pose {
	using namespace google::protobuf::lua::cmessage;

	absl::StatusOr<std::shared_ptr<Pose>> Pose::create(
		bool static_image_mode,
		uint8_t model_complexity,
		bool smooth_landmarks,
		bool enable_segmentation,
		bool smooth_segmentation,
		float min_detection_confidence,
		float min_tracking_confidence,
		const std::optional<ExtraSettings>& extra_settings
	) {
		MP_RETURN_IF_ERROR(download_utils::download_oss_model(_POSE_DETECTION_TFLITE_FILE_PATH));
		MP_RETURN_IF_ERROR(download_utils::download_oss_model(
			model_complexity == 1 ? _POSE_LANDMARK_FULL_RANGE_TFLITE_FILE_PATH :
			model_complexity == 2 ? _POSE_LANDMARK_HEAVY_RANGE_TFLITE_FILE_PATH :
			_POSE_LANDMARK_LITE_TFLITE_FILE_PATH,
			model_complexity == 1 ? _POSE_LANDMARK_FULL_RANGE_TFLITE_FILE_HASH :
			model_complexity == 2 ? _POSE_LANDMARK_HEAVY_RANGE_TFLITE_FILE_HASH :
			_POSE_LANDMARK_LITE_TFLITE_FILE_HASH
		));

		return SolutionBase::create(
			_BINARYPB_FILE_PATH,
			{
				{"posedetectioncpu__TensorsToDetectionsCalculator.min_score_thresh", ::LUA_MODULE_NAME::Object(min_detection_confidence)},
				{"poselandmarkbyroicpu__tensorstoposelandmarksandsegmentation__ThresholdingCalculator.threshold", ::LUA_MODULE_NAME::Object(min_tracking_confidence)},
			},
			std::shared_ptr<google::protobuf::Message>(),
			{
				{"model_complexity", ::LUA_MODULE_NAME::Object(model_complexity)},
				{"smooth_landmarks", ::LUA_MODULE_NAME::Object(smooth_landmarks && !static_image_mode)},
				{"enable_segmentation", ::LUA_MODULE_NAME::Object(enable_segmentation)},
				{"smooth_segmentation", ::LUA_MODULE_NAME::Object(smooth_segmentation && !static_image_mode)},
				{"use_prev_landmarks", ::LUA_MODULE_NAME::Object(!static_image_mode)},
			},
			{ "pose_landmarks", "pose_world_landmarks", "segmentation_mask" },
			noTypeMap(),
			noTypeMap(),
			extra_settings,
			static_cast<Pose*>(nullptr)
		);
	}

	absl::Status Pose::process(const cv::Mat& image, CV_OUT std::map<std::string, ::LUA_MODULE_NAME::Object>& solution_outputs) {
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
