#include "binding/tasks/text/core/base_text_task_api.h"
#include "binding/util.h"
#include <lua_bridge_common.hdr.hpp>

namespace mediapipe::tasks::lua::text::core::base_text_task_api {
	BaseTextTaskApi::~BaseTextTaskApi() {
		auto status = close();
		if (!status.ok()) {
			LUA_MODULE_WARN(::mediapipe::lua::StatusCodeToError(status.code()) << ": " << status.message().data());
		}
	}

	absl::StatusOr<std::shared_ptr<BaseTextTaskApi>> BaseTextTaskApi::create(
		lua_State* L,
		const CalculatorGraphConfig& graph_config
	) {
		return create(L, graph_config, static_cast<BaseTextTaskApi*>(nullptr));
	}

	absl::Status BaseTextTaskApi::close() {
		::LUA_MODULE_NAME::GilYield yielder(L);
		return _runner->Close();
	}
}
