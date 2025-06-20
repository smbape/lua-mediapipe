#pragma once

#include "absl/status/status.h"
#include "absl/status/statusor.h"
#include <opencv2/core/mat.hpp>
#include <optional>
#include "binding/util.h"

namespace mediapipe::tasks::lua::components::containers::audio_data {
	struct CV_EXPORTS_W_SIMPLE AudioDataFormat {
		CV_WRAP AudioDataFormat(const AudioDataFormat& other) = default;
		AudioDataFormat& operator=(const AudioDataFormat& other) = default;

		CV_WRAP AudioDataFormat(
			int num_channels = 1,
			const std::optional<float>& sample_rate = std::nullopt
		) :
			num_channels(num_channels),
			sample_rate(sample_rate)
		{}

		bool operator== (const AudioDataFormat& other) const {
			return ::mediapipe::lua::__eq__(num_channels, other.num_channels) &&
				::mediapipe::lua::__eq__(sample_rate, other.sample_rate);
		}

		CV_PROP_RW int num_channels;
		CV_PROP_RW std::optional<float> sample_rate;
	};

	class CV_EXPORTS_W AudioData {
	public:
		CV_WRAP AudioData(int buffer_length, AudioDataFormat audio_format = AudioDataFormat())
			: _audio_format(audio_format), _buffer(cv::Mat::zeros(buffer_length, 1, CV_MAKETYPE(CV_32F, audio_format.num_channels))) {};

		CV_WRAP void clear() {
			_buffer.setTo(0.0);
		}

		CV_WRAP [[nodiscard]] absl::Status load_from_mat(cv::Mat src, int offset = 0, int size = -1);
		CV_WRAP [[nodiscard]] static absl::StatusOr<std::shared_ptr<AudioData>> create_from_mat(cv::Mat src, const std::optional<float>& sample_rate = std::nullopt);

		CV_WRAP_AS(get audio_format) const AudioDataFormat audio_format() const {
			return _audio_format;
		}

		CV_WRAP_AS(get buffer_length) const int buffer_length() const {
			return _buffer.size[0];
		}

		CV_WRAP_AS(get buffer) const cv::Mat buffer()const {
			return _buffer;
		}
	private:
		AudioDataFormat _audio_format;
		cv::Mat _buffer;
	};

	// CV_EXPORTS_W cv::Mat read_wav_file(const std::string filename, int channels = 1);
}
