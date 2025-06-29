#pragma once

#include "binding/message.h"
#include "binding/ssize_t.h"

namespace google::protobuf::lua {
	struct RepeatedContainer;
	struct RepeatedIterator;

	struct RepeatedIterator {
		RepeatedIterator& operator++() noexcept;
		RepeatedIterator operator++(int) noexcept;
		bool operator==(const RepeatedIterator& other) const noexcept;
		bool operator!=(const RepeatedIterator& other) const noexcept;
		const ::LUA_MODULE_NAME::Object& operator*() noexcept;

		RepeatedContainer* container;
		size_t m_iter = 0;
		[[nodiscard]] absl::StatusOr<::LUA_MODULE_NAME::Object> m_value = ::LUA_MODULE_NAME::Object();
		bool m_dirty = true;
	};

	struct CV_EXPORTS_W_SIMPLE RepeatedContainer {
		using Comparator = std::function<bool(const ::LUA_MODULE_NAME::Object&, const ::LUA_MODULE_NAME::Object&)>;

		CV_WRAP RepeatedContainer() = default;
		CV_WRAP RepeatedContainer(const RepeatedContainer& other) = default;
		RepeatedContainer& operator=(const RepeatedContainer& other) = default;

		CV_WRAP_AS(length) size_t Length() const;
		CV_WRAP_AS(__len) size_t size() const;

		CV_WRAP_AS(__index) [[nodiscard]] absl::StatusOr<::LUA_MODULE_NAME::Object> GetItem(ssize_t index) const;
		CV_WRAP_AS(__newindex) [[nodiscard]] absl::Status SetItem(ssize_t index, ::LUA_MODULE_NAME::Object arg);
		CV_WRAP_AS(splice) [[nodiscard]] absl::Status Splice(CV_OUT std::vector<::LUA_MODULE_NAME::Object>& list, ssize_t start = 0);
		CV_WRAP_AS(splice) [[nodiscard]] absl::Status Splice(CV_OUT std::vector<::LUA_MODULE_NAME::Object>& list, ssize_t start, ssize_t deleteCount);
		CV_WRAP_AS(slice) [[nodiscard]] absl::Status Slice(CV_OUT std::vector<::LUA_MODULE_NAME::Object>& list, ssize_t start = 0) const;
		CV_WRAP_AS(slice) [[nodiscard]] absl::Status Slice(CV_OUT std::vector<::LUA_MODULE_NAME::Object>& list, ssize_t start, ssize_t count) const;
		CV_WRAP_AS(deepcopy) [[nodiscard]] absl::StatusOr<::LUA_MODULE_NAME::Object> DeepCopy();
		CV_WRAP_AS(add) [[nodiscard]] absl::StatusOr<Message*> Add(const std::map<std::string, ::LUA_MODULE_NAME::Object>& attrs = std::map<std::string, ::LUA_MODULE_NAME::Object>());
		CV_WRAP_AS(append) [[nodiscard]] absl::Status Append(::LUA_MODULE_NAME::Object item);
		CV_WRAP_AS(extend) [[nodiscard]] absl::Status Extend(const std::vector<::LUA_MODULE_NAME::Object>& items);
		CV_WRAP_AS(insert) [[nodiscard]] absl::Status Insert(ssize_t index, ::LUA_MODULE_NAME::Object item);
		CV_WRAP_AS(insert) [[nodiscard]] absl::Status Insert(std::tuple<ssize_t, ::LUA_MODULE_NAME::Object>& args);
		CV_WRAP_AS(pop) [[nodiscard]] absl::StatusOr<::LUA_MODULE_NAME::Object> Pop(ssize_t index = -1);
		CV_WRAP_AS(sort) [[nodiscard]] absl::Status Sort(RepeatedContainer::Comparator comp);
		CV_WRAP_AS(reverse) void Reverse();
		CV_WRAP_AS(clear) void Clear();
		CV_WRAP [[nodiscard]] absl::Status MergeFrom(const RepeatedContainer& other);
		CV_WRAP [[nodiscard]] absl::Status MergeFrom(const std::vector<::LUA_MODULE_NAME::Object>& other);

		CV_WRAP_AS(__tostring) std::string ToStr() const;

		using iterator = RepeatedIterator;
		using const_iterator = RepeatedIterator;

		iterator begin();
		iterator end();

		std::shared_ptr<Message> message;
		std::shared_ptr<FieldDescriptor> field_descriptor;
	};

