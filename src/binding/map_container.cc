#include <lua_bridge.hpp>

namespace google::protobuf {
	lua::MapIterator MapRefectionFriend::begin(lua::MapContainer* self) {
		Message* message = self->message.get();
		const FieldDescriptor* field_descriptor = self->field_descriptor.get();
		const Reflection* reflection = message->GetReflection();
		MapIterator begin = reflection->MapBegin(message, field_descriptor);
		return lua::MapIterator(self, std::move(begin));
	}

	lua::MapIterator MapRefectionFriend::end(lua::MapContainer* self) {
		Message* message = self->message.get();
		const FieldDescriptor* field_descriptor = self->field_descriptor.get();
		const Reflection* reflection = message->GetReflection();
		MapIterator end = reflection->MapEnd(message, field_descriptor);
		return lua::MapIterator(self, std::move(end));
	}

	absl::StatusOr<std::string> MapRefectionFriend::ToStr(const lua::MapContainer* self) {
		Message* message = self->message.get();
		const FieldDescriptor* field_descriptor = self->field_descriptor.get();

		std::string output;

		const Reflection* reflection = message->GetReflection();
		for (::google::protobuf::MapIterator it = reflection->MapBegin(message, field_descriptor);
			it != reflection->MapEnd(message, field_descriptor);
			++it
		) {
			MP_ASSIGN_OR_RETURN(auto key, lua::MapKeyToAnyObject(field_descriptor, it.GetKey()));
			MP_ASSIGN_OR_RETURN(auto value, lua::MapValueRefToAnyObject(field_descriptor, it.GetValueRef()));
			// TODO
		}

		return output;
	}

	absl::StatusOr<bool> MapRefectionFriend::Contains(const lua::MapContainer* self, ::LUA_MODULE_NAME::Object key) {
		Message* message = self->message.get();
		const FieldDescriptor* field_descriptor = self->field_descriptor.get();
		const Reflection* reflection = message->GetReflection();
		MapKey map_key;
		MP_RETURN_IF_ERROR(lua::AnyObjectToMapKey(field_descriptor, key, &map_key));
		return reflection->ContainsMapKey(*message, field_descriptor, map_key);
	}

	size_t MapRefectionFriend::Size(const lua::MapContainer* self) {
		Message* message = self->message.get();
		const FieldDescriptor* field_descriptor = self->field_descriptor.get();
		const Reflection* reflection = message->GetReflection();
		return reflection->MapSize(*message, field_descriptor);
	}

	absl::StatusOr<::LUA_MODULE_NAME::Object> MapRefectionFriend::GetItem(const lua::MapContainer* self, ::LUA_MODULE_NAME::Object key) {
		Message* message = self->message.get();
		const FieldDescriptor* field_descriptor = self->field_descriptor.get();
		const Reflection* reflection = message->GetReflection();
		MapKey map_key;
		MapValueRef value;
		MP_RETURN_IF_ERROR(lua::AnyObjectToMapKey(field_descriptor, key, &map_key));
		reflection->InsertOrLookupMapValue(message, field_descriptor, map_key, &value);
		return lua::MapValueRefToAnyObject(field_descriptor, value);
	}

	absl::Status MapRefectionFriend::SetItem(lua::MapContainer* self, ::LUA_MODULE_NAME::Object key, ::LUA_MODULE_NAME::Object arg) {
		Message* message = self->message.get();
		const FieldDescriptor* field_descriptor = self->field_descriptor.get();
		const Reflection* reflection = message->GetReflection();
		MapKey map_key;
		MapValueRef value;
		MP_RETURN_IF_ERROR(lua::AnyObjectToMapKey(field_descriptor, key, &map_key));

		if (arg.isnil()) {
			MP_ASSERT_RETURN_IF_ERROR(reflection->DeleteMapValue(message, field_descriptor, map_key), "Key not present in map");
			return absl::OkStatus();
		}

		reflection->InsertOrLookupMapValue(message, field_descriptor, map_key, &value);
		MP_RETURN_IF_ERROR(lua::AnyObjectToMapValueRef(field_descriptor, arg, reflection->SupportsUnknownEnumValues(), &value));
		return absl::OkStatus();
	}

	namespace lua {
		MapIterator::MapIterator(
			MapContainer* container,
			const ::google::protobuf::MapIterator&& iter
		) {
			m_container = container;
			m_iter = std::move(std::make_unique<::google::protobuf::MapIterator>(std::move(iter)));
		}

		MapIterator::MapIterator(const MapIterator& other) {
			m_container = other.m_container;
			m_iter = std::move(std::make_unique<::google::protobuf::MapIterator>(*other.m_iter));
		}

