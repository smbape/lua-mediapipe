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
#include <curl_tool/lib/curl_sha256.h>
#include <curl_tool/lib/curl_setup.h>
#include <curl_tool/lib/dynbuf.h>
#include <curl_tool/src/tool_libinfo.h>
#ifdef __cplusplus
}
#endif

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

#ifdef CURL_CA_BUNDLE
	std::string anonymous_cacert;
	bool cacert_set = false;
	const std::string& get_default_cacert() {
		if (!cacert_set) {
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
			cacert_set = true;
		}
		return anonymous_cacert;
	}
#endif

#ifdef CURL_CA_PATH
	constexpr auto DEFAULT_CURL_CA_PATH = "/etc/ssl/certs";
	std::string anonymous_capath;
	bool capath_set = false;
	const std::string& get_default_capath() {
		if (!capath_set) {
			auto status = fs::symlink_status(DEFAULT_CURL_CA_PATH);
			if (fs::is_directory(status)) {
				for (auto const& dir_entry : fs::directory_iterator{ DEFAULT_CURL_CA_PATH }) {
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
						anonymous_capath = DEFAULT_CURL_CA_PATH;
						break;
					}
				}
			}
			capath_set = true;
		}
		return anonymous_capath;
	}
#endif

	class CurlGuard {
	public:
		CurlGuard() {
			/* init the curl session */
			curl_global_init(CURL_GLOBAL_ALL);
			curl = curl_easy_init();
		}

		~CurlGuard() {
			cleanup();
		}

		CURL* get() {
			curl_easy_reset(curl);
			return curl;
		}

		void cleanup() {
			/* cleanup curl stuff */
			if (curl) {
				curl_easy_cleanup(curl);
				curl_global_cleanup();
				curl = nullptr;
			}
		}

	private:
		CURL* curl;
	};

	class FileOpenGuard {
	public:
		FileOpenGuard(const char* filename, const char* mode) {
			/* open the file */
			file = fopen(filename, mode);
		}

		~FileOpenGuard() {
			close();
		}

		std::FILE* get() {
			return file;
		}

		void close() {
			/* close the file */
			if (file) {
				std::fclose(file);
				file = nullptr;
			}
		}

	private:
		std::FILE* file;
	};

	size_t write_data(void* ptr, size_t size, size_t nmemb, void* stream) {
		return fwrite(ptr, size, nmemb, (std::FILE*)stream);
	}

	/* return current SSL backend name, chop off multissl */
	char* ssl_backend() {
		static char ssl_ver[80] = "no ssl";
		static bool already = FALSE;
		if (!already) { /* if there is no existing version */
			const char* v = curl_version_info(CURLVERSION_NOW)->ssl_version;
			if (v) {
				curl_msnprintf(ssl_ver, sizeof(ssl_ver), "%.*s", (int)strcspn(v, " "), v);
			}
			already = TRUE;
		}
		return ssl_ver;
	}

	struct CurlList {
		struct curl_slist* slist;

		CurlList(const std::vector<std::string>& svector) {
			struct curl_slist* temp = nullptr;
			for (const auto& v : svector) {
				temp = curl_slist_append(slist, v.c_str());
				if (!temp) {
					this->~CurlList();
					return;
				}
				slist = temp;
			}
		}

		~CurlList() {
			if (slist) {
				curl_slist_free_all(slist);
				slist = nullptr;
			}
		}
	};

	struct CurlxDynBuf {
		struct dynbuf buffer;

		CurlxDynBuf(int size) {
			Curl_dyn_init(&buffer, size);
		}

		~CurlxDynBuf() {
			Curl_dyn_free(&buffer);
		}
	};

	constexpr auto MAX_COOKIE_LINE = 8200;
}

namespace mediapipe::lua::solutions::download_utils {
	constexpr auto _GCS_URL_PREFIX = "https://storage.googleapis.com/mediapipe-assets/";

	absl::Status download_oss_model(const std::string& model_path, const std::string& hash, const bool force, const bool verbose) {
		fs::path mp_root_path(mediapipe::lua::_framework_bindings::resource_util::get_resource_dir());
		auto model_abspath = fs::absolute(mp_root_path / model_path);

		auto pos_end = model_path.find_last_of('/');
		auto model_url = _GCS_URL_PREFIX + model_path.substr(pos_end == std::string::npos ? 0 : pos_end + 1);

		return download({
			.url = model_url,
			.file = model_abspath.string(),
			.hash = hash,
			.force = force,
			.verbose = verbose,
			});
	}

