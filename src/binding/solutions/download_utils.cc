#include "binding/solutions/download_utils.h"
#include "binding/resource_util.h"
#include "binding/util.h"

#include <filesystem>
#include <fstream>
#include <iostream>
#include <cstdio>

// #define HAVE_CONFIG_H
// #define CURL_HIDDEN_SYMBOLS

#include <curl/curl.h>

// curl_sha256 is not supposed to be publicly available
// however, this is a hacky way to perform sha256 without relying on openssl
#include <curl/mprintf.h>

// #include <curl_sha256/lib/curl_setup.h>

#ifdef __cplusplus
extern "C" {
#endif
#include <curl_sha256/lib/curl_sha256.h>
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

		CURLcode result = hashparams.hinit(ctxt.get());
		MP_ASSERT_RETURN_IF_ERROR(result == CURLE_OK, "Failed to get hash of file " << file_abspath);

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
		} else {
			MP_ASSERT_RETURN_IF_ERROR(false, "Unsupported hash " << hash);
		}

		const auto is_valid = actual_hash == expected_hash;

		if (validate) {
			MP_ASSERT_RETURN_IF_ERROR(is_valid, "Expected hash " << hash << " but got " << actual_hash);
		}

		return is_valid;
	}

	struct CurlGuard {
		CURL* curl_handle;

		CurlGuard() {
			/* init the curl session */
			curl_global_init(CURL_GLOBAL_ALL);
			curl_handle = curl_easy_init();
		}

		~CurlGuard() {
			/* cleanup curl stuff */
			curl_easy_cleanup(curl_handle);
			curl_global_cleanup();
			curl_handle = nullptr;
		}
	};

	struct FileOpenGuard {
		std::FILE* file;

		FileOpenGuard(const char* filename, const char* mode) {
			/* open the file */
			file = fopen(filename, mode);
		}

		~FileOpenGuard() {
			/* close the file */
			std::fclose(file);
			file = nullptr;
		}
	};

	size_t write_data(void* ptr, size_t size, size_t nmemb, void* stream) {
		return fwrite(ptr, size, nmemb, (std::FILE*)stream);
	}

	absl::Status _download(const std::string& url, const fs::path& file_abspath, const bool verbose) {
		auto sFileNameL = file_abspath.string();

		CurlGuard curl;
		CURL* curl_handle = curl.curl_handle;

		if (verbose) {
			curl_easy_setopt(curl_handle, CURLOPT_VERBOSE, 1L);
		}

		/* set URL to get here */
		curl_easy_setopt(curl_handle, CURLOPT_URL, url.c_str());

		/* disable progress meter, set to 0L to enable it */
		curl_easy_setopt(curl_handle, CURLOPT_NOPROGRESS, 1L);

		/* send all data to this function  */
		curl_easy_setopt(curl_handle, CURLOPT_WRITEFUNCTION, write_data);

		/* follow redirections */
		curl_easy_setopt(curl_handle, CURLOPT_FOLLOWLOCATION, 1L);

		/* open the file */
		FileOpenGuard file_guard(sFileNameL.c_str(), "wb");
		MP_ASSERT_RETURN_IF_ERROR(static_cast<bool>(file_guard.file), "unable to open file " << sFileNameL);

		/* write the page body to this file handle */
		curl_easy_setopt(curl_handle, CURLOPT_WRITEDATA, file_guard.file);

		/* get it! */
		CURLcode res = curl_easy_perform(curl_handle);
		MP_ASSERT_RETURN_IF_ERROR(res == CURLE_OK, "curl_easy_perform() failed: " << curl_easy_strerror(res));

		return absl::OkStatus();
	}
}

namespace mediapipe::lua::solutions::download_utils {
	constexpr auto _GCS_URL_PREFIX = "https://storage.googleapis.com/mediapipe-assets/";

	absl::Status download_oss_model(const std::string& model_path, const std::string& hash, const bool force, const bool verbose) {
		fs::path mp_root_path(mediapipe::lua::_framework_bindings::resource_util::get_resource_dir());
		auto model_abspath = fs::absolute(mp_root_path / model_path);

		auto pos_end = model_path.find_last_of('/');
		auto model_url = _GCS_URL_PREFIX + model_path.substr(pos_end == std::string::npos ? 0 : pos_end + 1);

		return download(model_url, model_abspath.string(), hash, force, verbose);
	}

	absl::Status download(const std::string& url, const std::string& file, const std::string& hash, const bool force, const bool verbose) {
		auto file_abspath = fs::absolute(fs::path(file));

		MP_ASSIGN_OR_RETURN(auto exists, check_hash(file_abspath, hash, force, false));

		if (exists) {
			if (verbose) {
				LUA_MODULE_INFO("Keeping existing " << file_abspath);
			}
			return absl::OkStatus();
		}

		LUA_MODULE_INFO("Downloading " << url << " to " << file_abspath);

		// create directory tree
		fs::create_directories(file_abspath.parent_path());

		MP_RETURN_IF_ERROR(_download(url, file_abspath, verbose));
		MP_ASSIGN_OR_RETURN(exists, check_hash(file_abspath, hash, force, true));
		MP_ASSERT_RETURN_IF_ERROR(exists, "Downloading " << url << " to " << file_abspath << " failed");

		return absl::OkStatus();
	}
}