		MapIterator& MapIterator::operator=(const MapIterator& other) {
			m_container = other.m_container;
			m_iter = std::move(std::make_unique<::google::protobuf::MapIterator>(*other.m_iter));
			return *this;
		}

		MapIterator& MapIterator::operator++() noexcept {
			++(*m_iter);
			m_dirty = true;
			return *this;
		}

		MapIterator MapIterator::operator++(int) noexcept {
			MapIterator _Tmp = *this;
			++*this;
			return _Tmp;
		}

		bool MapIterator::operator==(const MapIterator& other) const noexcept {
			return *m_iter == *other.m_iter;
		}

		bool MapIterator::operator!=(const MapIterator& other) const noexcept {
			return *m_iter != *other.m_iter;
		}

		const std::pair<::LUA_MODULE_NAME::Object, ::LUA_MODULE_NAME::Object>& MapIterator::operator*() noexcept {
			if (m_dirty) {
				MP_ASSIGN_OR_THROW(m_value.first, MapKeyToAnyObject(m_container->field_descriptor.get(), m_iter->GetKey())); // Throwing because I failed to make COM STL Enum handle absl::StatusOr
				MP_ASSIGN_OR_THROW(m_value.second, MapValueRefToAnyObject(m_container->field_descriptor.get(), m_iter->GetValueRef())); // Throwing because I failed to make COM STL Enum handle absl::StatusOr
				m_dirty = false;
			}
			return m_value;
		}

		MapIterator MapContainer::begin() {
			return ::google::protobuf::MapRefectionFriend::begin(this);
		}

		MapIterator MapContainer::end() {
			return ::google::protobuf::MapRefectionFriend::end(this);
		}

