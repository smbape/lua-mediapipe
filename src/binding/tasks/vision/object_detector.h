#pragma once

#include "mediapipe/tasks/cc/vision/object_detector/object_detector.h"

namespace mediapipe::tasks::vision::object_detector {
	using ObjectDetectorResultCallback = std::function<void(absl::StatusOr<ObjectDetectorResult>, const Image&, int64_t)>;
}
