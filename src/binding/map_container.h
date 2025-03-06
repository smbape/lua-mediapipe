#pragma once

#include <google/protobuf/map_field.h>
#include <google/protobuf/stubs/common.h>
#include <opencv2/core/cvdef.h>

#include "binding/util.h"

#include <lua_bridge_common.hdr.hpp>

namespace google::protobuf {

	namespace lua {
		struct MapContainer;
		struct MapIterator;
	}

	// hack to access MapReflection private members
	template<>
	class MutableRepeatedFieldRef<lua::MapContainer, void> {
	public:
		static lua::MapIterator begin(lua::MapContainer* self);
		static lua::MapIterator end(lua::MapContainer* self);
		[[nodiscard]] static absl::StatusOr<std::string> ToStr(const lua::MapContainer* self);
		[[nodiscard]] static absl::StatusOr<bool> Contains(const lua::MapContainer* self, ::LUA_MODULE_NAME::Object key);
		[[nodiscard]] static absl::StatusOr<::LUA_MODULE_NAME::Object> GetItem(const lua::MapContainer* self, ::LUA_MODULE_NAME::Object key);
		[[nodiscard]] static absl::Status SetItem(lua::MapContainer* self, ::LUA_MODULE_NAME::Object key, ::LUA_MODULE_NAME::Object arg);
		static size_t Size(const lua::MapContainer* self);
	};

	using MapRefectionFriend = MutableRepeatedFieldRef<lua::MapContainer, void>;

	namespace lua {
		class MapIterator {
		public:
			MapIterator() = default;
			MapIterator(
				MapContainer* container,
				const ::google::protobuf::MapIterator&& iter
			);
			MapIterator(const MapIterator& other);
			MapIterator& operator=(const MapIterator& other);

			MapIterator& operator++() noexcept;
			MapIterator operator++(int) noexcept;
			bool operator==(const MapIterator& other) const noexcept;
			bool operator!=(const MapIterator& other) const noexcept;
			const std::pair<::LUA_MODULE_NAME::Object, ::LUA_MODULE_NAME::Object>& operator*() noexcept;

		private:
			MapContainer* m_container;
			std::unique_ptr<::google::protobuf::MapIterator> m_iter;
			std::pair<::LUA_MODULE_NAME::Object, ::LUA_MODULE_NAME::Object> m_value;
			bool m_dirty = true;
		};

		struct CV_EXPORTS_W_SIMPLE MapContainer {
			CV_WRAP MapContainer() = default;
			CV_WRAP MapContainer(const MapContainer& other) = default;
			MapContainer& operator=(const MapContainer& other) = default;

			CV_WRAP_AS(contains) [[nodiscard]] absl::StatusOr<bool> Contains(::LUA_MODULE_NAME::Object key) const;
			CV_WRAP_AS(clear) void Clear();
			CV_WRAP_AS(length) size_t Length() const;
			CV_WRAP size_t size() const;
			CV_WRAP_AS(get) [[nodiscard]] absl::StatusOr<::LUA_MODULE_NAME::Object> Get(::LUA_MODULE_NAME::Object key, ::LUA_MODULE_NAME::Object default_value = ::LUA_MODULE_NAME::lua_nil) const;

			CV_WRAP_AS(__index) [[nodiscard]] absl::StatusOr<::LUA_MODULE_NAME::Object> GetItem(::LUA_MODULE_NAME::Object key) const;
			CV_WRAP_AS(__newindex) [[nodiscard]] absl::Status SetItem(::LUA_MODULE_NAME::Object key, ::LUA_MODULE_NAME::Object arg);

			CV_WRAP_AS(setFields) [[nodiscard]] absl::Status SetFields(std::vector<std::pair<::LUA_MODULE_NAME::Object, ::LUA_MODULE_NAME::Object>>& fields);

			CV_WRAP_AS(__tostring) [[nodiscard]] absl::StatusOr<std::string> ToStr() const;

			CV_WRAP [[nodiscard]] absl::Status MergeFrom(const MapContainer& other);

			friend class MapRefectionFriend;

			using iterator = MapIterator;
			using const_iterator = MapIterator;

			iterator begin();
			iterator end();

			std::shared_ptr<Message> message;
			std::shared_ptr<FieldDescriptor> field_descriptor;
		};

		[[nodiscard]] absl::Status AnyObjectToMapKey(const FieldDescriptor* parent_field_descriptor, ::LUA_MODULE_NAME::Object arg, MapKey* key);
		[[nodiscard]] absl::Status AnyObjectToMapValueRef(const FieldDescriptor* parent_field_descriptor, ::LUA_MODULE_NAME::Object arg,
			bool allow_unknown_enum_values,
			MapValueRef* value_ref);
		[[nodiscard]] absl::StatusOr<::LUA_MODULE_NAME::Object> MapKeyToAnyObject(const FieldDescriptor* parent_field_descriptor, const MapKey& key);
		[[nodiscard]] absl::StatusOr<::LUA_MODULE_NAME::Object> MapValueRefToAnyObject(const FieldDescriptor* parent_field_descriptor, const MapValueRef& value);
	}
}
