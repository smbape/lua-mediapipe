#pragma once

#include "mediapipe/framework/packet.h"
#include "mediapipe/framework/timestamp.h"
#include "binding/util.h"

namespace LUA_MODULE_NAME {
	const std::string Packet__tostring(const mediapipe::Packet& packet);
}
