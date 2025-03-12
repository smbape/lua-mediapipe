#include <registration.hpp>
#include <file_utils.hpp>
#include "binding/resource_util.h"

#ifndef OPENCV_LUA_API
# if (defined _WIN32 || defined WINCE || defined __CYGWIN__)
#   define OPENCV_LUA_API __declspec(dllimport)
# else
#   define OPENCV_LUA_API extern
# endif
#endif

namespace opencv_lua {
	template<typename T>
	OPENCV_LUA_API std::shared_ptr<T> exported_lua_to(lua_State* L, int index, T* ptr, bool& is_valid);

	template<typename T>
	OPENCV_LUA_API int exported_lua_push(lua_State* L, T* ptr);

	template<typename T>
	OPENCV_LUA_API int exported_lua_push(lua_State* L, T&& obj);

	template<typename T>
	OPENCV_LUA_API int exported_lua_push(lua_State* L, const T& obj);
}

namespace LUA_MODULE_NAME {
	const std::string StatusCodeToError(const ::absl::StatusCode& code) {
		switch (code) {
		case absl::StatusCode::kInvalidArgument:
			return "Invalid argument";
		case absl::StatusCode::kAlreadyExists:
			return "File already exists";
		case absl::StatusCode::kUnimplemented:
			return "Not implemented";
		default:
			return "Runtime error";
		}
	}


	// ================================
	// cv::Mat
	// ================================

	std::shared_ptr<cv::Mat> lua_to(lua_State* L, int index, cv::Mat* ptr, bool& is_valid) {
		return opencv_lua::exported_lua_to(L, index, ptr, is_valid);
	}

	int lua_push(lua_State* L, cv::Mat* ptr) {
		return opencv_lua::exported_lua_push(L, ptr);
	}

	int lua_push(lua_State* L, cv::Mat&& obj) {
		return opencv_lua::exported_lua_push(L, std::move(obj));
	}

	int lua_push(lua_State* L, const cv::Mat& obj) {
		return opencv_lua::exported_lua_push(L, obj);
	}


	// ================================
	// mediapipe::Timestamp
	// ================================

	std::shared_ptr<mediapipe::Timestamp> lua_to(lua_State* L, int index, mediapipe::Timestamp*, bool& is_valid) {
		auto ptr = usertype_info<mediapipe::Timestamp>::lua_userdata_to(L, index, is_valid);
		if (is_valid) {
			return ptr;
		}

		auto timestamp = lua_to(L, index, static_cast<int64_t*>(nullptr), is_valid);
		if (is_valid) {
			return std::make_shared<mediapipe::Timestamp>(timestamp);
		}

		return std::shared_ptr<mediapipe::Timestamp>();
	}


	// ================================
	// absl::Status
	// ================================

	int lua_push(lua_State* L, const absl::Status& status) {
		if (status.ok()) {
			return 0;
		}

		std::ostringstream oss;
		oss << StatusCodeToError(status.code()) << ": " << status.message().data();
		return luaL_error(L, "%s", oss.str().c_str());
	}

}

namespace fs = std::filesystem;

#define _stringify(s) #s
#define stringify(s) _stringify(s)

#ifdef __linux__
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <stdio.h>
#include <dlfcn.h>
#include <cstdlib>
#include <stdlib.h>

namespace {
	fs::path get_module_filename() {
		Dl_info info;
		auto res = dladdr((void const*)&LUA_MODULE_LUAOPEN, &info);
		if (res) {
			return fs::absolute(info.dli_fname);
		}
		return fs::path();
	}
}
#elif defined(_MSC_VER)
#include <Windows.h>

namespace {
	// https://github.com/opencv/opencv/blob/4.11.0/modules/core/src/utils/datafile.cpp#L165-L187
	fs::path get_module_filename() {
		void* addr = (void*)&LUA_MODULE_LUAOPEN; // using code address, doesn't work with static linkage!
		HMODULE m = nullptr;
#if _WIN32_WINNT >= 0x0501 && (!defined(WINAPI_FAMILY) || (WINAPI_FAMILY == WINAPI_FAMILY_DESKTOP_APP))
		::GetModuleHandleEx(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
			reinterpret_cast<LPCTSTR>(addr),
			&m);
#endif
		if (m) {
			wchar_t lpFilename[4096];
			constexpr size_t nSize = sizeof(lpFilename) / sizeof(*lpFilename);

			auto sz = GetModuleFileNameW(m, lpFilename, nSize);
			if (sz > 0 && sz < nSize) {
				lpFilename[sz] = '\0';
				return fs::absolute(lpFilename);
			}
		}

		// Unable to get the path
		return fs::path();
	}
}
#endif

