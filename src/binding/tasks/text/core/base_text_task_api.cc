#include "binding/tasks/text/core/base_text_task_api.h"
#include "binding/util.h"

namespace mediapipe::tasks::lua::text::core::base_text_task_api {
	BaseTextTaskApi::~BaseTextTaskApi() {
		auto status = close();
		if (!status.ok()) {
			LUA_MODULE_WARN(::mediapipe::lua::StatusCodeToError(status.code()) << ": " << status.message().data());
		}
	}

	absl::StatusOr<std::shared_ptr<BaseTextTaskApi>> BaseTextTaskApi::create(
		const CalculatorGraphConfig& graph_config
	) {
		return create(graph_config, static_cast<BaseTextTaskApi*>(nullptr));
	}

	absl::Status BaseTextTaskApi::close() {
		return _runner->Close();
	}
}
