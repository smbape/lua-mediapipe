#pragma once

#include <lua_bridge_common.hdr.hpp>
#include <lua_bridge.hdr.hpp>

#include <lua_bridge_common.hpp>

#include <lua_generated_include.hpp>
#include <register_all.hpp>

#include <binding/repeated_container.impl.h>

namespace opencv_lua {
	template<typename T>
	LUA_EXPORTS bool exported_lua_is(lua_State* L, int index, T* ptr);

	template<typename T>
	LUA_EXPORTS std::shared_ptr<T> exported_lua_to(lua_State* L, int index, T* ptr);

	template<typename T>
	LUA_EXPORTS int exported_lua_push(lua_State* L, T* ptr);

	template<typename T>
	LUA_EXPORTS int exported_lua_push(lua_State* L, T&& obj);

	template<typename T>
	LUA_EXPORTS int exported_lua_push(lua_State* L, const T& obj);

	extern template
	LUA_EXPORTS bool exported_lua_is<cv::Mat>(lua_State* L, int index, cv::Mat* ptr);

	extern template
	LUA_EXPORTS std::shared_ptr<cv::Mat> exported_lua_to<cv::Mat>(lua_State* L, int index, cv::Mat* ptr);

	extern template
	LUA_EXPORTS int exported_lua_push<cv::Mat>(lua_State* L, cv::Mat* ptr);

	extern template
	LUA_EXPORTS int exported_lua_push<cv::Mat>(lua_State* L, cv::Mat&& obj);

	extern template
	LUA_EXPORTS int exported_lua_push<cv::Mat>(lua_State* L, const cv::Mat& obj);
}

namespace LUA_MODULE_NAME {
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

	// ================================
	// cv::Mat
	// ================================
	inline bool lua_is(lua_State* L, int index, cv::Mat* ptr) {
		return opencv_lua::exported_lua_is(L, index, ptr);
	}

	inline std::shared_ptr<cv::Mat> lua_to(lua_State* L, int index, cv::Mat* ptr) {
		return opencv_lua::exported_lua_to(L, index, ptr);
	}

	inline int lua_push(lua_State* L, cv::Mat* ptr) {
		return opencv_lua::exported_lua_push(L, ptr);
	}

	inline int lua_push(lua_State* L, cv::Mat&& obj) {
		return opencv_lua::exported_lua_push(L, std::move(obj));
	}

	inline int lua_push(lua_State* L, const cv::Mat& obj) {
		return opencv_lua::exported_lua_push(L, obj);
	}

	// ================================
	// mediapipe::Timestamp
	// ================================
	inline bool lua_is(lua_State* L, int index, mediapipe::Timestamp* ptr) {
		if (lua_isuserdata(L, index)) {
			return lua_userdata_is(L, index, ptr);
		}

		return lua_is(L, index, static_cast<int64_t*>(nullptr));
	}

	inline std::shared_ptr<mediapipe::Timestamp> lua_to(lua_State* L, int index, mediapipe::Timestamp* ptr) {
		if (lua_isuserdata(L, index)) {
			return *static_cast<std::shared_ptr<mediapipe::Timestamp>*>(lua_touserdata(L, index));
		}
		return std::make_shared<mediapipe::Timestamp>(lua_to(L, index, static_cast<int64_t*>(nullptr)));
	}

	// ================================
	// absl::Status
	// ================================
	inline int lua_push(lua_State* L, const absl::Status& status) {
		if (status.ok()) {
			return 0;
		}

		std::ostringstream oss;
		oss << StatusCodeToError(status.code()) << ": " << status.message().data();
		return luaL_error(L, "%s", oss.str().c_str());
	}

	// ================================
	// absl::StatusOr
	// ================================
	template<typename T>
	inline int lua_push(lua_State* L, const absl::StatusOr<T>& status_or) {
		if (!status_or.status().ok()) {
			return lua_push(L, status_or.status());
		}
		return lua_push(L, status_or.value());
	}

	// ================================
	// google::protobuf::RepeatedField
	// ================================

	template<class T>
	inline bool lua_is(lua_State* L, int index, google::protobuf::RepeatedField<T>* ptr, size_t len, bool loose) {
		return _stl_container_lua_is<google::protobuf::RepeatedField, T>(L, index, ptr, len, loose);
	}

	template<class T>
	inline void lua_to(lua_State* L, int index, google::protobuf::RepeatedField<T>& out) {
		return _stl_container_lua_to<google::protobuf::RepeatedField, T>(L, index, out);
	}

	template<class T>
	inline std::shared_ptr<google::protobuf::RepeatedField<T>> lua_to(lua_State* L, int index, google::protobuf::RepeatedField<T>* ptr) {
		return _stl_container_lua_to<google::protobuf::RepeatedField, T>(L, index, ptr);
	}

	template<class T>
	inline int lua_push(lua_State* L, google::protobuf::RepeatedField<T>&& vec) {
		return _stl_container_lua_push<google::protobuf::RepeatedField, T>(L, std::move(vec));
	}

	template<class T>
	inline int lua_push(lua_State* L, const google::protobuf::RepeatedField<T>& vec) {
		return _stl_container_lua_push<google::protobuf::RepeatedField, T>(L, vec);
	}

	// ================================
	// google::protobuf::RepeatedPtrField
	// ================================

	template<class T>
	inline bool lua_is(lua_State* L, int index, google::protobuf::RepeatedPtrField<T>* ptr, size_t len, bool loose) {
		return _stl_container_lua_is<google::protobuf::RepeatedPtrField, T>(L, index, ptr, len, loose);
	}

	template<class T>
	inline void lua_to(lua_State* L, int index, google::protobuf::RepeatedPtrField<T>& out) {
		return _stl_container_lua_to<google::protobuf::RepeatedPtrField, T>(L, index, out);
	}

	template<class T>
	inline std::shared_ptr<google::protobuf::RepeatedPtrField<T>> lua_to(lua_State* L, int index, google::protobuf::RepeatedPtrField<T>* ptr) {
		return _stl_container_lua_to<google::protobuf::RepeatedPtrField, T>(L, index, ptr);
	}

	template<class T>
	inline int lua_push(lua_State* L, google::protobuf::RepeatedPtrField<T>&& vec) {
		return _stl_container_lua_push<google::protobuf::RepeatedPtrField, T>(L, std::move(vec));
	}

	template<class T>
	inline int lua_push(lua_State* L, const google::protobuf::RepeatedPtrField<T>& vec) {
		return _stl_container_lua_push<google::protobuf::RepeatedPtrField, T>(L, vec);
	}

	// TODO MapContainer
	// TODO RepeatedContainer
}

namespace LUA_MODULE_NAME {
	void register_extensions(lua_State* L);
}
