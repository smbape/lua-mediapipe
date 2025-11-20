#include "absl/base/const_init.h"
#include "absl/synchronization/mutex.h"
#include "binding/calculator_graph.h"
#include <lua_bridge_common.hdr.hpp>

using namespace mediapipe;
using namespace mediapipe::lua;

namespace {
	// A mutex to guard the output stream observer callback function.
	// Only one callback can run at time.
	std::mutex callback_mutex;
}

namespace mediapipe::lua::calculator_graph {
	absl::StatusOr<std::shared_ptr<CalculatorGraph>> create(CalculatorGraphConfig& graph_config) {
		auto calculator_graph = std::make_shared<CalculatorGraph>();
		MP_RETURN_IF_ERROR(calculator_graph->Initialize(graph_config));
		return calculator_graph;
	}

	absl::StatusOr<std::shared_ptr<CalculatorGraph>> create(ValidatedGraphConfig& validated_graph_config) {
		auto graph_config = validated_graph_config.Config();
		return create(graph_config);
	}

	absl::StatusOr<std::shared_ptr<CalculatorGraph>> create(const std::string& binary_graph_path, const std::string& graph_config_proto) {
		CalculatorGraphConfig graph_config;
		const auto& use_binary_path = !binary_graph_path.empty();
		const auto& use_graph_config = !graph_config_proto.empty();

		MP_ASSERT_RETURN_IF_ERROR(use_binary_path && !use_graph_config || !use_binary_path && use_graph_config,
			"Please provide one of the following: "
			"\'binary_graph_path\' to initialize the graph "
			"with a binary graph file, or "
			"\'graph_config\' to initialize the graph with a "
			"graph config proto, or "
			"\'validated_graph_config\' to initialize the "
			"graph with a ValidatedGraphConfig object.");

		if (use_binary_path) {
			MP_RETURN_IF_ERROR(ReadCalculatorGraphConfigFromFile(binary_graph_path, graph_config));
		}
		else if (use_graph_config) {
			MP_RETURN_IF_ERROR(ParseProto<CalculatorGraphConfig>(graph_config_proto, graph_config));
		}

		return create(graph_config);
	}

	absl::Status add_packet_to_input_stream(CalculatorGraph* self, const std::string& stream, Packet& packet, Timestamp& timestamp) {
		::LUA_MODULE_NAME::GilYield yielder;
		auto packet_timestamp = timestamp == Timestamp::Unset() ? packet.Timestamp() : timestamp;
		MP_ASSERT_RETURN_IF_ERROR(packet_timestamp.IsAllowedInStream(), packet_timestamp.DebugString() << " can't be the timestamp of a Packet in a stream.");
		MP_RETURN_IF_ERROR(self->AddPacketToInputStream(stream, packet.At(packet_timestamp)));
		return absl::OkStatus();
	}

	const std::string get_combined_error_message(CalculatorGraph* self) {
		absl::Status error_status;
		if (self->GetCombinedErrors(&error_status) && !error_status.ok()) {
			return error_status.ToString();
		}
		return std::string();
	}

	absl::Status observe_output_stream(
		CalculatorGraph* self,
		const std::string& stream_name,
		PacketCallback callback_fn,
		bool observe_timestamp_bounds
	) {
		return self->ObserveOutputStream(
			stream_name,
			std::move([callback_fn, stream_name](const Packet& packet) {
				std::unique_lock<std::mutex> lock(callback_mutex);
				callback_fn(stream_name, packet);
				return absl::OkStatus();
			}),
			observe_timestamp_bounds
		);
	}

	absl::Status wait_until_done(CalculatorGraph* self) {
		::LUA_MODULE_NAME::GilYield yielder;
		return self->WaitUntilDone();
	}

	absl::Status wait_until_idle(CalculatorGraph* self) {
		::LUA_MODULE_NAME::GilYield yielder;
		return self->WaitUntilIdle();
	}

	absl::Status wait_for_observed_output(CalculatorGraph* self) {
		::LUA_MODULE_NAME::GilYield yielder;
		return self->WaitForObservedOutput();
	}

	absl::Status close(CalculatorGraph* self) {
		::LUA_MODULE_NAME::GilYield yielder;
		MP_RETURN_IF_ERROR(self->CloseAllPacketSources());
		MP_RETURN_IF_ERROR(self->WaitUntilDone());
		return absl::OkStatus();
	}
}
