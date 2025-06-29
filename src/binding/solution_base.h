#pragma once

#include <filesystem>
#include <opencv2/core/mat.hpp>

#include "binding/calculator_graph.h"
#include "binding/resource_util.h"
#include "binding/validated_graph_config.h"

#include <lua_bridge_common.hdr.hpp>

namespace mediapipe::lua::solution_base {
#pragma push_macro("BOOL")
#pragma push_macro("INT")
#pragma push_macro("FLOAT")
#ifdef BOOL
#undef BOOL
#endif
#ifdef INT
#undef INT
#endif
#ifdef FLOAT
#undef FLOAT
#endif

	enum class PacketDataType {
		STRING,
		BOOL,
		BOOL_LIST,
		INT,
		INT_LIST,
		FLOAT,
		FLOAT_LIST,
		AUDIO,
		IMAGE,
		IMAGE_LIST,
		IMAGE_FRAME,
		PROTO,
		PROTO_LIST
	};

	static const char* PacketDataTypeToChar[] =
	{
		"STRING",
		"BOOL",
		"BOOL_LIST",
		"INT",
		"INT_LIST",
		"FLOAT",
		"FLOAT_LIST",
		"AUDIO",
		"IMAGE",
		"IMAGE_LIST",
		"IMAGE_FRAME",
		"PROTO",
		"PROTO_LIST"
	};

#pragma pop_macro("FLOAT")
#pragma pop_macro("INT")
#pragma pop_macro("BOOL")

	const std::map<std::string, ::LUA_MODULE_NAME::Object>& noMap();
	const std::map<std::string, PacketDataType>& noTypeMap();
	const std::vector<std::string>& noVector();

	struct CV_EXPORTS_W_SIMPLE ExtraSettings {
		CV_WRAP ExtraSettings(
			bool disallow_service_default_initialization = false
		) : disallow_service_default_initialization(disallow_service_default_initialization) {}
		CV_WRAP ExtraSettings(const ExtraSettings& other) = default;

		CV_PROP_RW bool disallow_service_default_initialization;
	};

	class CV_EXPORTS_W SolutionBase {
	public:
		SolutionBase() = default;

		template<typename _Tp>
		[[nodiscard]] inline static absl::StatusOr<std::shared_ptr<_Tp>> create(
			const CalculatorGraphConfig& graph_config,
			const std::map<std::string, ::LUA_MODULE_NAME::Object>& calculator_params,
			const std::shared_ptr<google::protobuf::Message>& graph_options,
			const std::map<std::string, ::LUA_MODULE_NAME::Object>& side_inputs,
			const std::vector<std::string>& outputs,
			const std::map<std::string, PacketDataType>& stream_type_hints,
			const std::map<std::string, PacketDataType>& side_packet_type_hints,
			const std::optional<ExtraSettings>& extra_settings,
			_Tp*
		) {
			auto solution = std::make_shared<_Tp>();

			MP_RETURN_IF_ERROR(solution->__init__(
				graph_config,
				calculator_params,
				graph_options,
				side_inputs,
				outputs,
				stream_type_hints,
				side_packet_type_hints,
				extra_settings
			));

			return solution;
		}


		template<typename _Tp>
		[[nodiscard]] inline static absl::StatusOr<std::shared_ptr<_Tp>> create(
			const std::string& binary_graph_path,
			const std::map<std::string, ::LUA_MODULE_NAME::Object>& calculator_params,
			const std::shared_ptr<google::protobuf::Message>& graph_options,
			const std::map<std::string, ::LUA_MODULE_NAME::Object>& side_inputs,
			const std::vector<std::string>& outputs,
			const std::map<std::string, PacketDataType>& stream_type_hints,
			const std::map<std::string, PacketDataType>& side_packet_type_hints,
			const std::optional<ExtraSettings>& extra_settings,
			_Tp* ptr
		) {
			CalculatorGraphConfig graph_config;
			MP_RETURN_IF_ERROR(ReadCalculatorGraphConfigFromFile(GetResourcePath(binary_graph_path), graph_config));
			return create(
				graph_config,
				calculator_params,
				graph_options,
				side_inputs,
				outputs,
				stream_type_hints,
				side_packet_type_hints,
				extra_settings,
				ptr
			);
		}

