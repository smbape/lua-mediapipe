#pragma once

#include "mediapipe/framework/timestamp.h"

namespace mediapipe::lua {
    inline std::string TimestampValueString(const Timestamp& timestamp) {
        if (timestamp == Timestamp::Unset()) {
            return "UNSET";
        }
        else if (timestamp == Timestamp::Unstarted()) {
            return "UNSTARTED";
        }
        else if (timestamp == Timestamp::PreStream()) {
            return "PRESTREAM";
        }
        else if (timestamp == Timestamp::Min()) {
            return "MIN";
        }
        else if (timestamp == Timestamp::Max()) {
            return "MAX";
        }
        else if (timestamp == Timestamp::PostStream()) {
            return "POSTSTREAM";
        }
        else if (timestamp == Timestamp::OneOverPostStream()) {
            return "ONEOVERPOSTSTREAM";
        }
        else if (timestamp == Timestamp::Done()) {
            return "DONE";
        }
        else {
            return timestamp.DebugString();
        }
    }
}
