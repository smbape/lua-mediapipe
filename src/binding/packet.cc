#include "binding/packet.h"

using namespace mediapipe;
using mediapipe::lua::TimestampValueString;

namespace LUA_MODULE_NAME {
	const std::string Packet__tostring(const mediapipe::Packet& packet) {
		return absl::StrCat(
			"<mediapipe.Packet with timestamp: ",
			TimestampValueString(packet.Timestamp()),
			packet.IsEmpty()
				? " and no data>"
				: absl::StrCat(" and C++ type: ", packet.DebugTypeName(), ">")
		);
	}
}
