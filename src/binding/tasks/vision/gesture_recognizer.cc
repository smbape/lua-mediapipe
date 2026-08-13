#include "binding/tasks/vision/gesture_recognizer.h"

namespace mediapipe::tasks::lua::core::utils {
	tasks::vision::gesture_recognizer::GestureRecognizerResultCallback CppConvertToGestureRecognizerResultCallback(
		tasks::vision::gesture_recognizer::GestureRecognizerResultRawCallback callback
	) {
		return [callback](absl::StatusOr<tasks::vision::gesture_recognizer::GestureRecognizerResult> _status_or, const Image& image, int64_t timestamp) {
			auto status_or = tasks::lua::vision::gesture_recognizer::ConvertToGestureRecognizerResult(_status_or);
			callback(status_or, image, timestamp);
		};
	}

	void CppConvertToGestureRecognizerResultCallback(tasks::vision::gesture_recognizer::GestureRecognizerResultRawCallback callback, tasks::vision::gesture_recognizer::GestureRecognizerResultCallback& fn) {
		fn = CppConvertToGestureRecognizerResultCallback(callback);
	}
}
