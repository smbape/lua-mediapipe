#include "binding/solutions/download_utils.h"
#include "binding/resource_util.h"
#include "binding/util.h"

#include <filesystem>
#include <fstream>
#include <iostream>
#include <cstdio>

#include <curl/curl.h>
#include <curl/mprintf.h>

// curl_sha256 is not supposed to be publicly available
// however, this is a hacky way to perform sha256 without relying on openssl
#ifdef __cplusplus
extern "C" {
#endif

#ifdef _UNICODE

#if defined(__GNUC__) || defined(__clang__)
/* GCC does not know about wmain() */
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmissing-prototypes"
#pragma GCC diagnostic ignored "-Wmissing-declarations"
#endif

int tool_wmain(int argc, wchar_t *argv[]);
#pragma GCC diagnostic pop

#else /* _UNICODE */
int tool_main(int argc, char *argv[]);
#endif /* _UNICODE */

#include <curl_tool/lib/curl_sha256.h>
#ifdef __cplusplus
}
#endif

#define check_setopt( handle, option, parameter ) do { \
	CURLcode res = curl_easy_setopt(handle, option, parameter); \
	MP_ASSERT_RETURN_IF_ERROR(res == CURLE_OK, "curl_easy_setopt failed: " << curl_easy_strerror(res)); \
} while(0)

namespace fs = std::filesystem;

namespace {
	// https://a4z.gitlab.io/blog/2023/11/04/Compiletime-string-literals-processing.html
	constexpr size_t cstr_len(const char* const str) {
		size_t len = 0;
		while (*(str + len) != '\0') {
			len++;
		}
		return len;
	}

	constexpr auto SHA256_PREFIX = "sha256=";
	constexpr auto SHA256_PREFIX_LEN = cstr_len(SHA256_PREFIX);

	inline const bool startsWith(const std::string_view& s, const std::string_view& prefix) {
		return s.size() >= prefix.size() && s.compare(0, prefix.size(), prefix) == 0;
	}

	/* Convert sha256 or SHA-512/256 chunk to RFC7616 -suitable ASCII string */
	void auth_digest_sha256_to_ascii(
		unsigned char* source /* 32 bytes */,
		unsigned char* dest /* 65 bytes */
	) {
		for (int i = 0; i < 32; i++) {
			curl_msnprintf((char*)&dest[i * 2], 3, "%02x", source[i]);
		}
	}

	[[nodiscard]] inline absl::Status sha256_get_hash(const fs::path& file_abspath, std::string& output) {
		std::ifstream fp(file_abspath.native(), std::ios::in | std::ios::binary);
		MP_ASSERT_RETURN_IF_ERROR(fp.good(), "Cannot open " << file_abspath);

		unsigned char hashbuf[32]; /* 32 bytes/256 bits */
		memset(hashbuf, 0, sizeof(hashbuf));

		const auto& hashparams = Curl_HMAC_SHA256;

		auto ctxt = std::make_unique<unsigned char[]>(hashparams.ctxtsize);

		CURLcode res = hashparams.hinit(ctxt.get());
		MP_ASSERT_RETURN_IF_ERROR(res == CURLE_OK, "Failed to get hash of file " << file_abspath);

		constexpr const std::size_t buffer_size{ 1 << 12 };
		char buffer[buffer_size];
		while (fp.good()) {
			fp.read(buffer, buffer_size);
			hashparams.hupdate(ctxt.get(), reinterpret_cast<unsigned char*>(buffer), fp.gcount());
		}
		hashparams.hfinal(hashbuf, ctxt.get());

		output = std::move(std::string(64, '\0')); /* 64 digits */
		auth_digest_sha256_to_ascii(hashbuf, reinterpret_cast<unsigned char*>(&output[0]));

		return absl::OkStatus();
	}

	[[nodiscard]] inline absl::StatusOr<bool> check_hash(const fs::path& file_abspath, const std::string& hash, const bool force, const bool validate) {
		if (force || !fs::exists(file_abspath)) {
			return false;
		}

		if (hash.empty()) {
			return true;
		}

		std::string actual_hash;
		std::string expected_hash;

		if (startsWith(hash, SHA256_PREFIX)) {
			MP_RETURN_IF_ERROR(sha256_get_hash(file_abspath, actual_hash));
			expected_hash = hash.substr(SHA256_PREFIX_LEN);
		}
		else {
			MP_ASSERT_RETURN_IF_ERROR(false, "Unsupported hash " << hash);
		}

		const auto is_valid = actual_hash == expected_hash;

		if (validate) {
			MP_ASSERT_RETURN_IF_ERROR(is_valid, "Expected hash " << hash << " but got " << actual_hash);
		}

		return is_valid;
	}

#if defined(CURL_CA_BUNDLE) || !defined(_WIN32)
	std::optional<std::string> anonymous_cacert;
	const std::string& get_default_cacert() {
		if (!anonymous_cacert) {
			if (fs::exists("/etc/ssl/certs/ca-certificates.crt")) {
				anonymous_cacert = "/etc/ssl/certs/ca-certificates.crt";
			}
			else if (fs::exists("/etc/pki/tls/certs/ca-bundle.crt")) {
				anonymous_cacert = "/etc/pki/tls/certs/ca-bundle.crt";
			}
			else if (fs::exists("/usr/share/ssl/certs/ca-bundle.crt")) {
				anonymous_cacert = "/usr/share/ssl/certs/ca-bundle.crt";
			}
			else if (fs::exists("/usr/local/share/certs/ca-root-nss.crt")) {
				anonymous_cacert = "/usr/local/share/certs/ca-root-nss.crt";
			}
			else if (fs::exists("/etc/ssl/cert.pem")) {
				anonymous_cacert = "/etc/ssl/cert.pem";
			}
			else {
				anonymous_cacert = "";
			}
		}
		return *anonymous_cacert;
	}
#endif

#if defined(CURL_CA_PATH) || !defined(_WIN32)
	std::optional<std::string> anonymous_capath;
	const std::string& get_default_capath() {
		if (!anonymous_capath) {
			anonymous_capath = "";

			const auto status = fs::symlink_status("/etc/ssl/certs");
			if (!fs::is_directory(status)) {
				return *anonymous_capath;
			}

			for (const auto& dir_entry : fs::directory_iterator{ "/etc/ssl/certs" }) {
				// checking existence of a file [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f].0
				const auto& filename = dir_entry.path().filename().native();
				if (filename.size() != 10) {
					continue;
				}

				fs::path::string_type::size_type i = 0;

				for (; i < 8; ++i) {
					if (!(filename[i] >= 'a' && filename[i] <= 'z' || filename[i] >= '0' && filename[i] <= '9')) {
						break;
					}
				}

				if (i == 8 && filename[i] == '.' && filename[i + 1] == '0') {
					anonymous_capath = "/etc/ssl/certs";
					break;
				}
			}
		}
		return *anonymous_capath;
	}
#endif
}

