#include <lua_bridge.hpp>

namespace {
	using namespace google::protobuf::lua;
	using namespace google::protobuf;

	[[nodiscard]] absl::Status InternalAssignRepeatedField(RepeatedContainer* self, const std::vector<::LUA_MODULE_NAME::Object>& list) {
		Message* message = self->message.get();
		message->GetReflection()->ClearField(message, self->field_descriptor.get());
		for (const auto& value : list) {
			MP_RETURN_IF_ERROR(self->Append(value));
		}
		return absl::OkStatus();
	}
}

namespace google::protobuf::lua {
	RepeatedIterator& RepeatedIterator::operator++() noexcept {
		++m_iter;
		m_dirty = true;
		return *this;
	}

	RepeatedIterator RepeatedIterator::operator++(int) noexcept {
		RepeatedIterator _Tmp = *this;
		++*this;
		return _Tmp;
	}

	bool RepeatedIterator::operator==(const lua::RepeatedIterator& b) const noexcept {
		return m_iter == b.m_iter;
	}

	bool RepeatedIterator::operator!=(const lua::RepeatedIterator& b) const noexcept {
		return m_iter != b.m_iter;
	}

	const ::LUA_MODULE_NAME::Object& RepeatedIterator::operator*() noexcept {
		if (m_dirty) {
			MP_ASSIGN_OR_THROW(m_value, container->GetItem(m_iter));
			m_dirty = false;
		}
		return m_value.value();
	}

	size_t RepeatedContainer::Length() const {
		return size();
	}

	size_t RepeatedContainer::size() const {
		const Message* message = this->message.get();
		const FieldDescriptor* field_descriptor = this->field_descriptor.get();
		return message->GetReflection()->FieldSize(*message, field_descriptor);
	}

	absl::StatusOr<::LUA_MODULE_NAME::Object> RepeatedContainer::GetItem(ssize_t index) const {
		const Message* message = this->message.get();
		const FieldDescriptor* field_descriptor = this->field_descriptor.get();
		const Reflection* reflection = message->GetReflection();

		int field_size = reflection->FieldSize(*message, field_descriptor);

		if (index < 0) {
			index += field_size;
		}

		MP_ASSERT_RETURN_IF_ERROR(index >= 0 && index < field_size, "list index (" << index << ") out of range");

		::LUA_MODULE_NAME::Object obj;

		switch (field_descriptor->cpp_type()) {
		case FieldDescriptor::CPPTYPE_INT32: {
			obj = ::LUA_MODULE_NAME::Object(reflection->GetRepeatedInt32(*message, field_descriptor, index));
			break;
		}
		case FieldDescriptor::CPPTYPE_INT64: {
			obj = ::LUA_MODULE_NAME::Object(reflection->GetRepeatedInt64(*message, field_descriptor, index));
			break;
		}
		case FieldDescriptor::CPPTYPE_UINT32: {
			obj = ::LUA_MODULE_NAME::Object(reflection->GetRepeatedUInt32(*message, field_descriptor, index));
			break;
		}
		case FieldDescriptor::CPPTYPE_UINT64: {
			obj = ::LUA_MODULE_NAME::Object(reflection->GetRepeatedUInt64(*message, field_descriptor, index));
			break;
		}
		case FieldDescriptor::CPPTYPE_FLOAT: {
			obj = ::LUA_MODULE_NAME::Object(reflection->GetRepeatedFloat(*message, field_descriptor, index));
			break;
		}
		case FieldDescriptor::CPPTYPE_DOUBLE: {
			obj = ::LUA_MODULE_NAME::Object(reflection->GetRepeatedDouble(*message, field_descriptor, index));
			break;
		}
		case FieldDescriptor::CPPTYPE_BOOL: {
			obj = ::LUA_MODULE_NAME::Object(reflection->GetRepeatedBool(*message, field_descriptor, index));
			break;
		}
		case FieldDescriptor::CPPTYPE_ENUM: {
			const EnumValueDescriptor* enum_value = reflection->GetRepeatedEnum(*message, field_descriptor, index);
			obj = ::LUA_MODULE_NAME::Object(enum_value->number());
			break;
		}
		case FieldDescriptor::CPPTYPE_STRING: {
			std::string scratch;
			const std::string& value = reflection->GetRepeatedStringReference(
				*message, field_descriptor, index, &scratch);
			obj = ::LUA_MODULE_NAME::Object(value);
			break;
		}
		case FieldDescriptor::CPPTYPE_MESSAGE: {
			Message* sub_message = reflection->MutableRepeatedMessage(const_cast<Message*>(message), field_descriptor, index);
			obj = ::LUA_MODULE_NAME::Object(::LUA_MODULE_NAME::reference_internal(sub_message));
			break;
		}
		default:
			MP_ASSERT_RETURN_IF_ERROR(false, "Getting value from a repeated field of unknown type " << field_descriptor->cpp_type());
		}

		return obj;
	}

