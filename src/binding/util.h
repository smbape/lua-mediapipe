#pragma once

#include "mediapipe/framework/deps/status_macros.h"
#include "mediapipe/framework/port/file_helpers.h"
#include "mediapipe/framework/port/status.h"

#include "absl/status/status.h"
#include "absl/status/statusor.h"

#include "luadef.hpp"

#define MP_THROW_IF_ERROR(status) LUA_MODULE_ASSERT_THROW(status.ok(), ::mediapipe::lua::StatusCodeToError(status.code()) << ": " << status.message().data())

#define MP_ASSERT_RETURN_IF_ERROR( expr, _message ) do { if(!!(expr)) ; else { \
	std::ostringstream _out; _out << _message;	\
	auto fmt = "\n%s (%s)\n in %s, file %s, line %d\n";					\
	int sz = std::snprintf(nullptr, 0, fmt, _out.str().c_str(), #expr, Lua_Module_Func, __FILE__, __LINE__);	\
	std::vector<char> buf(sz + 1);																			\
	std::sprintf(buf.data(), fmt, _out.str().c_str(), #expr, Lua_Module_Func, __FILE__, __LINE__);				\
	return absl::Status(absl::StatusCode::kFailedPrecondition, buf.data()); 								\
} } while(0)

#define MP_ASSIGN_OR_THROW( lhs, rexpr ) auto MP_STATUS_MACROS_IMPL_CONCAT_(_status_or_value_, __LINE__) = (rexpr); \
MP_THROW_IF_ERROR(MP_STATUS_MACROS_IMPL_CONCAT_(_status_or_value_, __LINE__).status()); \
lhs = std::move(MP_STATUS_MACROS_IMPL_CONCAT_(_status_or_value_, __LINE__)).value()

#define MP_RETURN_LUA_ERROR_IF_ERROR( expr ) do {								\
MP_STATUS_MACROS_IMPL_ELSE_BLOCKER_										\
if (mediapipe::status_macro_internal::StatusAdaptorForMacros			\
  	status_macro_internal_adaptor = {(expr), MEDIAPIPE_LOC}) {			\
} else {																\
	absl::Status status = status_macro_internal_adaptor.Consume();		\
	std::ostringstream _out; _out << ::mediapipe::lua::StatusCodeToError(status.code()) << ": " << status.message().data();	\
	return luaL_error(L, "\n%s (%s)\n in %s, file %s, line %d\n", _out.str().c_str(), #expr, Lua_Module_Func, __FILE__, __LINE__);	\
} } while(0)

namespace mediapipe::lua {
	inline std::string StatusCodeToError(const ::absl::StatusCode& code) {
		switch (code) {
		case absl::StatusCode::kInvalidArgument:
			return "Invalid argument";
		case absl::StatusCode::kAlreadyExists:
			return "File already exists";
		case absl::StatusCode::kUnimplemented:
			return "Not implemented";
		default:
			return "Runtime error";
		}
	}

	template<typename T>
	[[nodiscard]] inline absl::Status ParseProto(const std::string& proto_str, T& proto) {
		MP_ASSERT_RETURN_IF_ERROR(ParseTextProto<T>(proto_str, &proto), "Failed to parse: " << proto_str);
		return absl::OkStatus();
	}
}