	absl::Status download(const DownloadParams& params) {
		auto file_abspath = fs::absolute(fs::path(params.file));

		MP_ASSIGN_OR_RETURN(auto exists, check_hash(file_abspath, params.hash, params.force, false));

		if (exists) {
			if (params.verbose) {
				LUA_MODULE_INFO("Keeping existing " << file_abspath);
			}
			return absl::OkStatus();
		}

		LUA_MODULE_INFO("Downloading " << params.url << " to " << file_abspath);

		// create directory tree
		fs::create_directories(file_abspath.parent_path());

		auto sFileNameL = file_abspath.string();

		long authtype = 0;
		std::string key_passwd;

		CurlGuard curl_guard;
		CURL* curl = curl_guard.get();

		if (params.verbose) {
			curl_easy_setopt(curl, CURLOPT_VERBOSE, 1L);
		}

		/* set URL to get here */
		curl_easy_setopt(curl, CURLOPT_URL, params.url.c_str());

		/* Connect via abstract Unix domain socket */
		if (params.abstract_unix_socket) {
			// MP_ASSERT_RETURN_IF_ERROR(!params.unix_socket, "abstract_unix_socket is mutually exclusive with unix_socket");
			MP_ASSERT_RETURN_IF_ERROR(!params.abstract_unix_socket->empty(), "abstract_unix_socket cannot be empty");
			curl_easy_setopt(curl, CURLOPT_ABSTRACT_UNIX_SOCKET, params.abstract_unix_socket->c_str());
		}

		/* Enable alt-svc with this cache file */
		if (!params.altsvc.empty()) {
			MP_ASSERT_RETURN_IF_ERROR(feature_altsvc, "the installed libcurl version does not support alt-svc");
			curl_easy_setopt(curl, CURLOPT_ALTSVC, params.altsvc.c_str());
		}

		/* Pick any authentication method */
		if (params.anyauth) {
			authtype = CURLAUTH_ANY;
		}

		/* AWS V4 signature auth */
		if (params.aws_sigv4) {
			authtype |= CURLAUTH_AWS_SIGV4;
			MP_ASSERT_RETURN_IF_ERROR(!params.aws_sigv4->empty(), "aws_sigv4 cannot be empty");
			curl_easy_setopt(curl, CURLOPT_AWS_SIGV4, params.aws_sigv4->c_str());
		}

		/* HTTP Basic Authentication */
		if (params.basic) {
			MP_ASSERT_RETURN_IF_ERROR(feature_ssl, "the installed libcurl version does not support basic authentication");
			authtype |= CURLAUTH_BASIC;
		}
		else {
			authtype &= ~CURLAUTH_BASIC;
		}

		// {
		// 	long mask =
		// 		(params.ssl_allow_beast ?
		// 			CURLSSLOPT_ALLOW_BEAST : 0) |
		// 		(params.ssl_allow_earlydata ?
		// 			CURLSSLOPT_EARLYDATA : 0) |
		// 		(params.ssl_no_revoke ?
		// 			CURLSSLOPT_NO_REVOKE : 0) |
		// 		(params.ssl_revoke_best_effort ?
		// 			CURLSSLOPT_REVOKE_BEST_EFFORT : 0) |
		// 		(params.ca_native ?
		// 			CURLSSLOPT_NATIVE_CA : 0) |
		// 		(params.ssl_auto_client_cert ?
		// 			CURLSSLOPT_AUTO_CLIENT_CERT : 0);

		// 	if (mask) {
		// 		curl_easy_setopt(curl, CURLOPT_SSL_OPTIONS, mask);
		// 	}
		// }

		/* CA certificate to verify peer against */
		if (params.cacert) {
			MP_ASSERT_RETURN_IF_ERROR(!params.cacert->empty(), "cacert cannot be empty");
			curl_easy_setopt(curl, CURLOPT_CAINFO, params.cacert->c_str());
		}
#ifdef CURL_CA_BUNDLE
		else {
			const auto& cacert = get_default_cacert();
			if (!cacert.empty()) {
				curl_easy_setopt(curl, CURLOPT_CAINFO, cacert.c_str());
			}
		}
#endif

		/* CA directory to verify peer against */
		if (params.capath) {
			MP_ASSERT_RETURN_IF_ERROR(!params.capath->empty(), "capath cannot be empty");
			CURLcode res = curl_easy_setopt(curl, CURLOPT_CAPATH, params.capath->c_str());
			MP_ASSERT_RETURN_IF_ERROR(res == CURLE_OK, "set capath failed: " << curl_easy_strerror(res));
		}
#ifdef CURL_CA_PATH
		else {
			const auto& capath = get_default_capath();
			if (!capath.empty()) {
				curl_easy_setopt(curl, CURLOPT_CAPATH, capath.c_str());
			}
		}
#endif

		if (feature_ssl) {
			/* Client certificate file and password */
			if (params.cert) {
				MP_ASSERT_RETURN_IF_ERROR(!params.cert->empty(), "cert cannot be empty");
				curl_easy_setopt(curl, CURLOPT_SSLCERT, params.cert->c_str());
			}

			/* Certificate type (DER/PEM/ENG/PROV/P12) */
			if (params.cert_type) {
				MP_ASSERT_RETURN_IF_ERROR(!params.cert_type->empty(), "cert_type cannot be empty");
				curl_easy_setopt(curl, CURLOPT_SSLCERTTYPE, params.cert_type->c_str());
			}
		}

		/* Verify server cert status OCSP-staple */
		if (params.cert_status) {
			curl_easy_setopt(curl, CURLOPT_SSL_VERIFYSTATUS, 1L);
		}

		/* TLS 1.2 (1.1, 1.0) ciphers to use */
		if (params.cipher_list) {
			CURLcode res = curl_easy_setopt(curl, CURLOPT_SSL_CIPHER_LIST, params.cipher_list->c_str());
			if (res == CURLE_NOT_BUILT_IN) {
				LUA_MODULE_WARN("ignoring --ciphers, not supported by libcurl with " << ssl_backend());
			}
		}

		/* Request compressed response */
		if (params.compressed) {
			MP_ASSERT_RETURN_IF_ERROR(feature_libz || feature_brotli || feature_zstd, "the installed libcurl version does not support compressed");
			curl_easy_setopt(curl, CURLOPT_ACCEPT_ENCODING, "");
		}

		/* Maximum time allowed to connect */
		if (params.connect_timeout) {
			curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT_MS, (*params.connect_timeout) * 1000);
		}

