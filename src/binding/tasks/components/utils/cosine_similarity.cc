#include "binding/tasks/components/utils/cosine_similarity.h"
#include <opencv2/core.hpp>

namespace {
	/**
	 * Computes cosine similarity between two embeddings.
	 * @param  u An embedding
	 * @param  v An embedding
	 * @return   Cosine similarity value.
	 */
	[[nodiscard]] inline absl::StatusOr<float> _compute_cosine_similarity(const cv::Mat& u, const cv::Mat& v) {
		auto norm_u = cv::norm(u);
		auto norm_v = cv::norm(v);
		MP_ASSERT_RETURN_IF_ERROR(norm_u > 0 && norm_v > 0, "Cannot compute cosine similarity on embedding with 0 norm.");
		return u.dot(v) / (norm_u * norm_v);
	}
}

namespace mediapipe::tasks::lua::components::utils::cosine_similarity {
	absl::StatusOr<float> cosine_similarity(const containers::embedding_result::Embedding& u_embedding, const containers::embedding_result::Embedding& v_embedding) {
		const auto& u = u_embedding.embedding;
		const auto& v = v_embedding.embedding;

		MP_ASSERT_RETURN_IF_ERROR(!u.empty(), "Cannot compute cosing similarity on empty embeddings.");

		MP_ASSERT_RETURN_IF_ERROR(u.channels() == v.channels(),
			"Cannot compute cosine similarity between embeddings "
			"of different channels "
			"(" << u.channels() << " vs. " << v.channels() << ").");

		MP_ASSERT_RETURN_IF_ERROR(u.total() == v.total(),
			"Cannot compute cosine similarity between embeddings "
			"of different sizes "
			"(" << u.total() << " vs. " << v.total() << ").");

		MP_ASSERT_RETURN_IF_ERROR(u.type() == v.type(),
			"Cannot compute cosine similarity between quantized and "
			"float embeddings.");

		if (u.depth() == CV_32F) {
			return _compute_cosine_similarity(u, v);
		}

		if (u.depth() == CV_8U) {
			cv::Mat u_view_int8(u.dims, u.size.p, CV_MAKE_TYPE(CV_8S, u.channels()), static_cast<void*>(u.data), u.step.p);
			cv::Mat v_view_int8(v.dims, v.size.p, CV_MAKE_TYPE(CV_8S, v.channels()), static_cast<void*>(v.data), v.step.p);
			return _compute_cosine_similarity(u_view_int8, v_view_int8);
		}

		MP_ASSERT_RETURN_IF_ERROR(false, "Cannot compute cosine similarity of unsupported "
			"embeddings type. Only float and byte types are supported.");
	}
}
