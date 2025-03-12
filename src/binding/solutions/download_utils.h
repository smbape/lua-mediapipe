#pragma once

#include "absl/status/status.h"
#include <opencv2/core/cvdef.h>

namespace mediapipe::lua::solutions::download_utils {
	/**
	 * Downloads the oss model from Google Cloud Storage if it doesn't exist in the package.
	 * @param model_path [description]
	 */
	CV_WRAP [[nodiscard]] absl::Status download_oss_model(const std::string& model_path, const std::string& hash = std::string(), const bool force = false, const bool verbose = false);

	struct DownloadParams {
		const std::string& url;
		const std::string& file;
		const std::string& hash = std::string();
		const bool force = false;
		const std::optional<std::string> abstract_unix_socket = std::nullopt;
		const std::string& altsvc = std::string();
		const bool anyauth = false;
		const std::optional<std::string> aws_sigv4 = std::nullopt;
		const bool basic = false;
		const bool ca_native = false;
		const std::optional<std::string> cacert = std::nullopt;
		const std::optional<std::string> capath = std::nullopt;
		const std::optional<std::string> cert = std::nullopt;
		const bool cert_status = false;
		const std::optional<std::string> cert_type = std::nullopt;
		const std::optional<std::string> cipher_list = std::nullopt;
		const bool compressed = false;
		const std::optional<long> connect_timeout = std::nullopt;
		const std::vector<std::string>& connect_to = std::vector<std::string>();
		const std::vector<std::string>& cookies = std::vector<std::string>();
		const std::optional<std::string> cookie_jar = std::nullopt;
		const std::optional<std::string> crlfile = std::nullopt;
		const std::optional<std::string> curves = std::nullopt;
		const std::optional<std::string> data = std::nullopt;
		const std::optional<bool> digest = std::nullopt;
		const bool disallow_username_in_url = false;
		const bool verbose = false;
	};

	absl::Status download(const DownloadParams& params);

	/**
	 * @brief download a file
	 *
	 * @param  url                      [description]
	 * @param  file                     [description]
	 * @param  hash                     Downloaded file must validate the given hash
	 * @param  force                    [description]
	 * @param  abstract_unix_socket     Connect via abstract Unix domain socket
	 * @param  altsvc                   Enable alt-svc with this cache fil
	 * @param  anyauth                  Pick any authentication method
	 * @param  aws_sigv4                AWS V4 signature auth
	 * @param  basic                    HTTP Basic Authentication
	 * @param  ca_native                Load CA certs from the OS
	 * @param  cacert                   CA certificate to verify peer against
	 * @param  capath                   CA directory to verify peer against
	 * @param  cert                     Client certificate file and password
	 * @param  cert_status              Verify server cert status OCSP-staple
	 * @param  cert_type                Certificate type (DER/PEM/ENG/PROV/P12)
	 * @param  cipher_list              TLS 1.2 (1.1, 1.0) ciphers to use
	 * @param  compressed               Request compressed response
	 * @param  connect_timeout          Maximum time allowed to connect
	 * @param  connect_to               Connect to host2 instead of host1
	 * @param  cookies                  Send cookies from string/load from file
	 * @param  crlfile                  Certificate Revocation list
	 * @param  curves                   (EC) TLS key exchange algorithms to request
	 * @param  verbose                  Make the operation more talkative
	 * @param  data                     HTTP POST data
	 * @param  digest                   HTTP Digest Authentication
	 * @param  disallow_username_in_url Disallow username in URL
	 * @return                          absl::okStatus() if download was successful
	 */
	CV_WRAP [[nodiscard]] absl::Status download(
		const std::string& url,
		const std::string& file,
		const std::string& hash = std::string(),
		const bool force = false,
		const std::optional<std::string> abstract_unix_socket = std::nullopt,
		const std::string& altsvc = std::string(),
		const bool anyauth = false,
		const std::optional<std::string> aws_sigv4 = std::nullopt,
		const bool basic = false,
		const bool ca_native = false,
		const std::optional<std::string> cacert = std::nullopt,
		const std::optional<std::string> capath = std::nullopt,
		const std::optional<std::string> cert = std::nullopt,
		const bool cert_status = false,
		const std::optional<std::string> cert_type = std::nullopt,
		const std::optional<std::string> cipher_list = std::nullopt,
		const bool compressed = false,
		const std::optional<long> connect_timeout = std::nullopt,
		const std::vector<std::string>& connect_to = std::vector<std::string>(),
		const std::vector<std::string>& cookies = std::vector<std::string>(),
		const std::optional<std::string> cookie_jar = std::nullopt,
		const std::optional<std::string> crlfile = std::nullopt,
		const std::optional<std::string> curves = std::nullopt,
		const std::optional<std::string> data = std::nullopt,
		const std::optional<bool> digest = std::nullopt,
		const bool disallow_username_in_url = false,
		const bool verbose = false
	);
}
