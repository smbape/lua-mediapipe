#pragma once

#include "mediapipe/framework/calculator.pb.h"
#include "mediapipe/framework/calculator.pb.h"
#include "mediapipe/framework/deps/status_macros.h"
#include "mediapipe/framework/port/file_helpers.h"
#include "mediapipe/framework/port/status.h"
#include "mediapipe/framework/timestamp.h"

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
	// ================================
	// __eq__
	// ================================

	template<typename T>
	inline bool __eq__(const T& o1, const T& o2);

	template<typename T>
	inline bool __eq__(const std::shared_ptr<T>& p1, const std::shared_ptr<T>& p2);

	template<typename K, typename V>
	inline bool __eq__(const std::map<K, V>& m1, const std::map<K, V>& m2);

	template<typename T1, typename T2>
	inline bool __eq__(const std::pair<T1, T2>& p1, const std::pair<T1, T2>& p2);

	template<typename T>
	inline bool __eq__(const std::vector<T>& v1, const std::vector<T>& v2);

	template<typename T>
	inline bool __eq__(const T& o1, const T& o2) {
		if constexpr (requires(const T & a, const T & b) { static_cast<bool>(a == b); }) {
			return static_cast<bool>(o1 == o2);
		}
		else {
			return &o1 == &o2;
		}
	}

	template<typename T>
	inline bool __eq__(const std::shared_ptr<T>& p1, const std::shared_ptr<T>& p2) {
		if (static_cast<bool>(p1) && static_cast<bool>(p2)) {
			return __eq__(*p1, *p2);
		}
		return !static_cast<bool>(p1) && !static_cast<bool>(p2);
	}

	template<typename K, typename V>
	inline bool __eq__(const std::map<K, V>& m1, const std::map<K, V>& m2) {
		if (m1.size() != m2.size()) {
			return false;
		}

		for (const auto& [key, value] : m1) {
			if (!m2.count(key) || !__eq__(value, m2.at(key))) {
				return false;
			}
		}

		return true;
	}

	template<typename T1, typename T2>
	inline bool __eq__(const std::pair<T1, T2>& p1, const std::pair<T1, T2>& p2) {
		return __eq__(p1.first, p2.first) && __eq__(p1.second, p2.second);
	}

	template<typename T>
	inline bool __eq__(const std::vector<T>& v1, const std::vector<T>& v2) {
		if (v1.size() != v2.size()) {
			return false;
		}
		const auto mismatched = std::mismatch(v1.begin(), v1.end(), v2.begin(), static_cast<bool(*)(const T&, const T&)>(__eq__));
		return mismatched.first == v1.end();
	}

	// ================================
	// __eq__
	// ================================

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

	inline std::string TimestampValueString(const Timestamp& timestamp) {
		if (timestamp == Timestamp::Unset()) {
			return "UNSET";
		}
		else if (timestamp == Timestamp::Unstarted()) {
			return "UNSTARTED";
		}
		else if (timestamp == Timestamp::PreStream()) {
			return "PRESTREAM";
		}
		else if (timestamp == Timestamp::Min()) {
			return "MIN";
		}
		else if (timestamp == Timestamp::Max()) {
			return "MAX";
		}
		else if (timestamp == Timestamp::PostStream()) {
			return "POSTSTREAM";
		}
		else if (timestamp == Timestamp::OneOverPostStream()) {
			return "ONEOVERPOSTSTREAM";
		}
		else if (timestamp == Timestamp::Done()) {
			return "DONE";
		}
		else {
			return timestamp.DebugString();
		}
	}

	// Reads a CalculatorGraphConfig from a file.
	[[nodiscard]] inline absl::Status ReadCalculatorGraphConfigFromFile(const std::string& file_name, ::mediapipe::CalculatorGraphConfig& graph_config_proto) {
		auto status = file::Exists(file_name);
		MP_ASSERT_RETURN_IF_ERROR(status.ok(), "File " << file_name << " was not found: " << status.message().data());

		std::string graph_config_string;
		MP_RETURN_IF_ERROR(file::GetContents(file_name, &graph_config_string, /*read_as_binary=*/true));
		if (!graph_config_proto.ParseFromArray(graph_config_string.c_str(), graph_config_string.length())) {
			MP_ASSERT_RETURN_IF_ERROR(false, "Failed to parse the binary graph: " << file_name);
		}

		return absl::OkStatus();
	}

	// Reads a CalculatorGraphConfig from a file.
	inline ::mediapipe::CalculatorGraphConfig ReadCalculatorGraphConfigFromFile(const std::string& file_name) {
		::mediapipe::CalculatorGraphConfig graph_config_proto;
		MP_THROW_IF_ERROR(ReadCalculatorGraphConfigFromFile(file_name, graph_config_proto));
		return graph_config_proto;
	}

	template<typename T>
	[[nodiscard]] inline absl::Status ParseProto(const std::string& proto_str, T& proto) {
		MP_ASSERT_RETURN_IF_ERROR(ParseTextProto<T>(proto_str, &proto), "Failed to parse: " << proto_str);
		return absl::OkStatus();
	}
}
