#pragma once

#include "mediapipe/tasks/cc/audio/audio_classifier/audio_classifier.h"

namespace mediapipe::tasks::audio::audio_classifier {
	using AudioClassifierResultCallback = std::function<void(absl::StatusOr<AudioClassifierResult>)>;
}
