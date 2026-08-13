#include "binding/tasks/components/containers/landmark.h"

namespace mediapipe::tasks::components::containers {

	mediapipe::Landmark ConvertLandmarkToProto(Landmark* landmark) {
		mediapipe::Landmark landmark_proto;
		landmark_proto.set_x(landmark->x);
		landmark_proto.set_y(landmark->y);
		landmark_proto.set_z(landmark->z);
		if (landmark->visibility) {
			landmark_proto.set_visibility(*landmark->visibility);
		}
		if (landmark->presence) {
			landmark_proto.set_presence(*landmark->presence);
		}
		return landmark_proto;
	}

	mediapipe::NormalizedLandmark ConvertNormalizedLandmarkToProto(NormalizedLandmark* normalized_landmark) {
		mediapipe::NormalizedLandmark normalized_landmark_proto;
		normalized_landmark_proto.set_x(normalized_landmark->x);
		normalized_landmark_proto.set_y(normalized_landmark->y);
		normalized_landmark_proto.set_z(normalized_landmark->z);
		if (normalized_landmark->visibility) {
			normalized_landmark_proto.set_visibility(*normalized_landmark->visibility);
		}
		if (normalized_landmark->presence) {
			normalized_landmark_proto.set_presence(*normalized_landmark->presence);
		}
		return normalized_landmark_proto;
	}

	mediapipe::LandmarkList ConvertLandmarkListToProto(Landmarks* landmarks) {
		mediapipe::LandmarkList landmark_list_proto;

		for (const auto& landmark : landmarks->landmarks) {
			landmark_list_proto.add_landmark()->CopyFrom(ConvertLandmarkToProto(const_cast<Landmark*>(&landmark)));
		}

		return landmark_list_proto;
	}

	mediapipe::NormalizedLandmarkList ConvertNormalizedLandmarkListToProto(NormalizedLandmarks* normalized_landmarks) {
		mediapipe::NormalizedLandmarkList normarlized_landmark_list_proto;

		for (const auto& normalized_landmark : normalized_landmarks->landmarks) {
			normarlized_landmark_list_proto.add_landmark()->CopyFrom(ConvertNormalizedLandmarkToProto(const_cast<NormalizedLandmark*>(&normalized_landmark)));
		}

		return normarlized_landmark_list_proto;
	}

	void CppConvertToLandmarks(const std::vector<Landmark>& landmark_result, Landmarks& landmarks) {
		landmarks.landmarks = landmark_result;
	}

	std::vector<Landmark>& CppConvertToLandmarkList(Landmarks& landmarks) {
		return landmarks.landmarks;
	}

	void CppConvertToNormalizedLandmarks(const std::vector<NormalizedLandmark>& normalized_landmark_result, NormalizedLandmarks& normalized_landmarks) {
		normalized_landmarks.landmarks = normalized_landmark_result;
	}

	std::vector<NormalizedLandmark>& CppConvertToNormalizedLandmarkList(NormalizedLandmarks& normalized_landmarks) {
		return normalized_landmarks.landmarks;
	}

	void CppConvertToLandmarksList(const std::vector<std::vector<Landmark>>& landmark_list_list, std::vector<Landmarks>& landmarks_list) {
		landmarks_list.clear();
		landmarks_list.reserve(landmark_list_list.size());
		for (const auto& landmarks : landmark_list_list) {
			landmarks_list.push_back({ .landmarks = landmarks });
		}
	}

	std::vector<std::vector<Landmark>> CppConvertToLandmarkListList(std::vector<Landmarks>& landmarks_list) {
		std::vector<std::vector<Landmark>> landmark_list_list;
		landmark_list_list.reserve(landmarks_list.size());
		for (const auto& landmarks : landmarks_list) {
			landmark_list_list.push_back(landmarks.landmarks);
		}
		return landmark_list_list;
	}

	void CppConvertToNormalizedLandmarksList(const std::vector<std::vector<NormalizedLandmark>>& normalized_landmark_list_list, std::vector<NormalizedLandmarks>& normalized_landmarks_list) {
		normalized_landmarks_list.clear();
		normalized_landmarks_list.reserve(normalized_landmark_list_list.size());
		for (const auto& landmarks : normalized_landmark_list_list) {
			normalized_landmarks_list.push_back({ .landmarks = landmarks });
		}
	}

	std::vector<std::vector<NormalizedLandmark>> CppConvertToNormalizedLandmarkListList(std::vector<NormalizedLandmarks>& normalized_landmarks_list) {
		std::vector<std::vector<NormalizedLandmark>> normalized_landmark_list_list;
		normalized_landmark_list_list.reserve(normalized_landmarks_list.size());
		for (const auto& normalized_landmarks : normalized_landmarks_list) {
			normalized_landmark_list_list.push_back(normalized_landmarks.landmarks);
		}
		return normalized_landmark_list_list;
	}
}