	absl::Status RepeatedContainer::SetItem(ssize_t index, ::LUA_MODULE_NAME::Object arg) {
		Message* message = this->message.get();
		const FieldDescriptor* field_descriptor = this->field_descriptor.get();
		const Reflection* reflection = message->GetReflection();

		int field_size = reflection->FieldSize(*message, field_descriptor);

		if (index < 0) {
			index += field_size;
		}

		MP_ASSERT_RETURN_IF_ERROR(index >= 0 && index < field_size, "list index (" << index << ") out of range");

		if (arg.isnil()) {
			std::vector<::LUA_MODULE_NAME::Object> list;
			return Splice(list, index, 1);
		}

		switch (field_descriptor->cpp_type()) {
		case FieldDescriptor::CPPTYPE_INT32: {
			bool is_valid;
			auto value_holder = ::LUA_MODULE_NAME::lua_to(arg, static_cast<int*>(nullptr), is_valid);
			MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
			decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<int*>(nullptr));
			reflection->SetRepeatedInt32(message, field_descriptor, index, value);
			break;
		}
		case FieldDescriptor::CPPTYPE_INT64: {
			bool is_valid;
			auto value_holder = ::LUA_MODULE_NAME::lua_to(arg, static_cast<int64_t*>(nullptr), is_valid);
			MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
			decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<int64_t*>(nullptr));
			reflection->SetRepeatedInt64(message, field_descriptor, index, value);
			break;
		}
		case FieldDescriptor::CPPTYPE_UINT32: {
			bool is_valid;
			auto value_holder = ::LUA_MODULE_NAME::lua_to(arg, static_cast<uint*>(nullptr), is_valid);
			MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
			decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<uint*>(nullptr));
			reflection->SetRepeatedUInt32(message, field_descriptor, index, value);
			break;
		}
		case FieldDescriptor::CPPTYPE_UINT64: {
			bool is_valid;
			auto value_holder = ::LUA_MODULE_NAME::lua_to(arg, static_cast<uint64_t*>(nullptr), is_valid);
			MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
			decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<uint64_t*>(nullptr));
			reflection->SetRepeatedUInt64(message, field_descriptor, index, value);
			break;
		}
		case FieldDescriptor::CPPTYPE_FLOAT: {
			bool is_valid;
			auto value_holder = ::LUA_MODULE_NAME::lua_to(arg, static_cast<float*>(nullptr), is_valid);
			MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
			decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<float*>(nullptr));
			reflection->SetRepeatedFloat(message, field_descriptor, index, value);
			break;
		}
		case FieldDescriptor::CPPTYPE_DOUBLE: {
			bool is_valid;
			auto value_holder = ::LUA_MODULE_NAME::lua_to(arg, static_cast<double*>(nullptr), is_valid);
			MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
			decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<double*>(nullptr));
			reflection->SetRepeatedDouble(message, field_descriptor, index, value);
			break;
		}
		case FieldDescriptor::CPPTYPE_BOOL: {
			bool is_valid;
			auto value_holder = ::LUA_MODULE_NAME::lua_to(arg, static_cast<bool*>(nullptr), is_valid);
			MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
			decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<bool*>(nullptr));
			reflection->SetRepeatedBool(message, field_descriptor, index, value);
			break;
		}
		case FieldDescriptor::CPPTYPE_STRING: {
			bool is_valid;
			auto value_holder = ::LUA_MODULE_NAME::lua_to(arg, static_cast<std::string*>(nullptr), is_valid);
			MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
			decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<std::string*>(nullptr));
			reflection->SetRepeatedString(message, field_descriptor, index, std::move(value));
			break;
		}
		case FieldDescriptor::CPPTYPE_ENUM: {
			bool is_valid;
			auto value_holder = ::LUA_MODULE_NAME::lua_to(arg, static_cast<int*>(nullptr), is_valid);
			MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
			decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<int*>(nullptr));
			if (reflection->SupportsUnknownEnumValues()) {
				reflection->SetRepeatedEnumValue(message, field_descriptor, index, value);
			} else {
				const EnumDescriptor* enum_descriptor = field_descriptor->enum_type();
				const EnumValueDescriptor* enum_value = enum_descriptor->FindValueByNumber(value);
				MP_ASSERT_RETURN_IF_ERROR(enum_value != nullptr, "Unknown enum value: " << value);
				reflection->SetRepeatedEnum(message, field_descriptor, index, enum_value);
			}
			break;
		}
		case FieldDescriptor::CPPTYPE_MESSAGE: {
			MP_ASSERT_RETURN_IF_ERROR(arg.isnil(), "does not support assignment");
			MP_RETURN_IF_ERROR(Pop(index).status());
			break;
		}
		default:
			MP_ASSERT_RETURN_IF_ERROR(false, "Adding value to a field of unknown type " << field_descriptor->cpp_type());
		}
		return absl::OkStatus();
	}

	absl::Status RepeatedContainer::Splice(std::vector<::LUA_MODULE_NAME::Object>& list, ssize_t start) {
		auto field_size = size();
		if (start < 0) {
			start += field_size;
		}
		return Splice(list, start, field_size - start);
	}

	absl::Status RepeatedContainer::Splice(std::vector<::LUA_MODULE_NAME::Object>& list, ssize_t start, ssize_t deleteCount) {
		list.clear();

		if (deleteCount <= 0) {
			return absl::OkStatus();
		}

		Message* message = this->message.get();
		const FieldDescriptor* field_descriptor = this->field_descriptor.get();
		const Reflection* reflection = message->GetReflection();

		int field_size = reflection->FieldSize(*message, field_descriptor);

		if (start < 0) {
			start += field_size;
		}

		MP_ASSERT_RETURN_IF_ERROR(start >= 0 && start < field_size, "splice index out of range");

		if (deleteCount > (field_size - start)) {
			deleteCount = field_size - start;
		}

		int end = start + deleteCount;

		for (int i = start; i < end && i + deleteCount < field_size; i++) {
			reflection->SwapElements(message, field_descriptor, i, i + deleteCount);
		}

		Arena* arena = Arena::InternalHelper<Message>::GetArenaForAllocation(message);
		GOOGLE_DCHECK_EQ(arena, nullptr) << "lua protobuf is expected to be allocated from heap";

		list.resize(deleteCount);

		// Remove items, starting from the end.
		for (int i = 0; deleteCount > 0; i++, deleteCount--) {
			if (field_descriptor->cpp_type() != FieldDescriptor::CPPTYPE_MESSAGE) {
				MP_ASSIGN_OR_RETURN(auto item, GetItem(field_size - 1 - i));
				list[deleteCount - 1 - i] = item;
				reflection->RemoveLast(message, field_descriptor);
				continue;
			}

			// It seems that RemoveLast() is less efficient for sub-messages, and
			// the memory is not completely released. Prefer ReleaseLast().
			//
			// To work around a debug hardening (PROTOBUF_FORCE_COPY_IN_RELEASE),
			// explicitly use UnsafeArenaReleaseLast. To not break rare use cases where
			// arena is used, we fallback to ReleaseLast (but GOOGLE_DCHECK to find/fix it).
			//
			// Note that arena is likely null and GOOGLE_DCHECK and ReleaesLast might be
			// redundant. The current approach takes extra cautious path not to disrupt
			// production.
			Message* sub_message =
				(arena == nullptr)
				? reflection->UnsafeArenaReleaseLast(message, field_descriptor)
				: reflection->ReleaseLast(message, field_descriptor);

			// transfert ownership of sub message to list
			list[deleteCount - 1 - i] = ::LUA_MODULE_NAME::Object(std::shared_ptr<Message>(sub_message));
		}

		return absl::OkStatus();
	}

	absl::Status RepeatedContainer::Slice(std::vector<::LUA_MODULE_NAME::Object>& list, ssize_t start) const {
		int field_size = size();
		if (start < 0) {
			start += field_size;
		}
		return Slice(list, start, field_size - start);
	}

	absl::Status RepeatedContainer::Slice(std::vector<::LUA_MODULE_NAME::Object>& list, ssize_t start, ssize_t count) const {
		list.clear();
		if (count <= 0) {
			return absl::OkStatus();
		}
		list.resize(count);
		for (size_t i = 0; i < count; i++) {
			MP_ASSIGN_OR_RETURN(auto item, GetItem(start + i));
			list[i] = item;
		}
		return absl::OkStatus();
	}

	absl::StatusOr<::LUA_MODULE_NAME::Object> RepeatedContainer::DeepCopy() {
		return cmessage::DeepCopy(message.get(), field_descriptor.get());
	}

	absl::StatusOr<Message*> RepeatedContainer::Add(const std::map<std::string, ::LUA_MODULE_NAME::Object>& attrs) {
		Message* message = this->message.get();
		const FieldDescriptor* field_descriptor = this->field_descriptor.get();
		const Reflection* reflection = message->GetReflection();

		MP_ASSERT_RETURN_IF_ERROR(field_descriptor->cpp_type() == FieldDescriptor::CPPTYPE_MESSAGE, "field is not a message field");

		Message* sub_message = reflection->AddMessage(message, field_descriptor);
		MP_RETURN_IF_ERROR(cmessage::InitAttributes(*sub_message, attrs));
		return sub_message;
	}

	absl::Status RepeatedContainer::Append(::LUA_MODULE_NAME::Object item) {
		Message* message = this->message.get();
		const FieldDescriptor* field_descriptor = this->field_descriptor.get();
		const Reflection* reflection = message->GetReflection();

		switch (field_descriptor->cpp_type()) {
		case FieldDescriptor::CPPTYPE_INT32: {
			bool is_valid;
			auto value_holder = ::LUA_MODULE_NAME::lua_to(item, static_cast<int*>(nullptr), is_valid);
			MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
			decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<int*>(nullptr));
			reflection->AddInt32(message, field_descriptor, value);
			break;
		}
		case FieldDescriptor::CPPTYPE_INT64: {
			bool is_valid;
			auto value_holder = ::LUA_MODULE_NAME::lua_to(item, static_cast<int64_t*>(nullptr), is_valid);
			MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
			decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<int64_t*>(nullptr));
			reflection->AddInt64(message, field_descriptor, value);
			break;
		}
		case FieldDescriptor::CPPTYPE_UINT32: {
			bool is_valid;
			auto value_holder = ::LUA_MODULE_NAME::lua_to(item, static_cast<uint*>(nullptr), is_valid);
			MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
			decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<uint*>(nullptr));
			reflection->AddUInt32(message, field_descriptor, value);
			break;
		}
		case FieldDescriptor::CPPTYPE_UINT64: {
			bool is_valid;
			auto value_holder = ::LUA_MODULE_NAME::lua_to(item, static_cast<uint64_t*>(nullptr), is_valid);
			MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
			decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<uint64_t*>(nullptr));
			reflection->AddUInt64(message, field_descriptor, value);
			break;
		}
		case FieldDescriptor::CPPTYPE_FLOAT: {
			bool is_valid;
			auto value_holder = ::LUA_MODULE_NAME::lua_to(item, static_cast<float*>(nullptr), is_valid);
			MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
			decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<float*>(nullptr));
			reflection->AddFloat(message, field_descriptor, value);
			break;
		}
		case FieldDescriptor::CPPTYPE_DOUBLE: {
			bool is_valid;
			auto value_holder = ::LUA_MODULE_NAME::lua_to(item, static_cast<double*>(nullptr), is_valid);
			MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
			decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<double*>(nullptr));
			reflection->AddDouble(message, field_descriptor, value);
			break;
		}
		case FieldDescriptor::CPPTYPE_BOOL: {
			bool is_valid;
			auto value_holder = ::LUA_MODULE_NAME::lua_to(item, static_cast<bool*>(nullptr), is_valid);
			MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
			decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<bool*>(nullptr));
			reflection->AddBool(message, field_descriptor, value);
			break;
		}
		case FieldDescriptor::CPPTYPE_STRING: {
			bool is_valid;
			auto value_holder = ::LUA_MODULE_NAME::lua_to(item, static_cast<std::string*>(nullptr), is_valid);
			MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
			decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<std::string*>(nullptr));
			reflection->AddString(message, field_descriptor, std::move(value));
			break;
		}
		case FieldDescriptor::CPPTYPE_ENUM: {
			bool is_valid;
			auto value_holder = ::LUA_MODULE_NAME::lua_to(item, static_cast<int*>(nullptr), is_valid);
			MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
			decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<int*>(nullptr));
			if (reflection->SupportsUnknownEnumValues()) {
				reflection->AddEnumValue(message, field_descriptor, value);
			} else {
				const EnumDescriptor* enum_descriptor = field_descriptor->enum_type();
				const EnumValueDescriptor* enum_value = enum_descriptor->FindValueByNumber(value);
				MP_ASSERT_RETURN_IF_ERROR(enum_value != nullptr, "Unknown enum value: " << value);
				reflection->AddEnum(message, field_descriptor, enum_value);
			}
			break;
		}
		case FieldDescriptor::CPPTYPE_MESSAGE: {
			MP_ASSIGN_OR_RETURN(auto sub_message, Add());
			std::map<std::string, ::LUA_MODULE_NAME::Object> sub_attrs;
			bool is_valid;
			::LUA_MODULE_NAME::lua_to(item, sub_attrs, is_valid);
			if (is_valid) {
				MP_RETURN_IF_ERROR(cmessage::InitAttributes(*sub_message, sub_attrs));
			}
			else {
				auto value_holder = ::LUA_MODULE_NAME::lua_to(item, static_cast<Message*>(nullptr), is_valid);
				MP_ASSERT_RETURN_IF_ERROR(is_valid, "expecting type " << field_descriptor->cpp_type());
				decltype(auto) value = ::LUA_MODULE_NAME::extract_holder(value_holder, static_cast<Message*>(nullptr));
				sub_message->MergeFrom(value);
			}
			break;
		}
		default:
			MP_ASSERT_RETURN_IF_ERROR(false, "Adding value to a field of unknown type " << field_descriptor->cpp_type());
		}

		return absl::OkStatus();
	}

	absl::Status RepeatedContainer::Extend(const std::vector<::LUA_MODULE_NAME::Object>& items) {
		for (auto& item : items) {
			MP_RETURN_IF_ERROR(Append(item));
		}
		return absl::OkStatus();
	}

	absl::Status RepeatedContainer::Insert(ssize_t index, ::LUA_MODULE_NAME::Object item) {
		Message* message = this->message.get();
		const FieldDescriptor* field_descriptor = this->field_descriptor.get();
		const Reflection* reflection = message->GetReflection();

		int field_size = reflection->FieldSize(*message, field_descriptor);
		if (index < 0) {
			index += field_size;
		}

		MP_ASSERT_RETURN_IF_ERROR(index >= 0 && index <= field_size, "list index (" << index << ") out of range");

		MP_RETURN_IF_ERROR(Append(item));

		for (int i = index; i < field_size; i++) {
			reflection->SwapElements(message, field_descriptor, i, field_size);
		}
	}

	absl::Status RepeatedContainer::Insert(std::tuple<ssize_t, ::LUA_MODULE_NAME::Object>& args) {
		return Insert(std::get<0>(args), std::get<1>(args));
	}

	absl::StatusOr<::LUA_MODULE_NAME::Object> RepeatedContainer::Pop(ssize_t index) {
		std::vector<::LUA_MODULE_NAME::Object> list;
		MP_RETURN_IF_ERROR(Splice(list, index, 1));
		return list[0];
	}

	absl::Status RepeatedContainer::Sort(RepeatedContainer::Comparator comp) {
		std::vector<::LUA_MODULE_NAME::Object> list;
		MP_RETURN_IF_ERROR(Slice(list));

		auto begin = std::begin(list);
		std::sort(begin, begin + list.size(), comp);

		return InternalAssignRepeatedField(this, list);
	}

	void RepeatedContainer::Reverse() {
		Message* message = this->message.get();
		const FieldDescriptor* field_descriptor = this->field_descriptor.get();
		const Reflection* reflection = message->GetReflection();

		int field_size = reflection->FieldSize(*message, field_descriptor);
		for (int i = 0; i < field_size / 2; i++) {
			reflection->SwapElements(message, field_descriptor, i, field_size - 1 - i);
		}
	}

	void RepeatedContainer::Clear() {
		Message* message = this->message.get();
		const FieldDescriptor* field_descriptor = this->field_descriptor.get();
		const Reflection* reflection = message->GetReflection();
		reflection->ClearField(message, field_descriptor);
	}

	absl::Status RepeatedContainer::MergeFrom(const RepeatedContainer& other) {
		auto field_size = other.size();
		for (int i = 0; i < field_size; i++) {
			MP_ASSIGN_OR_RETURN(auto item, other.GetItem(i));
			MP_RETURN_IF_ERROR(Append(item));
		}
		return absl::OkStatus();
	}

	absl::Status RepeatedContainer::MergeFrom(const std::vector<::LUA_MODULE_NAME::Object>& other) {
		for (const auto& item : other) {
			MP_RETURN_IF_ERROR(Append(item));
		}
		return absl::OkStatus();
	}

	std::string RepeatedContainer::ToStr() const {
		std::string output;
		// TODO
		return output;
	}

	RepeatedIterator RepeatedContainer::begin() {
		return { this, 0 };
	}

	RepeatedIterator RepeatedContainer::end() {
		return { this, size() };
	}
}
