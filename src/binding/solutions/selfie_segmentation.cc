#include "binding/solutions/selfie_segmentation.h"
#include "binding/solutions/face_detection.h"
#include "binding/solutions/download_utils.h"

namespace {
	constexpr auto _BINARYPB_FILE_PATH = "mediapipe/modules/selfie_segmentation/selfie_segmentation_cpu.binarypb";
	constexpr auto _GENERAL_TFLITE_FILE_PATH = "mediapipe/modules/selfie_segmentation/selfie_segmentation.tflite";
	constexpr auto _GENERAL_TFLITE_FILE_HASH = ""; // Google model files change over time, therefore, a specific hash will not be always // "sha256=9ee168ec7c8f2a16c56fe8e1cfbc514974cbbb7e434051b455635f1bd1462f5c";
	constexpr auto _LANDSCAPE_TFLITE_FILE_PATH = "mediapipe/modules/selfie_segmentation/selfie_segmentation_landscape.tflite";
	constexpr auto _LANDSCAPE_TFLITE_FILE_HASH = ""; // Google model files change over time, therefore, a specific hash will not be always // "sha256=a77d03f4659b9f6b6c1f5106947bf40e99d7655094b6527f214ea7d451106edd";
}

namespace mediapipe::lua::solutions::selfie_segmentation {
	absl::StatusOr<std::shared_ptr<SelfieSegmentation>> SelfieSegmentation::create(uchar model_selection) {
		MP_RETURN_IF_ERROR(download_utils::download_oss_model(
			model_selection == 0 ? _GENERAL_TFLITE_FILE_PATH : _LANDSCAPE_TFLITE_FILE_PATH,
			model_selection == 0 ? _GENERAL_TFLITE_FILE_HASH : _LANDSCAPE_TFLITE_FILE_HASH
		));

		return SolutionBase::create(
			_BINARYPB_FILE_PATH,
			noMap(),
			std::shared_ptr<google::protobuf::Message>(),
			{
				{"model_selection", ::LUA_MODULE_NAME::Object(model_selection)}
			},
			{ "segmentation_mask" },
			noTypeMap(),
			noTypeMap(),
			std::nullopt,
			static_cast<SelfieSegmentation*>(nullptr)
		);
	}

	absl::Status SelfieSegmentation::process(const cv::Mat& image, CV_OUT std::map<std::string, ::LUA_MODULE_NAME::Object>& solution_outputs) {
		return SolutionBase::process({
			{ "image", ::LUA_MODULE_NAME::Object(image) }
		}, solution_outputs);
	}
}
