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

    ["LUA_MODULE_NAME", "mediapipe_lua"],

    ["DrawingColor", "std::tuple<int, int, int>"],

    ["TextEmbedderResult", "mediapipe::tasks::components::containers::EmbeddingResult"],
    ["ImageEmbedderResult", "mediapipe::tasks::components::containers::EmbeddingResult"],

    ["AudioClassifierResult", "mediapipe::tasks::components::containers::ClassificationResult"],
    ["TextClassifierResult", "mediapipe::tasks::components::containers::ClassificationResult"],
    ["ImageClassifierResult", "mediapipe::tasks::components::containers::ClassificationResult"],

    ["ObjectDetectorResult", "mediapipe::tasks::components::containers::DetectionResult"],

    ["FaceDetectorResult", "mediapipe::tasks::components::containers::DetectionResult"],
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
