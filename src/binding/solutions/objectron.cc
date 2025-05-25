#include <lua_bridge.hpp>

namespace {
	constexpr auto _BINARYPB_FILE_PATH = "mediapipe/modules/objectron/objectron_cpu.binarypb";

	using namespace mediapipe::lua::solutions::objectron;
	using namespace mediapipe::lua::solutions;

	template<typename _Tp>
	inline cv::Mat repeated_to_mat(::google::protobuf::RepeatedField<_Tp> repeated) {
		const auto& rows = 1;
		auto cols = repeated.size();
		const auto& channels = 1;

		cv::Mat matrix(rows, cols, CV_MAKETYPE(
			cv::DataType<_Tp>::depth,
			channels
		));

		int idx = 0;
		for (const auto& value : repeated) {
			matrix.at<_Tp>(idx++) = value;
		}

		return matrix;
	}

	std::map<std::string, ObjectronModel> _MODEL_DICT = {
		{"Shoe", ShoeModel()},
		{"Chair", ChairModel()},
		{"Cup", CupModel()},
		{"Camera", CameraModel()},
	};

	[[nodiscard]] absl::Status _download_oss_objectron_models(const std::string& objectron_model) {
		MP_RETURN_IF_ERROR(download_utils::download_oss_model(
			"mediapipe/modules/objectron/object_detection_ssd_mobilenetv2_oidv4_fp16.tflite"
		));
		MP_RETURN_IF_ERROR(download_utils::download_oss_model(objectron_model));
		return absl::OkStatus();
	}

	std::tuple<int, int> _noSize = { 0, 0 };
}

namespace mediapipe::lua::solutions::objectron {
	std::tuple<int, int>& noSize() {
		return _noSize;
	}

	absl::StatusOr<ObjectronModel> get_model_by_name(const std::string& name) {
		MP_ASSERT_RETURN_IF_ERROR(_MODEL_DICT.count(name), name << " is not a valid model name for Objectron.");
		MP_RETURN_IF_ERROR(_download_oss_objectron_models(_MODEL_DICT[name].model_path));
		return _MODEL_DICT[name];
	}

	absl::StatusOr<std::shared_ptr<Objectron>> Objectron::create(
		bool static_image_mode,
		int max_num_objects,
		float min_detection_confidence,
		float min_tracking_confidence,
		const std::string& model_name,
		const std::tuple<float, float>& focal_length,
		const std::tuple<float, float>& principal_point,
		const std::tuple<int, int> image_size
	) {
		// Get Camera parameters.
		auto [fx, fy] = focal_length;
		auto [px, py] = principal_point;
		auto [width, height] = image_size;

		if (width != 0 && height != 0) {
			auto half_width = width / 2.0;
			auto half_height = height / 2.0;
			fx = fx / half_width;
			fy = fy / half_height;
			px = -(px - half_width) / half_width;
			py = -(py - half_height) / half_height;
		}

		// Create and init model.
		MP_ASSIGN_OR_RETURN(auto model, get_model_by_name(model_name));

		return SolutionBase::create(
			_BINARYPB_FILE_PATH,
			{
				{"objectdetectionoidv4subgraph"
					"__TensorsToDetectionsCalculator.min_score_thresh",
					::LUA_MODULE_NAME::Object(min_detection_confidence)},
				{"boxlandmarksubgraph__ThresholdingCalculator"
					".threshold",
					::LUA_MODULE_NAME::Object(min_tracking_confidence)},
				{"Lift2DFrameAnnotationTo3DCalculator"
					".normalized_focal_x", ::LUA_MODULE_NAME::Object(fx)},
				{"Lift2DFrameAnnotationTo3DCalculator"
					".normalized_focal_y", ::LUA_MODULE_NAME::Object(fy)},
				{"Lift2DFrameAnnotationTo3DCalculator"
					".normalized_principal_point_x", ::LUA_MODULE_NAME::Object(px)},
				{"Lift2DFrameAnnotationTo3DCalculator"
					".normalized_principal_point_y", ::LUA_MODULE_NAME::Object(py)},
			},
			std::shared_ptr<google::protobuf::Message>(),
			{
				{"box_landmark_model_path", ::LUA_MODULE_NAME::Object(model.model_path)},
				{"allowed_labels", ::LUA_MODULE_NAME::Object(model.label_name)},
				{"max_num_objects", ::LUA_MODULE_NAME::Object(max_num_objects)},
				{"use_prev_landmarks", ::LUA_MODULE_NAME::Object(!static_image_mode)},
			},
			{ "detected_objects" },
			noTypeMap(),
			noTypeMap(),
			std::nullopt,
			static_cast<Objectron*>(nullptr)
		);
	}

	::LUA_MODULE_NAME::Object _convert_format(::LUA_MODULE_NAME::Object input_objects) {
		bool is_valid;
		auto inputs_holder = ::LUA_MODULE_NAME::lua_to(input_objects, static_cast<FrameAnnotation*>(nullptr), is_valid);
		MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting a FrameAnnotation");
		decltype(auto) inputs = ::LUA_MODULE_NAME::extract_holder(inputs_holder, static_cast<FrameAnnotation*>(nullptr));

		std::vector<ObjectronOutputs> new_outputs;
		new_outputs.reserve(inputs.annotations_size());

		for (const auto& annotation : inputs.annotations()) {
			// Get 3d object pose.
			auto rotation = repeated_to_mat(annotation.rotation()).reshape(1, 3);
			auto translation = repeated_to_mat(annotation.translation());
			auto scale = repeated_to_mat(annotation.scale());

			// Get 2d/3d landmarks.
			NormalizedLandmarkList landmarks_2d;
			LandmarkList landmarks_3d;
			for (const auto& keypoint : annotation.keypoints()) {
				const auto& point_2d = keypoint.point_2d();
				auto* landmarks_2d_added = landmarks_2d.add_landmark();
				landmarks_2d_added->set_x(point_2d.x());
				landmarks_2d_added->set_y(point_2d.y());

				const auto& point_3d = keypoint.point_3d();
				auto* landmarks_3d_added = landmarks_3d.add_landmark();
				landmarks_3d_added->set_x(point_3d.x());
				landmarks_3d_added->set_y(point_3d.y());
				landmarks_3d_added->set_z(point_3d.z());
			}

			// Add to objectron outputs.
			new_outputs.push_back({
				landmarks_2d,
				landmarks_3d,
				rotation,
				translation,
				scale
				});
		}

		return ::LUA_MODULE_NAME::Object(new_outputs);
	}

	static ::LUA_MODULE_NAME::Object None = ::LUA_MODULE_NAME::lua_nil;

	absl::Status Objectron::process(const cv::Mat& image, CV_OUT std::map<std::string, ::LUA_MODULE_NAME::Object>& solution_outputs) {
		MP_RETURN_IF_ERROR(SolutionBase::process({
			{ "image", ::LUA_MODULE_NAME::Object(image) }
		}, solution_outputs));

		if (
			solution_outputs.count("detected_objects")
			&& !solution_outputs["detected_objects"].isnil()
			) {
			solution_outputs["detected_objects"] = _convert_format(solution_outputs["detected_objects"]);
		}
		else {
			solution_outputs["detected_objects"] = None;
		}

		return absl::OkStatus();
	}
}
