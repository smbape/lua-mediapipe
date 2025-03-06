#pragma once

#include "binding/solution_base.h"
#include <opencv2/core/mat.hpp>

namespace mediapipe::lua::solutions::selfie_segmentation {
	using namespace mediapipe::lua::solution_base;

	class CV_EXPORTS_W SelfieSegmentation : public ::mediapipe::lua::solution_base::SolutionBase {
	public:
		using SolutionBase::SolutionBase;
		CV_WRAP [[nodiscard]] static absl::StatusOr<std::shared_ptr<SelfieSegmentation>> create(uchar model_selection = 0);
		CV_WRAP [[nodiscard]] absl::Status process(const cv::Mat& image, CV_OUT std::map<std::string, ::LUA_MODULE_NAME::Object>& solution_outputs);
	};
}
