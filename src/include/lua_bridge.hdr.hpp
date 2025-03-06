#pragma once

#include <luadef.hpp>
#include <opencv2/core.hpp>
#include "absl/status/status.h"
#include "absl/status/statusor.h"
#include <google/protobuf/repeated_field.h>
#include "mediapipe/framework/timestamp.h"

namespace LUA_MODULE_NAME {
	// ================================
	// cv::Mat
	// ================================
	inline bool lua_is(lua_State* L, int index, cv::Mat* ptr);
	inline std::shared_ptr<cv::Mat> lua_to(lua_State* L, int index, cv::Mat* ptr);
	inline int lua_push(lua_State* L, cv::Mat* ptr);
	inline int lua_push(lua_State* L, cv::Mat&& obj);
	inline int lua_push(lua_State* L, const cv::Mat& obj);

	// ================================
	// mediapipe::Timestamp
	// ================================
	inline bool lua_is(lua_State* L, int index, mediapipe::Timestamp* ptr);
	inline std::shared_ptr<mediapipe::Timestamp> lua_to(lua_State* L, int index, mediapipe::Timestamp* ptr);

	// ================================
	// absl::Status
	// ================================
	inline int lua_push(lua_State* L, const absl::Status& status);

	// ================================
	// absl::StatusOr
	// ================================
	template<typename T>
	inline int lua_push(lua_State* L, const absl::StatusOr<T>& status_or);

	// ================================
	// google::protobuf::RepeatedField
	// ================================

	template<class T>
	inline bool lua_is(lua_State* L, int index, google::protobuf::RepeatedField<T>* ptr, size_t len = 0, bool loose = false);

	template<class T>
	inline void lua_to(lua_State* L, int index, google::protobuf::RepeatedField<T>& out);

	template<class T>
	inline std::shared_ptr<google::protobuf::RepeatedField<T>> lua_to(lua_State* L, int index, google::protobuf::RepeatedField<T>* ptr);

	template<class T>
	inline int lua_push(lua_State* L, google::protobuf::RepeatedField<T>&& vec);

	template<class T>
	inline int lua_push(lua_State* L, const google::protobuf::RepeatedField<T>& vec);

	// ================================
	// google::protobuf::RepeatedPtrField
	// ================================

	template<class T>
	inline bool lua_is(lua_State* L, int index, google::protobuf::RepeatedPtrField<T>* ptr, size_t len = 0, bool loose = false);

	template<class T>
	inline void lua_to(lua_State* L, int index, google::protobuf::RepeatedPtrField<T>& out);

	template<class T>
	inline std::shared_ptr<google::protobuf::RepeatedPtrField<T>> lua_to(lua_State* L, int index, google::protobuf::RepeatedPtrField<T>* ptr);

	template<class T>
	inline int lua_push(lua_State* L, google::protobuf::RepeatedPtrField<T>&& vec);

	template<class T>
	inline int lua_push(lua_State* L, const google::protobuf::RepeatedPtrField<T>& vec);
}