namespace {
	using namespace LUA_MODULE_NAME;

#ifdef _MSC_VER
	template <typename char_type>
	inline bool null_or_empty(const char_type* s) {
		return s == nullptr || *s == 0;
	}

	/**
	 * Maps a UTF-16 (wide character) string to a new character string. The new character string is not necessarily from a multibyte character set.
	 *
	 * @param  codePage Code page to use in performing the conversion.
	 * @param  c_wstr   Pointer to the Unicode string to convert.
	 * @param  length   Size, in characters, of the string indicated by c_wstr parameter.
	 * @param  str      Pointer to a buffer that receives the converted string.
	 * @return          The number of bytes written to the buffer pointed to by c_str.
	 * @see             https://learn.microsoft.com/en-us/windows/win32/api/stringapiset/nf-stringapiset-widechartomultibyte
	 */
	inline int wcs_to_mbs(UINT codePage, const fs::path::value_type* c_wstr, size_t length, std::string& str) {
		if (null_or_empty(c_wstr)) {
			str.clear();
			return 0;
		}

		int size = WideCharToMultiByte(codePage, 0, c_wstr, length, nullptr, 0, nullptr, nullptr);
		str.assign(size, 0);
		return WideCharToMultiByte(codePage, 0, c_wstr, length, &str[0], size + 1, nullptr, nullptr);
	}

	inline int wcs_to_utf8(const fs::path::value_type* c_wstr, size_t length, std::string& str) {
		return wcs_to_mbs(CP_UTF8, c_wstr, length, str);
	}
#endif

	inline std::string _string_type_to_string(const fs::path::string_type& match) {
#ifdef _MSC_VER
		std::string str; wcs_to_utf8(match.c_str(), match.length(), str);
		return str;
#else
		return match;
#endif
	}

	// https://a4z.gitlab.io/blog/2023/11/04/Compiletime-string-literals-processing.html
	constexpr size_t cstr_len(const char* const str) {
		size_t len = 0;
		while (*(str + len) != '\0') {
			len++;
		}
		return len;
	}

	void require_opencv_lua(lua_State* L) {
		lua_getglobal(L, "require");
		lua_pushliteral(L, "opencv_lua");
		lua_call(L, 1, 1);  /* call 'require("opencv_lua")' */
		lua_pop(L, 1); /* remove the result because we don't need it and to keep the stack consistent */
	}

	void set_resource_dir() {
		std::vector<std::string> hints = {
#ifdef _MSC_VER
#if _DEBUG
			"out/build/x64-Debug/mediapipe/mediapipe-src/bazel-out/x64_windows-dbg/bin",
#else
			"out/build/x64-Release/mediapipe/mediapipe-src/bazel-out/x64_windows-opt/bin",
#endif
#else
#ifndef NDEBUG
			"out/build/Linux-GCC-Debug/mediapipe/mediapipe-src/bazel-out/k8-dbg/bin",
#else
			"out/build/Linux-GCC-Release/mediapipe/mediapipe-src/bazel-out/k8-opt/bin",
#endif
#endif
		};

		auto module_filename = get_module_filename();
		if (!module_filename.empty()) {
			auto base_directory = module_filename.parent_path() / stringify(LUA_MODULE_NAME);
			if (fs::exists(base_directory)) {
				hints.insert(hints.begin(), _string_type_to_string(base_directory.native()));
			}
		}

		constexpr auto graph_file = "mediapipe/modules/face_detection/face_detection_short_range_cpu.binarypb";
		const auto& directory = std::filesystem::current_path().string();
		const auto& filter = "";
		auto graph_file_found = fs_utils::findFile(graph_file, directory, filter, hints);
		if (!graph_file_found.empty()) {
			const auto& root_path = graph_file_found.substr(0, graph_file_found.size() - cstr_len(graph_file) - 1);
			mediapipe::lua::_framework_bindings::resource_util::set_resource_dir(root_path);
		}
	}
}

namespace LUA_MODULE_NAME {
	void register_extensions(lua_State* L) {
		require_opencv_lua(L);
		set_resource_dir();
	}
}
