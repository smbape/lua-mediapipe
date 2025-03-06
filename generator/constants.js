exports.SIMPLE_ARGTYPE_DEFAULTS = new Map([
    ["bool", "0"],
    ["size_t", "0"],
    ["std::size_t", "0"],
    ["SSIZE_T", "0"],
    ["ssize_t", "0"],
    ["int", "0"],
    ["float", "0.f"],
    ["double", "0"],
    ["c_string", "(char*)\"\""],

    ["int8", "0"],
    ["int8_t", "0"],
    ["int16", "0"],
    ["int16_t", "0"],
    ["int32", "0"],
    ["int32_t", "0"],
    ["int64", "0"],
    ["int64_t", "0"],

    ["uint8", "0"],
    ["uint8_t", "0"],
    ["uint16", "0"],
    ["uint16_t", "0"],
    ["uint32", "0"],
    ["uint32_t", "0"],
    ["uint64", "0"],
    ["uint64_t", "0"],
    ["Stream", "Stream::Null()"],
]);

exports.IDL_TYPES = new Map([]);

exports.CPP_TYPES = new Map([
    ["InputArray", "cv::_InputArray"],
    ["InputArrayOfArrays", "cv::_InputArray"],
    ["InputOutputArray", "cv::_InputOutputArray"],
    ["InputOutputArrayOfArrays", "cv::_InputOutputArray"],
    ["OutputArray", "cv::_OutputArray"],
    ["OutputArrayOfArrays", "cv::_OutputArray"],

    ["Point", "cv::Point"],
    ["Point2d", "cv::Point2d"],
    ["Rect", "cv::Rect"],
    ["Scalar", "cv::Scalar"],
    ["Size", "cv::Size"],

    ["string", "std::string"],
]);

exports.ALIASES = new Map([
    ["cv::InputArray", "InputArray"],
    ["cv::InputArrayOfArrays", "InputArrayOfArrays"],
    ["cv::InputOutputArray", "InputOutputArray"],
    ["cv::InputOutputArrayOfArrays", "InputOutputArrayOfArrays"],
    ["cv::OutputArray", "OutputArray"],
    ["cv::OutputArrayOfArrays", "OutputArrayOfArrays"],

    ["mediapipe::solutions::face_detection::SolutionBase", "mediapipe::lua::solution_base::SolutionBase"],
    ["DrawingColor", "std::tuple<int, int, int>"],

    ["tasks::components::processors::proto::ClassifierOptions", "mediapipe::tasks::components::processors::proto::ClassifierOptions"],

    ["AudioEmbedderResult", "mediapipe::tasks::lua::components::containers::embedding_result::EmbeddingResult"],
    ["TextEmbedderResult", "mediapipe::tasks::lua::components::containers::embedding_result::EmbeddingResult"],
    ["ImageEmbedderResult", "mediapipe::tasks::lua::components::containers::embedding_result::EmbeddingResult"],

    ["AudioClassifierResult", "mediapipe::tasks::lua::components::containers::classification_result::ClassificationResult"],
    ["TextClassifierResult", "mediapipe::tasks::lua::components::containers::classification_result::ClassificationResult"],
    ["ImageClassifierResult", "mediapipe::tasks::lua::components::containers::classification_result::ClassificationResult"],

    ["ObjectDetectorResult", "mediapipe::tasks::lua::components::containers::detections::DetectionResult"],

    ["FaceDetectorResult", "mediapipe::tasks::lua::components::containers::detections::DetectionResult"],
]);

exports.CLASS_PTR = new Set([]);

exports.PTR = new Set([
    "void*",
    "uchar*",
]);

exports.CUSTOM_CLASSES = [];

exports.TEMPLATED_TYPES = new Set([
    "cv::GArray",
    "cv::GOpaque",
]);

exports.IGNORED_CLASSES = new Set([]);
