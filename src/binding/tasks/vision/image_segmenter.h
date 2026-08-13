#pragma once

#include "mediapipe/tasks/cc/vision/image_segmenter/image_segmenter.h"

namespace mediapipe::tasks::vision::image_segmenter {
	using ImageSegmenterResultCallback = std::function<void(absl::StatusOr<ImageSegmenterResult>, const Image&, int64_t)>;

	inline bool operator==(const ImageSegmenterResult& lhs, const ImageSegmenterResult& rhs) {
		return lhs.confidence_masks == rhs.confidence_masks
			&& lhs.category_mask == rhs.category_mask
			&& lhs.quality_scores == rhs.quality_scores;
	}
}
