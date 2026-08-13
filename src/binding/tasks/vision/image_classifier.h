#pragma once

#include "mediapipe/tasks/cc/vision/image_classifier/image_classifier.h"

namespace mediapipe::tasks::vision::image_classifier {
	using ImageClassifierResultCallback = std::function<void(absl::StatusOr<ImageClassifierResult>, const Image&, int64_t)>;
}
