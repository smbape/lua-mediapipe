#pragma once

#include "mediapipe/framework/formats/landmark.pb.h"
#include <opencv2/core/cvdef.h>
#include "binding/util.h"

namespace mediapipe::tasks::lua::components::containers::landmark {
	struct CV_EXPORTS_W_SIMPLE Landmark {
		CV_WRAP Landmark(const landmark::Landmark& other) = default;
		Landmark& operator=(const landmark::Landmark& other) = default;

		CV_WRAP Landmark(
			float x = 0.0f,
			float y = 0.0f,
			float z = 0.0f,
			float visibility = 0.0f,
			float presence = 0.0f
		)
			:
			x(x),
			y(y),
			z(z),
			visibility(visibility),
			presence(presence)
		{}

		CV_WRAP std::shared_ptr<mediapipe::Landmark> to_pb2() const;
		CV_WRAP static std::shared_ptr<landmark::Landmark> create_from_pb2(const mediapipe::Landmark& pb2_obj);

		bool operator== (const Landmark& other) const {
			return ::mediapipe::lua::__eq__(x, other.x) &&
				::mediapipe::lua::__eq__(y, other.y) &&
				::mediapipe::lua::__eq__(z, other.z) &&
				::mediapipe::lua::__eq__(visibility, other.visibility) &&
				::mediapipe::lua::__eq__(presence, other.presence);
		}

		CV_PROP_RW float x;
		CV_PROP_RW float y;
		CV_PROP_RW float z;
		CV_PROP_RW float visibility;
		CV_PROP_RW float presence;
	};

	struct CV_EXPORTS_W_SIMPLE NormalizedLandmark {
		CV_WRAP NormalizedLandmark(const landmark::NormalizedLandmark& other) = default;
		NormalizedLandmark& operator=(const landmark::NormalizedLandmark& other) = default;

		CV_WRAP NormalizedLandmark(
			float x = 0.0f,
			float y = 0.0f,
			float z = 0.0f,
			float visibility = 0.0f,
			float presence = 0.0f
		)
			:
			x(x),
			y(y),
			z(z),
			visibility(visibility),
			presence(presence)
		{}

		CV_WRAP std::shared_ptr<mediapipe::NormalizedLandmark> to_pb2() const;
		CV_WRAP static std::shared_ptr<landmark::NormalizedLandmark> create_from_pb2(const mediapipe::NormalizedLandmark& pb2_obj);

		bool operator== (const NormalizedLandmark& other) const {
			return ::mediapipe::lua::__eq__(x, other.x) &&
				::mediapipe::lua::__eq__(y, other.y) &&
				::mediapipe::lua::__eq__(z, other.z) &&
				::mediapipe::lua::__eq__(visibility, other.visibility) &&
				::mediapipe::lua::__eq__(presence, other.presence);
		}

		CV_PROP_RW float x;
		CV_PROP_RW float y;
		CV_PROP_RW float z;
		CV_PROP_RW float visibility;
		CV_PROP_RW float presence;
	};
}
