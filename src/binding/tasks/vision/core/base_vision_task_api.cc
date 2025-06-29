#include "binding/tasks/vision/core/base_vision_task_api.h"
#include <lua_bridge_common.hdr.hpp>

namespace mediapipe::tasks::lua::vision::core::base_vision_task_api {
	using vision_task_running_mode::VisionTaskRunningMode;
	using components::containers::rect::NormalizedRect;
	using image_processing_options::ImageProcessingOptions;

	BaseVisionTaskApi::~BaseVisionTaskApi() {
		auto status = close();
		if (!status.ok()) {
			LUA_MODULE_WARN(::mediapipe::lua::StatusCodeToError(status.code()) << ": " << status.message().data());
		}
	}

	absl::StatusOr<std::shared_ptr<BaseVisionTaskApi>> BaseVisionTaskApi::create(
		const CalculatorGraphConfig& graph_config,
		vision_task_running_mode::VisionTaskRunningMode running_mode,
		mediapipe::lua::PacketsCallback packet_callback
	) {
		return create(graph_config, running_mode, std::move(packet_callback), static_cast<BaseVisionTaskApi*>(nullptr));
	}

	absl::StatusOr<std::map<std::string, Packet>> BaseVisionTaskApi::_process_image_data(const std::map<std::string, Packet>& inputs) {
		MP_ASSERT_RETURN_IF_ERROR(_running_mode == VisionTaskRunningMode::IMAGE,
			"Task is not initialized with the image mode. Current running mode: "
			<< StringifyVisionTaskRunningMode(_running_mode));
		return _runner->Process(inputs);
	}

	absl::StatusOr<std::map<std::string, Packet>> BaseVisionTaskApi::_process_video_data(const std::map<std::string, Packet>& inputs) {
		MP_ASSERT_RETURN_IF_ERROR(_running_mode == VisionTaskRunningMode::VIDEO,
			"Task is not initialized with the video mode. Current running mode: "
			<< StringifyVisionTaskRunningMode(_running_mode));
		return _runner->Process(inputs);
	}

	absl::Status BaseVisionTaskApi::_send_live_stream_data(const std::map<std::string, Packet>& inputs) {
		MP_ASSERT_RETURN_IF_ERROR(_running_mode == VisionTaskRunningMode::LIVE_STREAM,
			"Task is not initialized with the video mode. Current running mode: "
			<< StringifyVisionTaskRunningMode(_running_mode));
		return _runner->Send(inputs);
	}

	absl::StatusOr<NormalizedRect> BaseVisionTaskApi::convert_to_normalized_rect(
		std::shared_ptr<image_processing_options::ImageProcessingOptions> options,
		const mediapipe::Image& image,
		bool roi_allowed
	) {
		NormalizedRect normalized_rect;
		normalized_rect.rotation = 0;
		normalized_rect.x_center = 0.5;
		normalized_rect.y_center = 0.5;
		normalized_rect.width = 1;
		normalized_rect.height = 1;

		if (!options) {
			return normalized_rect;
		}

		MP_ASSERT_RETURN_IF_ERROR(options->rotation_degrees % 90 == 0, "Expected rotation to be a multiple of 90°.");

		// Convert to radians counter-clockwise.
		normalized_rect.rotation = -options->rotation_degrees * M_PI / 180.0;

		if (options->region_of_interest) {
			MP_ASSERT_RETURN_IF_ERROR(roi_allowed, "This task doesn't support region-of-interest.");
			const auto& roi = *options->region_of_interest;
			MP_ASSERT_RETURN_IF_ERROR(roi.left < roi.right && roi.top < roi.bottom, "Expected Rect with left < right and top < bottom.");
			MP_ASSERT_RETURN_IF_ERROR(roi.left >= 0 && roi.top >= 0 && roi.right <= 1 && roi.bottom <= 1, "Expected Rect values to be in [0,1].");
			normalized_rect.x_center = (roi.left + roi.right) / 2.0;
			normalized_rect.y_center = (roi.top + roi.bottom) / 2.0;
			normalized_rect.width = roi.right - roi.left;
			normalized_rect.height = roi.bottom - roi.top;
		}

		// For 90° and 270° rotations, we need to swap width and height.
		// This is due to the internal behavior of ImageToTensorCalculator, which:
		// - first denormalizes the provided rect by multiplying the rect width or
		//   height by the image width or height, repectively.
		// - then rotates this by denormalized rect by the provided rotation, and
		//   uses this for cropping,
		// - then finally rotates this back.
		if (std::abs(options->rotation_degrees % 180) != 0) {
			auto w = normalized_rect.height * image.height() / image.width();
			auto h = normalized_rect.width * image.width() / image.height();
			normalized_rect.width = w;
			normalized_rect.height = h;
		}

		return normalized_rect;
	}

	absl::Status BaseVisionTaskApi::close() {
		return _runner->Close();
	}

	std::shared_ptr<mediapipe::CalculatorGraphConfig> BaseVisionTaskApi::get_graph_config() {
		return ::LUA_MODULE_NAME::reference_internal(_runner->GetGraphConfig());
	}
}