		/* Connect to host2 instead of host1 */
		if (!params.connect_to.empty()) {
			CurlList connect_to(params.connect_to);
			curl_easy_setopt(curl, CURLOPT_CONNECT_TO, connect_to.slist);
		}

		// Send cookies from string/load from file
		if (!params.cookies.empty()) {
			CurlxDynBuf cookies(MAX_COOKIE_LINE);

			/* The maximum size needs to match MAX_NAME in cookie.h */
			Curl_dyn_init(&cookies.buffer, MAX_COOKIE_LINE);

			for (const auto& cookie : params.cookies) {
				if (strchr(cookie.c_str(), '=')) {
					CURLcode res = Curl_dyn_addf(&cookies.buffer, "%s;", cookie.c_str());
					MP_ASSERT_RETURN_IF_ERROR(res == CURLE_OK,
						"skipped provided cookie, the cookie header "
						"would go over " << MAX_COOKIE_LINE << " bytes");
				}
				else {
					curl_easy_setopt(curl, CURLOPT_COOKIEFILE, cookie.c_str());
				}
			}

			curl_easy_setopt(curl, CURLOPT_COOKIE, Curl_dyn_ptr(&cookies.buffer));
		}

		/* Save cookies to <filename> after operation */
		if (params.cookie_jar) {
			MP_ASSERT_RETURN_IF_ERROR(!params.cookie_jar->empty(), "cookie_jar cannot be empty");
			curl_easy_setopt(curl, CURLOPT_COOKIEJAR, params.cookie_jar->c_str());
		}