		CV_WRAP [[nodiscard]] static absl::StatusOr<std::shared_ptr<SolutionBase>> create(
			const std::string& binary_graph_path,
			const std::map<std::string, ::LUA_MODULE_NAME::Object>& calculator_params = noMap(),
			const std::shared_ptr<google::protobuf::Message>& graph_options = std::shared_ptr<google::protobuf::Message>(),
			const std::map<std::string, ::LUA_MODULE_NAME::Object>& side_inputs = noMap(),
			const std::vector<std::string>& outputs = noVector(),
			const std::map<std::string, PacketDataType>& stream_type_hints = noTypeMap(),
			const std::map<std::string, PacketDataType>& side_packet_type_hints = noTypeMap(),
			const std::optional<ExtraSettings>& extra_settings = std::nullopt
		);

		CV_WRAP [[nodiscard]] static absl::StatusOr<std::shared_ptr<SolutionBase>> create(
			const CalculatorGraphConfig& graph_config,
			const std::map<std::string, ::LUA_MODULE_NAME::Object>& calculator_params = noMap(),
			const std::shared_ptr<google::protobuf::Message>& graph_options = std::shared_ptr<google::protobuf::Message>(),
			const std::map<std::string, ::LUA_MODULE_NAME::Object>& side_inputs = noMap(),
			const std::vector<std::string>& outputs = noVector(),
			const std::map<std::string, PacketDataType>& stream_type_hints = noTypeMap(),
			const std::map<std::string, PacketDataType>& side_packet_type_hints = noTypeMap(),
			const std::optional<ExtraSettings>& extra_settings = std::nullopt
		);

		CV_WRAP [[nodiscard]] absl::Status process(const cv::Mat& input_data, CV_OUT std::map<std::string, ::LUA_MODULE_NAME::Object>& solution_outputs);
		CV_WRAP [[nodiscard]] absl::Status process(const std::map<std::string, ::LUA_MODULE_NAME::Object>& input_data, CV_OUT std::map<std::string, ::LUA_MODULE_NAME::Object>& solution_outputs);

		/**
		 * Closes all the input sources and the graph.
		 */
		CV_WRAP [[nodiscard]] absl::Status close();

		/**
		 * Resets the graph for another run.
		 */
		CV_WRAP [[nodiscard]] absl::Status reset();

		/**
		 * Sets protobuf field values.
		 *
		 *  Args:
		 *    options_message: the options protobuf message.
		 *    values: field value pairs, where each field may be a "." separated path.
		 *
		 *  Returns:
		 *    the options protobuf message.
		 */
		CV_WRAP [[nodiscard]] static absl::StatusOr<std::shared_ptr<google::protobuf::Message>> create_graph_options(
			std::shared_ptr<google::protobuf::Message> options_message,
			const std::map<std::string, ::LUA_MODULE_NAME::Object>& values
		);

		virtual ~SolutionBase();

	private:
		// since I don't know the copy behaviour
		// disable it
		SolutionBase(const SolutionBase&) = delete;
		SolutionBase& operator=(const SolutionBase&) = delete;

		[[nodiscard]] absl::Status __init__(
			const CalculatorGraphConfig& graph_config,
			const std::map<std::string, ::LUA_MODULE_NAME::Object>& calculator_params,
			const std::shared_ptr<google::protobuf::Message>& graph_options,
			const std::map<std::string, ::LUA_MODULE_NAME::Object>& side_inputs,
			const std::vector<std::string>& outputs,
			const std::map<std::string, PacketDataType>& stream_type_hints,
			const std::map<std::string, PacketDataType>& side_packet_type_hints,
			const std::optional<ExtraSettings>& extra_settings
		);

		inline static const std::string GetResourcePath(const std::string& binary_graph_path) {
			namespace fs = std::filesystem;
			fs::path root_path(mediapipe::lua::_framework_bindings::resource_util::get_resource_dir());
			return (root_path / binary_graph_path).string();
		}

		std::map<std::string, PacketDataType> m_input_stream_type_info;
		std::map<std::string, PacketDataType> m_output_stream_type_info;
		std::map<std::string, PacketDataType> m_side_input_type_info;

		std::unique_ptr<CalculatorGraph> m_graph;
		int64_t m_simulated_timestamp = 0;
		std::map<std::string, Packet> m_graph_outputs;
		std::map<std::string, Packet> m_input_side_packets;
	};
}
