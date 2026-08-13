#pragma once

#include <lua_bridge_common.hdr.hpp>
#include <opencv2/core.hpp>
#include "absl/status/status.h"
#include "absl/status/statusor.h"
#include "google/protobuf/repeated_field.h"
#include "mediapipe/framework/timestamp.h"

namespace LUA_MODULE_NAME {
	const std::string StatusCodeToError(const ::absl::StatusCode& code);

	// ================================
	// cv::Mat
	// ================================

	std::shared_ptr<cv::Mat> lua_to(lua_State* L, int index, cv::Mat* ptr, bool& is_valid);

	void lua_push(lua_State* L, cv::Mat* ptr);

	void lua_push(lua_State* L, cv::Mat&& obj);

	void lua_push(lua_State* L, const cv::Mat& obj);

	void lua_push(lua_State* L, const std::shared_ptr<cv::Mat>& obj);


	// ================================
	// absl::Status
	// ================================

	void lua_push(lua_State* L, const absl::Status& status);


	// ================================
	// absl::StatusOr
	// ================================

	template<typename T>
	inline void lua_push(lua_State* L, const absl::StatusOr<T>& status_or);


	// ================================
	// google::protobuf::RepeatedField
	// ================================

	template<class T>
	inline void lua_to(lua_State* L, int index, google::protobuf::RepeatedField<T>& out, bool& is_valid, size_t len = 0, bool loose = false);

	template<class T>
	inline std::shared_ptr<google::protobuf::RepeatedField<T>> lua_to(lua_State* L, int index, google::protobuf::RepeatedField<T>* ptr, bool& is_valid, size_t len = 0, bool loose = false);

	template<class T>
	inline void lua_push(lua_State* L, google::protobuf::RepeatedField<T>&& vec);

	template<class T>
	inline void lua_push(lua_State* L, const google::protobuf::RepeatedField<T>& vec);


	// ================================
	// google::protobuf::RepeatedPtrField
	// ================================

	template<class T>
	inline void lua_to(lua_State* L, int index, google::protobuf::RepeatedPtrField<T>& out, bool& is_valid, size_t len = 0, bool loose = false);

	template<class T>
	inline std::shared_ptr<google::protobuf::RepeatedPtrField<T>> lua_to(lua_State* L, int index, google::protobuf::RepeatedPtrField<T>* ptr, bool& is_valid, size_t len = 0, bool loose = false);

	template<class T>
	inline void lua_push(lua_State* L, google::protobuf::RepeatedPtrField<T>&& vec);

	template<class T>
	inline void lua_push(lua_State* L, const google::protobuf::RepeatedPtrField<T>& vec);
}
