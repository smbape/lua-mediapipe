#pragma once

#include "binding/solution_base.h"
#include "mediapipe/modules/face_detection/face_detection.pb.h"
#include <opencv2/core/mat.hpp>

namespace mediapipe::lua::solutions::face_detection {
	using namespace mediapipe::lua::solution_base;

	enum class FaceKeyPoint {
		RIGHT_EYE = 0,
		LEFT_EYE = 1,
		NOSE_TIP = 2,
		MOUTH_CENTER = 3,
		RIGHT_EAR_TRAGION = 4,
		LEFT_EAR_TRAGION = 5,
	};

	CV_WRAP std::shared_ptr<LocationData::RelativeKeypoint> get_key_point(
		const Detection& detection,
		FaceKeyPoint key_point_enum
	);

	class CV_EXPORTS_W FaceDetection : public ::mediapipe::lua::solution_base::SolutionBase {
	public:
		using SolutionBase::SolutionBase;

		CV_WRAP [[nodiscard]] static absl::StatusOr<std::shared_ptr<FaceDetection>> create(
			float min_detection_confidence = 0,
			uchar model_selection = 0
		);

		CV_WRAP [[nodiscard]] absl::Status process(const cv::Mat& image, CV_OUT std::map<std::string, ::LUA_MODULE_NAME::Object>& solution_outputs);
	};
}
