#include "mediapipe/framework/port/status_macros.h"
#include "binding/solutions/face_detection.h"
#include "binding/solutions/download_utils.h"

namespace {
	constexpr auto _SHORT_RANGE_GRAPH_FILE_PATH = "mediapipe/modules/face_detection/face_detection_short_range_cpu.binarypb";
	constexpr auto _FULL_RANGE_GRAPH_FILE_PATH = "mediapipe/modules/face_detection/face_detection_full_range_cpu.binarypb";

	constexpr auto _SHORT_RANGE_TFLITE_FILE_PATH = "mediapipe/modules/face_detection/face_detection_short_range.tflite";
	constexpr auto _SHORT_RANGE_TFLITE_FILE_HASH = ""; // Google model files change over time, therefore, a specific hash will not be always // "sha256=3bc182eb9f33925d9e58b5c8d59308a760f4adea8f282370e428c51212c26633";
	constexpr auto _FULL_RANGE_TFLITE_FILE_PATH = "mediapipe/modules/face_detection/face_detection_full_range_sparse.tflite";
	constexpr auto _FULL_RANGE_TFLITE_FILE_HASH = ""; // Google model files change over time, therefore, a specific hash will not be always // "sha256=2c3728e6da56f21e21a320433396fb06d40d9088f2247c05e5635a688d45dfe1";

	using namespace mediapipe::lua::solutions::face_detection;
	using namespace mediapipe::lua::solutions;
}

namespace mediapipe::lua::solutions::face_detection {
	std::shared_ptr<LocationData::RelativeKeypoint> get_key_point(
		const Detection& detection,
		FaceKeyPoint key_point_enum
	) {
		if (!detection.has_location_data()) {
			return std::shared_ptr<LocationData::RelativeKeypoint>();
		}

		const auto& index = static_cast<int>(key_point_enum);
		return std::make_shared<LocationData::RelativeKeypoint>(detection.location_data().relative_keypoints(index));
	}

	absl::StatusOr<std::shared_ptr<FaceDetection>> FaceDetection::create(
		float min_detection_confidence,
		uchar model_selection
	) {
		MP_RETURN_IF_ERROR(download_utils::download_oss_model(
			model_selection == 1 ? _FULL_RANGE_TFLITE_FILE_PATH : _SHORT_RANGE_TFLITE_FILE_PATH,
			model_selection == 1 ? _FULL_RANGE_TFLITE_FILE_HASH : _SHORT_RANGE_TFLITE_FILE_HASH
		));
		const auto& model_path = model_selection == 1 ? _FULL_RANGE_GRAPH_FILE_PATH : _SHORT_RANGE_GRAPH_FILE_PATH;

		MP_ASSIGN_OR_RETURN(auto graph_options, SolutionBase::create_graph_options(std::make_shared<FaceDetectionOptions>(), { {"min_score_thresh", ::LUA_MODULE_NAME::Object(model_selection)} }));

		return SolutionBase::create(
			model_path,
			noMap(),
			graph_options,
			noMap(),
			{ "detections" },
			noTypeMap(),
			noTypeMap(),
			std::nullopt,
			static_cast<FaceDetection*>(nullptr)
		);
	}

	absl::Status FaceDetection::process(const cv::Mat& image, CV_OUT std::map<std::string, ::LUA_MODULE_NAME::Object>& solution_outputs) {
		return SolutionBase::process({
			{ "image", ::LUA_MODULE_NAME::Object(image) }
		}, solution_outputs);
	}
}
