#include "binding/solutions/face_mesh.h"
#include "binding/solutions/download_utils.h"

namespace {
	constexpr auto _BINARYPB_FILE_PATH = "mediapipe/modules/face_landmark/face_landmark_front_cpu.binarypb";

	constexpr auto _FACE_LANDMARK_TFLITE_FILE_PATH = "mediapipe/modules/face_landmark/face_landmark.tflite";
	constexpr auto _FACE_LANDMARK_TFLITE_FILE_HASH = ""; // Google model files change over time, therefore, a specific hash will not be always // "sha256=1055cb9d4a9ca8b8c688902a3a5194311138ba256bcc94e336d8373a5f30c814";
	constexpr auto _FACE_LANDMARK_WITH_ATTENTION_TFLITE_FILE_PATH = "mediapipe/modules/face_landmark/face_landmark_with_attention.tflite";
	constexpr auto _FACE_LANDMARK_WITH_ATTENTION_TFLITE_FILE_HASH = ""; // Google model files change over time, therefore, a specific hash will not be always // "sha256=883b7411747bac657c30c462d305d312e9dec6adbf8b85e2f5d8d722fca9455d";

	constexpr auto _SHORT_RANGE_TFLITE_FILE_PATH = "mediapipe/modules/face_detection/face_detection_short_range.tflite";
	constexpr auto _SHORT_RANGE_TFLITE_FILE_HASH = ""; // Google model files change over time, therefore, a specific hash will not be always // "sha256=3bc182eb9f33925d9e58b5c8d59308a760f4adea8f282370e428c51212c26633";
	constexpr auto _FULL_RANGE_TFLITE_FILE_PATH = "mediapipe/modules/face_detection/face_detection_full_range_sparse.tflite";
	constexpr auto _FULL_RANGE_TFLITE_FILE_HASH = ""; // Google model files change over time, therefore, a specific hash will not be always // "sha256=2c3728e6da56f21e21a320433396fb06d40d9088f2247c05e5635a688d45dfe1";
}

namespace mediapipe::lua::solutions::face_mesh {
	absl::StatusOr<std::shared_ptr<FaceMesh>> FaceMesh::create(
		bool static_image_mode,
		int max_num_faces,
		bool refine_landmarks,
		float min_detection_confidence,
		float min_tracking_confidence
	) {
		MP_RETURN_IF_ERROR(download_utils::download_oss_model(
			refine_landmarks ? _FACE_LANDMARK_WITH_ATTENTION_TFLITE_FILE_PATH : _FACE_LANDMARK_TFLITE_FILE_PATH,
			refine_landmarks ? _FACE_LANDMARK_WITH_ATTENTION_TFLITE_FILE_HASH : _FACE_LANDMARK_TFLITE_FILE_HASH
		));
		MP_RETURN_IF_ERROR(download_utils::download_oss_model(
			refine_landmarks ? _FULL_RANGE_TFLITE_FILE_PATH : _SHORT_RANGE_TFLITE_FILE_PATH,
			refine_landmarks ? _FULL_RANGE_TFLITE_FILE_HASH : _SHORT_RANGE_TFLITE_FILE_HASH
		));

		return SolutionBase::create(
			_BINARYPB_FILE_PATH,
			{
				{"facedetectionshortrangecpu__facedetectionshortrange__facedetection__TensorsToDetectionsCalculator.min_score_thresh", ::LUA_MODULE_NAME::Object(min_detection_confidence)},
				{"facelandmarkcpu__ThresholdingCalculator.threshold", ::LUA_MODULE_NAME::Object(min_tracking_confidence)},
			},
			std::shared_ptr<google::protobuf::Message>(),
			{
				{"num_faces", ::LUA_MODULE_NAME::Object(max_num_faces)},
				{"with_attention", ::LUA_MODULE_NAME::Object(refine_landmarks)},
				{"use_prev_landmarks", ::LUA_MODULE_NAME::Object(!static_image_mode)},
			},
			{ "multi_face_landmarks" },
			noTypeMap(),
			static_cast<FaceMesh*>(nullptr)
			);
	}

	absl::Status FaceMesh::process(const cv::Mat& image, CV_OUT std::map<std::string, ::LUA_MODULE_NAME::Object>& solution_outputs) {
		return SolutionBase::process({
			{ "image", ::LUA_MODULE_NAME::Object(image) }
		}, solution_outputs);
	}
}
