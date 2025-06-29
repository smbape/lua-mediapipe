#pragma once

#include "mediapipe/framework/formats/landmark.pb.h"
#include "binding/solution_base.h"
#include <opencv2/core/mat.hpp>

namespace mediapipe::lua::solutions::pose {
	using namespace mediapipe::lua::solution_base;

	enum class PoseLandmark {
		// The 33 pose landmarks.
		NOSE = 0,
		LEFT_EYE_INNER = 1,
		LEFT_EYE = 2,
		LEFT_EYE_OUTER = 3,
		RIGHT_EYE_INNER = 4,
		RIGHT_EYE = 5,
		RIGHT_EYE_OUTER = 6,
		LEFT_EAR = 7,
		RIGHT_EAR = 8,
		MOUTH_LEFT = 9,
		MOUTH_RIGHT = 10,
		LEFT_SHOULDER = 11,
		RIGHT_SHOULDER = 12,
		LEFT_ELBOW = 13,
		RIGHT_ELBOW = 14,
		LEFT_WRIST = 15,
		RIGHT_WRIST = 16,
		LEFT_PINKY = 17,
		RIGHT_PINKY = 18,
		LEFT_INDEX = 19,
		RIGHT_INDEX = 20,
		LEFT_THUMB = 21,
		RIGHT_THUMB = 22,
		LEFT_HIP = 23,
		RIGHT_HIP = 24,
		LEFT_KNEE = 25,
		RIGHT_KNEE = 26,
		LEFT_ANKLE = 27,
		RIGHT_ANKLE = 28,
		LEFT_HEEL = 29,
		RIGHT_HEEL = 30,
		LEFT_FOOT_INDEX = 31,
		RIGHT_FOOT_INDEX = 32,
	};

	class CV_EXPORTS_W Pose : public ::mediapipe::lua::solution_base::SolutionBase {
	public:
		using SolutionBase::SolutionBase;

		CV_WRAP [[nodiscard]] static absl::StatusOr<std::shared_ptr<Pose>> create(
			bool static_image_mode = false,
			uint8_t model_complexity = 1,
			bool smooth_landmarks = true,
			bool enable_segmentation = false,
			bool smooth_segmentation = true,
			float min_detection_confidence = 0.5f,
			float min_tracking_confidence = 0.5f,
			const std::optional<ExtraSettings>& extra_settings = std::nullopt
		);

		CV_WRAP [[nodiscard]] absl::Status process(const cv::Mat& image, CV_OUT std::map<std::string, ::LUA_MODULE_NAME::Object>& solution_outputs);
	};
}
