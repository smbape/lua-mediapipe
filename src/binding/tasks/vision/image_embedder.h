#pragma once

#include "mediapipe/tasks/cc/vision/image_embedder/image_embedder.h"

namespace mediapipe::tasks::vision::image_embedder {
	using ImageEmbedderResultCallback = std::function<void(absl::StatusOr<ImageEmbedderResult>, const Image&, int64_t)>;
}