		/* Certificate Revocation list */
		if (params.crlfile) {
			MP_ASSERT_RETURN_IF_ERROR(!params.crlfile->empty(), "crlfile cannot be empty");
			curl_easy_setopt(curl, CURLOPT_CRLFILE, params.crlfile->c_str());
		}

		/* (EC) TLS key exchange algorithms to request */
		if (params.curves) {
			MP_ASSERT_RETURN_IF_ERROR(!params.curves->empty(), "curves cannot be empty");
			curl_easy_setopt(curl, CURLOPT_SSL_EC_CURVES, params.curves->c_str());
		}

		/* HTTP POST data */
		if (params.data) {
			curl_easy_setopt(curl, CURLOPT_POSTFIELDS, params.data->c_str());
			curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE_LARGE, params.data->size());
		}

		/* HTTP Digest Authentication */
		if (params.digest) {
			if (*params.digest) {
				authtype |= CURLAUTH_DIGEST;
			}
			else {
				authtype &= ~CURLAUTH_DIGEST;
			}
		}

		/* Disallow username in URL */
		if (params.disallow_username_in_url) {
			curl_easy_setopt(curl, CURLOPT_DISALLOW_USERNAME_IN_URL, 1L);
		}

		/* follow redirections */
		curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);

		/* disable progress meter, set to 0L to enable it */
		curl_easy_setopt(curl, CURLOPT_NOPROGRESS, 1L);

		if (authtype != 0) {
			curl_easy_setopt(curl, CURLOPT_HTTPAUTH, authtype);
		}

		/* send all data to this function  */
		curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_data);

		/* open the file */
		FileOpenGuard file_guard(sFileNameL.c_str(), "wb");
		MP_ASSERT_RETURN_IF_ERROR(static_cast<bool>(file_guard.get()), "unable to open file " << sFileNameL);

		/* write the page body to this file handle */
		curl_easy_setopt(curl, CURLOPT_WRITEDATA, file_guard.get());

		/* get it! */
		CURLcode res = curl_easy_perform(curl);
		MP_ASSERT_RETURN_IF_ERROR(res == CURLE_OK, "curl_easy_perform() failed: " << curl_easy_strerror(res));
		file_guard.close();

		MP_ASSIGN_OR_RETURN(exists, check_hash(file_abspath, params.hash, params.force, true));
		MP_ASSERT_RETURN_IF_ERROR(exists, "Downloading " << params.url << " to " << file_abspath << " failed");

		return absl::OkStatus();
	}


	absl::Status download(
		const std::string& url,
		const std::string& file,
		const std::string& hash,
		const bool force,
		const std::optional<std::string> abstract_unix_socket,
		const std::string& altsvc,
		const bool anyauth,
		const std::optional<std::string> aws_sigv4,
		const bool basic,
		const bool ca_native,
		const std::optional<std::string> cacert,
		const std::optional<std::string> capath,
		const std::optional<std::string> cert,
		const bool cert_status,
		const std::optional<std::string> cert_type,
		const std::optional<std::string> cipher_list,
		const bool compressed,
		const std::optional<long> connect_timeout,
		const std::vector<std::string>& connect_to,
		const std::vector<std::string>& cookies,
		const std::optional<std::string> cookie_jar,
		const std::optional<std::string> crlfile,
		const std::optional<std::string> curves,
		const std::optional<std::string> data,
		const std::optional<bool> digest,
		const bool disallow_username_in_url,
		const bool verbose
	) {
		return download({
			.url = url,
			.file = file,
			.hash = hash,
			.force = force,
			.abstract_unix_socket = abstract_unix_socket,
			.altsvc = altsvc,
			.anyauth = anyauth,
			.aws_sigv4 = aws_sigv4,
			.basic = basic,
			.ca_native = ca_native,
			.cacert = cacert,
			.capath = capath,
			.cert = cert,
			.cert_status = cert_status,
			.cert_type = cert_type,
			.cipher_list = cipher_list,
			.compressed = compressed,
			.connect_timeout = connect_timeout,
			.connect_to = connect_to,
			.cookies = cookies,
			.cookie_jar = cookie_jar,
			.crlfile = crlfile,
			.curves = curves,
			.data = data,
			.digest = digest,
			.disallow_username_in_url = disallow_username_in_url,
			.verbose = verbose
		});
	}
}