namespace mediapipe::lua::solutions::download_utils {
	constexpr auto _GCS_URL_PREFIX = "https://storage.googleapis.com/mediapipe-assets/";

	absl::Status download_oss_model(
		const std::string& model_path,
		const std::string& hash,
		const bool force,
		const char verbose
	) {
		fs::path mp_root_path(mediapipe::lua::_framework_bindings::resource_util::get_resource_dir());
		auto model_abspath = fs::absolute(mp_root_path / model_path);

		auto pos_end = model_path.find_last_of('/');
		auto model_url = _GCS_URL_PREFIX + model_path.substr(pos_end == std::string::npos ? 0 : pos_end + 1);

		return download(
			model_url,
			model_abspath.string(),
			hash,
			force,
			verbose
		);
	}

	absl::Status curl(const std::vector<std::string>& _argv) {
		char *env = curl_getenv("CURL_CA_BUNDLE");
		if (env) {
			goto after_env;
		}

		env = curl_getenv("SSL_CERT_DIR");
		if (env) {
			goto after_env;
		}

		env = curl_getenv("SSL_CERT_FILE");
		if (env) {
			goto after_env;
		}

after_env:

		if (env) {
			curl_free(env);
			env = nullptr;
		} else {
#if defined(CURL_CA_BUNDLE) || !defined(_WIN32)
			const auto& cacert = get_default_cacert();
			if (!cacert.empty()) {
#if _WIN32
				SetEnvironmentVariableA("CURL_CA_BUNDLE", cacert.c_str());
#else
				setenv("CURL_CA_BUNDLE", cacert.c_str(), 0); // does not overwrite
#endif
			}
#endif

#if defined(CURL_CA_PATH) || !defined(_WIN32)
			const auto& capath = get_default_capath();
			if (!capath.empty()) {
#if _WIN32
				SetEnvironmentVariableA("SSL_CERT_DIR", capath.c_str());
#else
				setenv("SSL_CERT_DIR", capath.c_str(), 0); // does not overwrite
#endif
			}
#endif
		}

#ifdef _UNICODE
		std::vector<std::wstring> argv;
		argv.reserve(_argv.size());
		for (const auto& arg : _argv) {
			std::wstring wstr; LUA_MODULE_NAME::wide_char::utf8_to_wcs(arg, wstr);
			argv.push(std::move(wstr));
		}

		std::vector<wchar_t*> cstrings;
		cstrings.reserve(argv.size());
		for (const auto& arg : argv) {
			cstrings.push_back(const_cast<wchar_t*>(arg.c_str()));
		}

		CURLcode res = static_cast<CURLcode>(tool_wmain(cstrings.size(), cstrings.size() == 0 ? nullptr : &cstrings[0]));
#else
		const auto& argv = _argv;
		std::vector<char*> cstrings;
		cstrings.reserve(argv.size());
		for (const auto& arg : argv) {
			cstrings.push_back(const_cast<char*>(arg.c_str()));
		}

		CURLcode res = static_cast<CURLcode>(tool_main(cstrings.size(), cstrings.size() == 0 ? nullptr : &cstrings[0]));
#endif

		MP_ASSERT_RETURN_IF_ERROR(res == CURLE_OK, "curl_easy_perform() failed: " << curl_easy_strerror(res));
		return absl::OkStatus();
	}

	absl::Status download(
		const std::string& url,
		const std::string& output,
		const std::string& hash,
		const bool force,
		const char verbose,
		const std::vector<std::string>& other
	) {
		auto file_abspath = fs::absolute(fs::path(output));

		MP_ASSIGN_OR_RETURN(auto exists, check_hash(file_abspath, hash, force, false));

		if (exists) {
			if (verbose > 0) {
				LUA_MODULE_INFO("Keeping existing " << file_abspath);
			}
			return absl::OkStatus();
		}

		LUA_MODULE_INFO("Downloading " << url << " to " << file_abspath);

		std::vector<std::string> argv = {
			"--url", url,
			"--output", output,
			"-L",
			"--create-dirs",
		};

		if (verbose > 0) {
			argv.push_back("-" + std::string(verbose, 'v'));
		} else if (verbose < 0) {
			argv.push_back("--silent");
		}

		argv.insert(std::end(argv), std::begin(other), std::end(other));

		MP_RETURN_IF_ERROR(curl(argv));

		MP_ASSIGN_OR_RETURN(exists, check_hash(file_abspath, hash, force, true));

		return absl::OkStatus();
	}
}
