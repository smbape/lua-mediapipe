#include "mediapipe/framework/port/status_macros.h"
#include "binding/packet_getter.h"

using namespace mediapipe;
using namespace proto_ns;

// RegisteredTypeName()

namespace mediapipe::lua::packet_getter {
	absl::StatusOr<int64_t> get_int(const Packet& packet) {
		if (packet.ValidateAsType<int>().ok()) {
			return static_cast<int64_t>(packet.Get<int>());
		}

		if (packet.ValidateAsType<int8_t>().ok()) {
			return static_cast<int64_t>(packet.Get<int8_t>());
		}

		if (packet.ValidateAsType<int16_t>().ok()) {
			return static_cast<int64_t>(packet.Get<int16_t>());
		}

		if (packet.ValidateAsType<int32_t>().ok()) {
			return static_cast<int64_t>(packet.Get<int32_t>());
		}

		if (packet.ValidateAsType<int64_t>().ok()) {
			return static_cast<int64_t>(packet.Get<int64_t>());
		}

		MP_ASSERT_RETURN_IF_ERROR(false, "Packet doesn't contain int, int8, int16, int32, or int64 data.");
	}

	absl::StatusOr<uint64_t> get_uint(const Packet& packet) {
		if (packet.ValidateAsType<uint8_t>().ok()) {
			return static_cast<std::uint64_t>(packet.Get<uint8_t>());
		}

		if (packet.ValidateAsType<uint16_t>().ok()) {
			return static_cast<std::uint64_t>(packet.Get<uint16_t>());
		}

		if (packet.ValidateAsType<uint32_t>().ok()) {
			return static_cast<std::uint64_t>(packet.Get<uint32_t>());
		}

		if (packet.ValidateAsType<uint64_t>().ok()) {
			return static_cast<std::uint64_t>(packet.Get<uint64_t>());
		}

		MP_ASSERT_RETURN_IF_ERROR(false, "Packet doesn't contain uint8, uint16, uint32, or uint64 data.");
	}

	absl::StatusOr<float> get_float(const Packet& packet) {
		if (packet.ValidateAsType<float>().ok()) {
			return packet.Get<float>();
		}

		if (packet.ValidateAsType<double>().ok()) {
			return static_cast<float>(packet.Get<double>());
		}

		MP_ASSERT_RETURN_IF_ERROR(false, "Packet doesn't contain float or double data.");
	}

	absl::StatusOr<std::vector<int64_t>> get_int_list(const Packet& packet) {
		if (packet.ValidateAsType<std::vector<int>>().ok()) {
			auto int_list = packet.Get<std::vector<int>>();
			return std::vector<int64_t>(int_list.begin(), int_list.end());
		}

		if (packet.ValidateAsType<std::vector<int8_t>>().ok()) {
			auto int_list = packet.Get<std::vector<int8_t>>();
			return std::vector<int64_t>(int_list.begin(), int_list.end());
		}

		if (packet.ValidateAsType<std::vector<int16_t>>().ok()) {
			auto int_list = packet.Get<std::vector<int16_t>>();
			return std::vector<int64_t>(int_list.begin(), int_list.end());
		}

		if (packet.ValidateAsType<std::vector<int32_t>>().ok()) {
			auto int_list = packet.Get<std::vector<int32_t>>();
			return std::vector<int64_t>(int_list.begin(), int_list.end());
		}

		if (packet.ValidateAsType<std::vector<int64_t>>().ok()) {
			auto int_list = packet.Get<std::vector<int64_t>>();
			return std::vector<int64_t>(int_list.begin(), int_list.end());
		}

		MP_ASSERT_RETURN_IF_ERROR(false, "Packet doesn't contain int, int8, int16, int32, or int64 containers.");
	}

	absl::StatusOr<std::vector<float>> get_float_list(const Packet& packet) {
		if (packet.ValidateAsType<std::vector<float>>().ok()) {
			return packet.Get<std::vector<float>>();
		}

		if (packet.ValidateAsType<std::array<float, 16>>().ok()) {
			auto float_array = packet.Get<std::array<float, 16>>();
			return std::vector<float>(float_array.begin(), float_array.end());
		}

		if (packet.ValidateAsType<std::array<float, 4>>().ok()) {
			auto float_array = packet.Get<std::array<float, 4>>();
			return std::vector<float>(float_array.begin(), float_array.end());
		}

		MP_ASSERT_RETURN_IF_ERROR(false, "Packet doesn't contain std::vector<float> or std::array<float, 4 / 16> containers.");
	}

	absl::StatusOr<std::shared_ptr<Message>> MessageFromDynamicProto(const std::string& type_name, const std::string& serialized) {
		using namespace packet_internal;

		MP_ASSIGN_OR_RETURN(auto message_holder, MessageHolderRegistry::CreateByName(type_name));

		auto* copy = const_cast<proto_ns::MessageLite*>(message_holder->GetProtoMessageLite());
		MP_ASSERT_RETURN_IF_ERROR(copy->ParseFromString(serialized), "Failed to get proto message from packet " << type_name);

		MP_ASSIGN_OR_RETURN(auto message_ptr, message_holder->ReleaseProtoMessageLite());

		return std::shared_ptr<Message>(static_cast<Message*>(message_ptr.release()));
	}

	absl::StatusOr<std::shared_ptr<Message>> get_proto(const Packet& packet) {
		const auto& message = packet.GetProtoMessageLite();
		const std::string& type_name = message.GetTypeName();
		const std::string& serialized = message.SerializeAsString();
		return MessageFromDynamicProto(type_name, serialized);
	}

	absl::Status get_proto_list(const Packet& packet, std::vector<std::shared_ptr<Message>>& proto_list) {
		if (packet.IsEmpty()) {
			return absl::OkStatus();
		}

		MP_ASSIGN_OR_RETURN(auto proto_vector, packet.GetVectorOfProtoMessageLitePtrs());

		auto size = proto_vector.size();
		if (size == 0) {
			return absl::OkStatus();
		}

		proto_list.resize(size);
		auto type_name = proto_vector[0]->GetTypeName();

		int i = 0;
		for (const MessageLite* proto : proto_vector) {
			const std::string& serialized = proto->SerializeAsString();
			MP_ASSIGN_OR_RETURN(proto_list[i++], MessageFromDynamicProto(type_name, serialized));
		}

		return absl::OkStatus();
	}

	absl::Status get_image_frame_list(const Packet& packet, std::vector<std::shared_ptr<ImageFrame>>& image_frame_list) {
		if (packet.IsEmpty()) {
			return absl::OkStatus();
		}

		const std::vector<ImageFrame>& image_frame_vector = packet.Get<std::vector<ImageFrame>>();

		auto size = image_frame_vector.size();
		if (size == 0) {
			return absl::OkStatus();
		}

		image_frame_list.resize(size);
		int i = 0;
		for (const ImageFrame& image_frame : image_frame_vector) {
			image_frame_list[i++] = std::make_shared<ImageFrame>(
				image_frame.Format(), image_frame.Width(), image_frame.Height(),
				image_frame.WidthStep(), const_cast<uint8_t*>(image_frame.PixelData()),
				// Capture the packet by copy to ensure that the returned ImageFrames
				// outlive the input ImageFrames. Destroy the captured packet when the
				// deleter is called to ensure that the input ImageFrames can be
				// released when no longer needed.
				/*deleter=*/[p = packet](uint8_t*) mutable { p = Packet(); });
		}

		return absl::OkStatus();
	}
}
