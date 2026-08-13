#pragma once

#include "mediapipe/tasks/cc/vision/face_detector/face_detector.h"

namespace mediapipe::tasks::vision::face_detector {
	using FaceDetectorResultCallback = std::function<void(absl::StatusOr<FaceDetectorResult>, const Image&, uint64_t)>;
}