	template<typename Element, typename _Tp>
	[[nodiscard]] absl::StatusOr<bool> RepeatedField_PrepareSplice(
		_Tp* repeatedField,
		std::vector<Element>& list,
		ssize_t start,
		ssize_t& deleteCount
	);

	template<typename Element>
	[[nodiscard]] absl::StatusOr<Element*> RepeatedField_AddMessage(RepeatedPtrField<Element>* repeatedField, const Element* message);

	template<typename Element>
	[[nodiscard]] absl::StatusOr<Element*> RepeatedField_AddMessage(RepeatedPtrField<Element>* repeatedField, std::map<std::string, ::LUA_MODULE_NAME::Object>& attrs);

	template<typename Element, typename _Tp>
	[[nodiscard]] absl::Status RepeatedField_SpliceScalar(_Tp* repeatedField, std::vector<Element>& list, ssize_t start, ssize_t deleteCount);

	template<typename Element, typename _Tp>
	[[nodiscard]] absl::Status RepeatedField_SpliceScalar(_Tp* repeatedField, std::vector<Element>& list, ssize_t start = 0);

	template<typename Element>
	[[nodiscard]] absl::Status RepeatedField_SpliceMessage(
		RepeatedPtrField<Element>* repeatedField,
		std::vector<std::shared_ptr<Element>>& list,
		ssize_t start,
		ssize_t deleteCount
	);

	template<typename Element>
	[[nodiscard]] absl::Status RepeatedField_SpliceMessage(
		RepeatedPtrField<Element>* repeatedField,
		std::vector<std::shared_ptr<Element>>& list,
		ssize_t start = 0
	);

	template<typename Element, typename _Tp>
	void RepeatedField_SliceScalar(
		_Tp* repeatedField,
		std::vector<Element>& list,
		ssize_t start,
		ssize_t count
	);

	template<typename Element, typename _Tp>
	void RepeatedField_SliceScalar(
		_Tp* repeatedField,
		std::vector<Element>& list,
		ssize_t start = 0
	);

	template<typename Element>
	void RepeatedField_SliceMessage(
		RepeatedPtrField<Element>* repeatedField,
		std::vector<std::shared_ptr<Element>>& list,
		ssize_t start,
		ssize_t count
	);

	template<typename Element>
	void RepeatedField_SliceMessage(
		RepeatedPtrField<Element>* repeatedField,
		std::vector<std::shared_ptr<Element>>& list,
		ssize_t start = 0
	);

	template<typename _Tp>
	void RepeatedField_ExtendScalar(
		_Tp* repeatedField,
		const _Tp& items
	);

	template<typename Element, typename _Tp>
	void RepeatedField_ExtendScalar(
		_Tp* repeatedField,
		const std::vector<Element>& items
	);

	template<typename Element>
	[[nodiscard]] absl::Status RepeatedField_ExtendMessage(
		RepeatedPtrField<Element>* repeatedField,
		const std::vector<std::shared_ptr<Element>>& items
	);

	template<typename Element>
	[[nodiscard]] absl::Status RepeatedField_ExtendMessage(
		RepeatedPtrField<Element>* repeatedField,
		const RepeatedPtrField<Element>& items
	);

	template<typename Element>
	[[nodiscard]] absl::Status RepeatedField_ExtendMessage(
		RepeatedPtrField<Element>* repeatedField,
		const std::vector<::LUA_MODULE_NAME::Object>& items
	);

	template<typename Element, typename _Tp>
	[[nodiscard]] absl::Status RepeatedField_InsertScalar(_Tp* repeatedField, ssize_t index, const Element& item);

	template<typename Element>
	[[nodiscard]] absl::Status RepeatedField_InsertMessage(RepeatedPtrField<Element>* repeatedField, ssize_t index, const Element* item);

	template<typename Element, typename _Tp>
	[[nodiscard]] absl::StatusOr<Element> RepeatedField_PopScalar(_Tp* repeatedField, ssize_t index = -1);

	template<typename Element>
	[[nodiscard]] absl::StatusOr<std::shared_ptr<Element>> RepeatedField_PopMessage(RepeatedPtrField<Element>* repeatedField, ssize_t index = -1);

	template<typename _Tp>
	void RepeatedField_Reverse(_Tp* repeatedField);

	template<typename _Tr, typename _Ti>
	[[nodiscard]] absl::Status RepeatedField_Set(Message& message, const std::string& field_name, ::LUA_MODULE_NAME::Object newVal, _Tr* repeated_field, _Ti& repeated_iterator);
}
