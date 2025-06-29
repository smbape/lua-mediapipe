#include "binding/tasks/components/containers/audio_data.h"

namespace mediapipe::tasks::lua::components::containers::audio_data {
	absl::Status AudioData::load_from_mat(cv::Mat src, int offset, int size) {
		MP_ASSERT_RETURN_IF_ERROR(src.dims == 2, "The audio data is expected to have at most 2 dimensions");
		MP_ASSERT_RETURN_IF_ERROR(src.cols == 1 || src.channels() == 1, "The audio data is expected be a Nx1 matrix");

		int channels = src.cols * src.channels();

		if (channels == 1) {
			MP_ASSERT_RETURN_IF_ERROR(_audio_format.num_channels == 1, "Input audio is mono, but the audio data is expected "
				"to have " << _audio_format.num_channels << " channels.");
		}
		else {
			MP_ASSERT_RETURN_IF_ERROR(channels == _audio_format.num_channels, "Input audio contains an invalid number of channels. "
				"Expect " << _audio_format.num_channels << ".");
		}

		src = src.reshape(channels);

		if (size < 0) {
			size = src.rows;
		}

		MP_ASSERT_RETURN_IF_ERROR(
			offset + size <= src.rows,
			"Index out of range. offset " << offset << " + size " << size <<
			" should be <= src's length: " << src.rows);

		if (size >= _buffer.rows) {
			// If the internal buffer is shorter than the load target (src), copy
			// values from the end of the src array to the internal buffer.
			int new_size = _buffer.rows;
			int new_offset = src.rows - new_size;
			cv::Mat(src, cv::Rect(0, new_offset, 1, new_size)).copyTo(_buffer);
		}
		else {
			// Shift the internal buffer backward.
			auto remaining_size = _buffer.rows - size;
			auto begining = cv::Mat(_buffer, cv::Rect(0, 0, 1, remaining_size));
			auto ending = cv::Mat(_buffer, cv::Rect(0, size, 1, remaining_size));
			ending.copyTo(begining);

			// add the incoming data to the end of the buffer
			auto incoming = cv::Mat(src, cv::Rect(0, offset, 1, size));
			auto dst = cv::Mat(_buffer, cv::Rect(0, remaining_size, 1, size));
			incoming.copyTo(dst);
		}
	}

	absl::StatusOr<std::shared_ptr<AudioData>> AudioData::create_from_mat(cv::Mat src, const std::optional<float>& sample_rate) {
		auto obj = std::make_shared<AudioData>(src.rows, AudioDataFormat(src.cols * src.channels(), sample_rate));
		MP_RETURN_IF_ERROR(obj->load_from_mat(src));
		return obj;
	}

	// cv::Mat read_wav_file(const std::string filename, int channels) {
	// 	// TODO
	// }
}
