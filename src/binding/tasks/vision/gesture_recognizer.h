#pragma once

#include "mediapipe/tasks/cc/vision/gesture_recognizer/gesture_recognizer.h"
#include "binding/tasks/vision/gesture_recognizer_result.h"
#include "binding/tasks/core/utils.h"

namespace mediapipe::tasks::vision::gesture_recognizer {
	using GestureRecognizerResultRawCallback = std::function<void(absl::StatusOr<tasks::lua::vision::gesture_recognizer::GestureRecognizerResult>, const Image&, int64_t)>;
	using GestureRecognizerResultCallback = std::function<void(absl::StatusOr<GestureRecognizerResult>, const Image&, int64_t)>;
}

namespace mediapipe::tasks::lua::core::utils {
	tasks::vision::gesture_recognizer::GestureRecognizerResultCallback CppConvertToGestureRecognizerResultCallback(
		tasks::vision::gesture_recognizer::GestureRecognizerResultRawCallback callback
	);

	void CppConvertToGestureRecognizerResultCallback(tasks::vision::gesture_recognizer::GestureRecognizerResultRawCallback callback, tasks::vision::gesture_recognizer::GestureRecognizerResultCallback& fn);
}
