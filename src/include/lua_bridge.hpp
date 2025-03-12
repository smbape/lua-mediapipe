#pragma once

#include <lua_bridge_common.hdr.hpp>
#include <lua_bridge.hdr.hpp>

#include <lua_bridge_common.hpp>
#include <lua_generated_include.hpp>
#include <register_all.hpp>

#include <binding/repeated_container.impl.h>

namespace LUA_MODULE_NAME {
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
	inline void lua_to(lua_State* L, int index, google::protobuf::RepeatedField<T>& out, bool& is_valid, size_t len, bool loose) {
		return _stl_container_lua_to<google::protobuf::RepeatedField, T>(L, index, out, is_valid, len, loose);
	}

	template<class T>
	inline std::shared_ptr<google::protobuf::RepeatedField<T>> lua_to(lua_State* L, int index, google::protobuf::RepeatedField<T>* ptr, bool& is_valid, size_t len, bool loose) {
		return _stl_container_lua_to<google::protobuf::RepeatedField, T>(L, index, ptr, is_valid, len, loose);
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
	inline void lua_to(lua_State* L, int index, google::protobuf::RepeatedPtrField<T>& out, bool& is_valid, size_t len, bool loose) {
		return _stl_container_lua_to<google::protobuf::RepeatedPtrField, T>(L, index, out, is_valid, len, loose);
	}

	template<class T>
	inline std::shared_ptr<google::protobuf::RepeatedPtrField<T>> lua_to(lua_State* L, int index, google::protobuf::RepeatedPtrField<T>* ptr, bool& is_valid, size_t len, bool loose) {
		return _stl_container_lua_to<google::protobuf::RepeatedPtrField, T>(L, index, ptr, is_valid, len, loose);
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
