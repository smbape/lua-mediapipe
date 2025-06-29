#pragma once

#include "mediapipe/framework/formats/classification.pb.h"
#include "mediapipe/framework/formats/landmark.pb.h"
#include "mediapipe/tasks/cc/components/containers/proto/landmarks_detection_result.pb.h"
#include "binding/tasks/components/containers/category.h"
#include "binding/tasks/components/containers/landmark.h"
#include "binding/tasks/components/containers/rect.h"

namespace mediapipe::tasks::lua::components::containers::landmark_detection_result {
	struct CV_EXPORTS_W_SIMPLE LandmarksDetectionResult {
		CV_WRAP LandmarksDetectionResult(const LandmarksDetectionResult& other) = default;
		LandmarksDetectionResult& operator=(const LandmarksDetectionResult& other) = default;

		CV_WRAP LandmarksDetectionResult(
			const std::vector<std::shared_ptr<landmark::NormalizedLandmark>>& landmarks = std::vector<std::shared_ptr<landmark::NormalizedLandmark>>(),
			const std::vector<std::shared_ptr<category::Category>>& categories = std::vector<std::shared_ptr<category::Category>>(),
			const std::vector<std::shared_ptr<landmark::Landmark>>& world_landmarks = std::vector<std::shared_ptr<landmark::Landmark>>(),
			std::shared_ptr<rect::NormalizedRect> rect = std::shared_ptr<rect::NormalizedRect>()
		)
			:
			landmarks(landmarks),
			categories(categories),
			world_landmarks(world_landmarks),
			rect(rect)
		{}

		CV_WRAP std::shared_ptr<mediapipe::tasks::containers::proto::LandmarksDetectionResult> to_pb2() const;
		CV_WRAP static std::shared_ptr<LandmarksDetectionResult> create_from_pb2(const mediapipe::tasks::containers::proto::LandmarksDetectionResult& pb2_obj);

		bool operator== (const LandmarksDetectionResult& other) const {
			return ::mediapipe::lua::__eq__(landmarks, other.landmarks) &&
				::mediapipe::lua::__eq__(categories, other.categories) &&
				::mediapipe::lua::__eq__(world_landmarks, other.world_landmarks) &&
				::mediapipe::lua::__eq__(rect, other.rect);
		}

		CV_PROP_RW std::vector<std::shared_ptr<landmark::NormalizedLandmark>> landmarks;
		CV_PROP_RW std::vector<std::shared_ptr<category::Category>> categories;
		CV_PROP_RW std::vector<std::shared_ptr<landmark::Landmark>> world_landmarks;
		CV_PROP_RW std::shared_ptr<rect::NormalizedRect> rect;
	};
}
