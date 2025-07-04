#include "binding/tasks/components/containers/embedding_result.h"

using namespace mediapipe::tasks::components::containers;

namespace mediapipe::tasks::lua::components::containers::embedding_result {
	std::shared_ptr<Embedding> Embedding::create_from_pb2(const proto::Embedding& pb2_obj) {
		auto embedding = std::make_shared<Embedding>();

		if (pb2_obj.has_float_embedding()) {
			std::vector<float> values(pb2_obj.float_embedding().values().begin(), pb2_obj.float_embedding().values().end());
			embedding->embedding = cv::Mat(values, true);
		}
		else {
			std::vector<unsigned char> values(pb2_obj.quantized_embedding().values().begin(), pb2_obj.quantized_embedding().values().end());
			embedding->embedding = cv::Mat(values, true);
		}

		embedding->head_index = pb2_obj.head_index();
		embedding->head_name = pb2_obj.head_name();
		return embedding;
	}

	std::shared_ptr<EmbeddingResult> EmbeddingResult::create_from_pb2(const proto::EmbeddingResult& pb2_obj) {
		auto embedding_result = std::make_shared<EmbeddingResult>();
		for (const auto& embedding : pb2_obj.embeddings()) {
			embedding_result->embeddings.push_back(std::move(Embedding::create_from_pb2(embedding)));
		}
		return embedding_result;
	}
}
