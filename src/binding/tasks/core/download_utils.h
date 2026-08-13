#pragma once

#include "absl/status/status.h"
#include <opencv2/core/cvdef.h>

namespace mediapipe::tasks::lua::core::download_utils {
	/**
	 * Call embedded curl executable
	 * 
	 * @param  argv command line arguments for curl
	 * @return      absl::okStatus() if the call was successful
	 */
	CV_WRAP [[nodiscard]] absl::Status curl(const std::vector<std::string>& argv);

	/**
	 * @brief download a file
	 *
	 * @param  url                          [description]
	 * @param  output                       [description]
	 * @param  hash                         Downloaded file must validate the given hash
	 * @param  force                        Overwrite existing file
	 * @param  verbose                      Make the operation more talkative
	 * @return                              absl::okStatus() if download was successful
	 */
	CV_WRAP [[nodiscard]] absl::Status download(
		const std::string& url,
		const std::string& output,
		const std::string& hash = std::string(),
		const bool force = false,
		const char verbose = 0,
		const std::vector<std::string>& argv = std::vector<std::string>()
	);
}