		absl::Status AnyObjectToMapKey(const FieldDescriptor* parent_field_descriptor, ::LUA_MODULE_NAME::Object arg, MapKey* key) {
			const FieldDescriptor* field_descriptor =
				parent_field_descriptor->message_type()->map_key();

			switch (field_descriptor->cpp_type()) {
				case FieldDescriptor::CPPTYPE_INT32: {
					bool is_valid;
					auto value_holder = ::LUA_MODULE_NAME::lua_to(arg, static_cast<int*>(nullptr), is_valid);
					MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
					decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<int*>(nullptr));
					key->SetInt32Value(value);
					break;
				}
				case FieldDescriptor::CPPTYPE_INT64: {
					bool is_valid;
					auto value_holder = ::LUA_MODULE_NAME::lua_to(arg, static_cast<int64_t*>(nullptr), is_valid);
					MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
					decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<int64_t*>(nullptr));
					key->SetInt64Value(value);
					break;
				}
				case FieldDescriptor::CPPTYPE_UINT32: {
					bool is_valid;
					auto value_holder = ::LUA_MODULE_NAME::lua_to(arg, static_cast<uint*>(nullptr), is_valid);
					MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
					decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<uint*>(nullptr));
					key->SetUInt32Value(value);
					break;
				}
				case FieldDescriptor::CPPTYPE_UINT64: {
					bool is_valid;
					auto value_holder = ::LUA_MODULE_NAME::lua_to(arg, static_cast<uint64_t*>(nullptr), is_valid);
					MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
					decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<uint64_t*>(nullptr));
					key->SetUInt64Value(value);
					break;
				}
				case FieldDescriptor::CPPTYPE_BOOL: {
					bool is_valid;
					auto value_holder = ::LUA_MODULE_NAME::lua_to(arg, static_cast<bool*>(nullptr), is_valid);
					MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
					decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<bool*>(nullptr));
					key->SetBoolValue(value);
					break;
				}
				case FieldDescriptor::CPPTYPE_STRING: {
					bool is_valid;
					auto value_holder = ::LUA_MODULE_NAME::lua_to(arg, static_cast<std::string*>(nullptr), is_valid);
					MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
					decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<std::string*>(nullptr));
					key->SetStringValue(value);
					break;
				}
				default:
					MP_ASSERT_RETURN_IF_ERROR(false, "Type " << field_descriptor->cpp_type() << " cannot be a map key");
			}

			return absl::OkStatus();
		}

		absl::Status AnyObjectToMapValueRef(const FieldDescriptor* parent_field_descriptor, ::LUA_MODULE_NAME::Object arg,
			bool allow_unknown_enum_values,
			MapValueRef* value_ref) {
			const FieldDescriptor* field_descriptor =
				parent_field_descriptor->message_type()->map_value();
			switch (field_descriptor->cpp_type()) {
				case FieldDescriptor::CPPTYPE_INT32: {
					bool is_valid;
					auto value_holder = ::LUA_MODULE_NAME::lua_to(arg, static_cast<int*>(nullptr), is_valid);
					MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
					decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<int*>(nullptr));
					value_ref->SetInt32Value(value);
					break;
				}
				case FieldDescriptor::CPPTYPE_INT64: {
					bool is_valid;
					auto value_holder = ::LUA_MODULE_NAME::lua_to(arg, static_cast<int64_t*>(nullptr), is_valid);
					MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
					decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<int64_t*>(nullptr));
					value_ref->SetInt64Value(value);
					break;
				}
				case FieldDescriptor::CPPTYPE_UINT32: {
					bool is_valid;
					auto value_holder = ::LUA_MODULE_NAME::lua_to(arg, static_cast<uint*>(nullptr), is_valid);
					MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
					decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<uint*>(nullptr));
					value_ref->SetUInt32Value(value);
					break;
				}
				case FieldDescriptor::CPPTYPE_UINT64: {
					bool is_valid;
					auto value_holder = ::LUA_MODULE_NAME::lua_to(arg, static_cast<uint64_t*>(nullptr), is_valid);
					MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
					decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<uint64_t*>(nullptr));
					value_ref->SetUInt64Value(value);
					break;
				}
				case FieldDescriptor::CPPTYPE_FLOAT: {
					bool is_valid;
					auto value_holder = ::LUA_MODULE_NAME::lua_to(arg, static_cast<float*>(nullptr), is_valid);
					MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
					decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<float*>(nullptr));
					value_ref->SetFloatValue(value);
					break;
				}
				case FieldDescriptor::CPPTYPE_DOUBLE: {
					bool is_valid;
					auto value_holder = ::LUA_MODULE_NAME::lua_to(arg, static_cast<double*>(nullptr), is_valid);
					MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
					decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<double*>(nullptr));
					value_ref->SetDoubleValue(value);
					break;
				}
				case FieldDescriptor::CPPTYPE_BOOL: {
					bool is_valid;
					auto value_holder = ::LUA_MODULE_NAME::lua_to(arg, static_cast<bool*>(nullptr), is_valid);
					MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
					decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<bool*>(nullptr));
					value_ref->SetBoolValue(value);
					break;
				}
				case FieldDescriptor::CPPTYPE_STRING: {
					bool is_valid;
					auto value_holder = ::LUA_MODULE_NAME::lua_to(arg, static_cast<std::string*>(nullptr), is_valid);
					MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
					decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<std::string*>(nullptr));
					value_ref->SetStringValue(value);
					break;
				}
				case FieldDescriptor::CPPTYPE_ENUM: {
					bool is_valid;
					auto value_holder = ::LUA_MODULE_NAME::lua_to(arg, static_cast<int*>(nullptr), is_valid);
					MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
					decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<int*>(nullptr));
					if (allow_unknown_enum_values) {
						value_ref->SetEnumValue(value);
					} else {
						const EnumDescriptor* enum_descriptor = field_descriptor->enum_type();
						const EnumValueDescriptor* enum_value =
							enum_descriptor->FindValueByNumber(value);

						MP_ASSERT_RETURN_IF_ERROR(enum_value, "Unknown enum value: " << value);
						value_ref->SetEnumValue(value);
					}
					break;
				}
				case FieldDescriptor::CPPTYPE_MESSAGE: {
					MP_ASSERT_RETURN_IF_ERROR(false, "Direct assignment of submessage not allowed");
				}
				default:
					MP_ASSERT_RETURN_IF_ERROR(false, "Setting value to a field of unknown type " << field_descriptor->cpp_type());
			}

			return absl::OkStatus();
		}

		absl::StatusOr<::LUA_MODULE_NAME::Object> MapKeyToAnyObject(const FieldDescriptor* parent_field_descriptor, const MapKey& key) {
			::LUA_MODULE_NAME::Object obj;

			const FieldDescriptor* field_descriptor =
				parent_field_descriptor->message_type()->map_key();

			switch (field_descriptor->cpp_type()) {
				case FieldDescriptor::CPPTYPE_INT32:
					obj = ::LUA_MODULE_NAME::Object(key.GetInt32Value());
				case FieldDescriptor::CPPTYPE_INT64:
					obj = ::LUA_MODULE_NAME::Object(key.GetInt64Value());
				case FieldDescriptor::CPPTYPE_UINT32:
					obj = ::LUA_MODULE_NAME::Object(key.GetUInt32Value());
				case FieldDescriptor::CPPTYPE_UINT64:
					obj = ::LUA_MODULE_NAME::Object(key.GetUInt64Value());
				case FieldDescriptor::CPPTYPE_BOOL:
					obj = ::LUA_MODULE_NAME::Object(key.GetBoolValue());
				case FieldDescriptor::CPPTYPE_STRING:
					obj = ::LUA_MODULE_NAME::Object(key.GetStringValue());
				default:
					MP_ASSERT_RETURN_IF_ERROR(false, "Couldn't convert type " << field_descriptor->cpp_type() << " to value");
			}

			return obj;
		}

		absl::StatusOr<::LUA_MODULE_NAME::Object> MapValueRefToAnyObject(const FieldDescriptor* parent_field_descriptor, const MapValueRef& value) {
			::LUA_MODULE_NAME::Object obj;

			const FieldDescriptor* field_descriptor =
				parent_field_descriptor->message_type()->map_value();
			switch (field_descriptor->cpp_type()) {
			case FieldDescriptor::CPPTYPE_INT32:
				obj = ::LUA_MODULE_NAME::Object(value.GetInt32Value());
			case FieldDescriptor::CPPTYPE_INT64:
				obj = ::LUA_MODULE_NAME::Object(value.GetInt64Value());
			case FieldDescriptor::CPPTYPE_UINT32:
				obj = ::LUA_MODULE_NAME::Object(value.GetUInt32Value());
			case FieldDescriptor::CPPTYPE_UINT64:
				obj = ::LUA_MODULE_NAME::Object(value.GetUInt64Value());
			case FieldDescriptor::CPPTYPE_FLOAT:
				obj = ::LUA_MODULE_NAME::Object(value.GetFloatValue());
			case FieldDescriptor::CPPTYPE_DOUBLE:
				obj = ::LUA_MODULE_NAME::Object(value.GetDoubleValue());
			case FieldDescriptor::CPPTYPE_BOOL:
				obj = ::LUA_MODULE_NAME::Object(value.GetBoolValue());
			case FieldDescriptor::CPPTYPE_STRING:
				obj = ::LUA_MODULE_NAME::Object(value.GetStringValue());
			case FieldDescriptor::CPPTYPE_ENUM:
				obj = ::LUA_MODULE_NAME::Object(value.GetEnumValue());
			case FieldDescriptor::CPPTYPE_MESSAGE: {
				obj = ::LUA_MODULE_NAME::Object(::LUA_MODULE_NAME::reference_internal(&value.GetMessageValue()));
			}
			default:
				MP_ASSERT_RETURN_IF_ERROR(false, "Couldn't convert type " << field_descriptor->cpp_type() << " to value");
			}

			return obj;
		}

		absl::StatusOr<bool> MapContainer::Contains(::LUA_MODULE_NAME::Object key) const {
			return ::google::protobuf::MapRefectionFriend::Contains(this, key);
		}

		void MapContainer::Clear() {
			const Reflection* reflection = message->GetReflection();
			reflection->ClearField(message.get(), field_descriptor.get());
		}

		size_t MapContainer::Length() const {
			return ::google::protobuf::MapRefectionFriend::Size(this);
		}

		size_t MapContainer::size() const {
			return ::google::protobuf::MapRefectionFriend::Size(this);
		}

		absl::StatusOr<::LUA_MODULE_NAME::Object> MapContainer::Get(::LUA_MODULE_NAME::Object key, ::LUA_MODULE_NAME::Object default_value) const {
			MP_ASSIGN_OR_RETURN(auto contains, ::google::protobuf::MapRefectionFriend::Contains(this, key));
			if (contains) {
				return GetItem(key);
			}
			return default_value;
		}

		absl::StatusOr<::LUA_MODULE_NAME::Object> MapContainer::GetItem(::LUA_MODULE_NAME::Object key) const {
			return ::google::protobuf::MapRefectionFriend::GetItem(this, key);
		}

		absl::Status MapContainer::SetItem(::LUA_MODULE_NAME::Object key, ::LUA_MODULE_NAME::Object arg) {
			return ::google::protobuf::MapRefectionFriend::SetItem(this, key, arg);
		}

		absl::Status MapContainer::SetFields(std::vector<std::pair<::LUA_MODULE_NAME::Object, ::LUA_MODULE_NAME::Object>>& fields) {
			for (auto& [key, arg] : fields) {
				MP_RETURN_IF_ERROR(::google::protobuf::MapRefectionFriend::SetItem(this, key, arg));
			}
			return absl::OkStatus();
		}

		absl::StatusOr<std::string> MapContainer::ToStr() const {
			return ::google::protobuf::MapRefectionFriend::ToStr(this);
		}

		absl::Status MapContainer::MergeFrom(const MapContainer& other) {
			MP_ASSERT_RETURN_IF_ERROR(message->GetDescriptor() == other.message->GetDescriptor(),
				"Parameter to MergeFrom() must be instance of same class: "
				"expected " << message->GetDescriptor()->full_name() << " got " << other.message->GetDescriptor()->full_name() << ".");
			message->MergeFrom(*other.message.get());
			return absl::OkStatus();
		}
	}
}
