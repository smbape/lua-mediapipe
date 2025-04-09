#pragma once

#include "absl/status/status.h"
#include <opencv2/core/cvdef.h>

namespace mediapipe::lua::solutions::download_utils {
	/**
	 * Downloads the oss model from Google Cloud Storage if it doesn't exist in the package.
	 * @param model_path [description]
	 */
	CV_WRAP [[nodiscard]] absl::Status download_oss_model(
		const std::string& model_path,
		const std::string& hash = std::string(),
		const bool force = false,
		const char verbose = 0
	);

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
		const char verbose = 0
	);
}
