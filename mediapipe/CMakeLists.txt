cmake_minimum_required(VERSION 3.25)

project(mediapipe)


set(Mediapipe_VERSION 0.10.14 CACHE STRING "Choose the mediapipe version.")
set_property(CACHE Mediapipe_VERSION PROPERTY STRINGS "0.10.14")
string(REPLACE "." "" Mediapipe_DLLVERSION ${Mediapipe_VERSION})

set(Mediapipe_URL_HASH_SHA256_01014 9d46fa5363f5c4e11c3d1faec71b0746f15c5aab7b5460d0e5655d7af93c6957)

string(REPLACE "." ";" Mediapipe_VERSION_LIST ${Mediapipe_VERSION})
list(GET Mediapipe_VERSION_LIST 0 Mediapipe_VERSION_MAJOR)
list(GET Mediapipe_VERSION_LIST 1 Mediapipe_VERSION_MINOR)
list(GET Mediapipe_VERSION_LIST 2 Mediapipe_VERSION_PATCH)

cmake_path(RELATIVE_PATH CMAKE_CURRENT_BINARY_DIR BASE_DIRECTORY "${CMAKE_SOURCE_DIR}" OUTPUT_VARIABLE CMAKE_CURRENT_RELATIVE_BINARY_DIR)
string(REGEX REPLACE "/$" "" CMAKE_CURRENT_RELATIVE_BINARY_DIR "${CMAKE_CURRENT_RELATIVE_BINARY_DIR}")

if (LUAJIT_VERSION_STRING)
  string(REPLACE "." ";" LUAJIT_VERSION_STRING_PARTS "${LUAJIT_VERSION_STRING}")
  list(GET LUAJIT_VERSION_STRING_PARTS 0 LUAJIT_VERSION_MAJOR)
  list(GET LUAJIT_VERSION_STRING_PARTS 1 LUAJIT_VERSION_MINOR)
  set(MEDIAPIPE_ADDON_PACKAGE "mediapipe/luajit-${LUAJIT_VERSION_MAJOR}.${LUAJIT_VERSION_MINOR}")
elseif(LUA_VERSION_STRING)
  string(REPLACE "." ";" LUA_VERSION_STRING_PARTS "${LUA_VERSION_STRING}")
  list(GET LUA_VERSION_STRING_PARTS 0 LUA_VERSION_MAJOR)
  list(GET LUA_VERSION_STRING_PARTS 1 LUA_VERSION_MINOR)
  set(MEDIAPIPE_ADDON_PACKAGE "mediapipe/lua-${LUA_VERSION_MAJOR}.${LUA_VERSION_MINOR}")
else()
  message(FATAL_ERROR "LUAJIT_VERSION_STRING or LUA_VERSION_STRING mmust be defined")
endif()

set(MEDIAPIPE_ADDON_REPOSITORIES ":${CMAKE_CURRENT_RELATIVE_BINARY_DIR}/third_party/repositories.bzl")
set(MEDIAPIPE_ADDON_RULES_DEPENDENCIES "lua_rules_dependencies")

configure_file("${CMAKE_SOURCE_DIR}/patches/001-mediapipe-src.patch.in" "${CMAKE_SOURCE_DIR}/patches/001-mediapipe-src.patch" @ONLY)

# Tell cmake that we will need mediapipe.
include(FetchContent)
FetchContent_Populate(mediapipe
  URL               https://fossies.org/linux/misc/mediapipe-${Mediapipe_VERSION}.tar.gz
                    https://github.com/google-ai-edge/mediapipe/archive/refs/tags/v${Mediapipe_VERSION}.tar.gz
  URL_HASH          SHA256=${Mediapipe_URL_HASH_SHA256_${Mediapipe_DLLVERSION}}
  PATCH_COMMAND     "${PATCH_EXECUTABLE}" -p 1 -d "<SOURCE_DIR>" -i "${CMAKE_SOURCE_DIR}/patches/001-mediapipe-src.patch"
)

file(CREATE_LINK "${CMAKE_SOURCE_DIR}" "${mediapipe_SOURCE_DIR}/${MEDIAPIPE_ADDON_PACKAGE}" SYMBOLIC)

if (EXISTS "${CMAKE_BINARY_DIR}/patches/001-mediapipe-src.patch")
  execute_process( COMMAND ${CMAKE_COMMAND} -E compare_files "${CMAKE_SOURCE_DIR}/patches/001-mediapipe-src.patch" "${CMAKE_BINARY_DIR}/patches/001-mediapipe-src.patch"
    RESULT_VARIABLE compare_result
  )
  if (NOT compare_result EQUAL 0)
    execute_process(
      COMMAND "${PATCH_EXECUTABLE}" -p 1 -i "${CMAKE_BINARY_DIR}/patches/001-mediapipe-src.patch" -R
      WORKING_DIRECTORY "${mediapipe_SOURCE_DIR}"
      COMMAND_ECHO STDERR
      COMMAND_ERROR_IS_FATAL ANY
    )
    execute_process(
      COMMAND "${PATCH_EXECUTABLE}" -p 1 -i "${CMAKE_SOURCE_DIR}/patches/001-mediapipe-src.patch"
      WORKING_DIRECTORY "${mediapipe_SOURCE_DIR}"
      COMMAND_ECHO STDERR
      COMMAND_ERROR_IS_FATAL ANY
    )
  endif()
endif()

configure_file("${CMAKE_SOURCE_DIR}/patches/001-mediapipe-src.patch.in" "${CMAKE_BINARY_DIR}/patches/001-mediapipe-src.patch" @ONLY)

include(../cmake/bazel_tools.cmake)

# Add lua to bazel repositories
set(Lua_INCLUDE_DIR "${LUA_INCLUDE_DIR}")
list_cmake_convert(TO_CMAKE_PATH Lua_INCLUDE_DIR)
set(Lua_LIBRARIES "${LUA_LIBRARIES}")
get_bazel_library(
  OUTPUT_VARIABLE bazel_lua
  NAME            lua
  PKGNAME         lua
  INCLUDES        ${Lua_INCLUDE_DIR}
  SOURCES         ${Lua_LIBRARIES}
)
list(APPEND bazel_repositories "${bazel_lua}")

# Add opencv to bazel repositories
if (WIN32)
  set(OpenCV_PLATFORM "windows_opencv")
else()
  set(OpenCV_PLATFORM "linux_opencv")
endif()
generate_bazel_library(
  OUTPUT_VARIABLE bazel_opencv
  TARGET          ${OpenCV_LIBS}
  NAME            ${OpenCV_PLATFORM}
  PKGNAME         opencv
)
list(APPEND bazel_repositories "${bazel_opencv}")

# Add libcurl to bazel repositories
generate_bazel_library(
  OUTPUT_VARIABLE    bazel_libcurl
  TARGET             libcurl
  NAME               curl
  PKGNAME            libcurl
  ALWAYSLINK
  NAME_OVERRIDES    "ZLIB,zlib_bundled"
  PKGNAME_OVERRIDES "zlib_bundled,ZLIB,zlib"
)
list(APPEND bazel_repositories "${bazel_libcurl}")

# specific files needed to perform sha256sum
# without explicetly include an ssl library
# ============================================
function(create_link file src dst)
  set(src "${src}/${file}")
  set(dst "${dst}/${file}")
  cmake_path(GET dst PARENT_PATH dst_parent)
  file(MAKE_DIRECTORY "${dst_parent}")
  file(CREATE_LINK "${src}" "${dst}" SYMBOLIC)
endfunction()

set(curl_sha256_include "${mediapipe_BINARY_DIR}/curl_sha256/include")
file(REMOVE_RECURSE "${curl_sha256_include}")

foreach(file IN ITEMS
  "lib/curl_hmac.h"
  "lib/curl_sha256.h"
)
  create_link("${file}" "${curl_SOURCE_DIR}" "${curl_sha256_include}/curl_sha256")
endforeach()

add_library(libcurl_sha256 INTERFACE EXCLUDE_FROM_ALL)
target_include_directories(libcurl_sha256 INTERFACE "${curl_sha256_include}")

generate_bazel_library(
  OUTPUT_VARIABLE bazel_libcurl_sha256
  TARGET          libcurl_sha256
  NAME            curl
  PKGNAME         libcurl_sha256
)
list(APPEND bazel_repositories "${bazel_libcurl_sha256}")
# ============================================

string(REPLACE ";" ", " bazel_repositories "${bazel_repositories}")

configure_file("${CMAKE_SOURCE_DIR}/scripts/configure_bazel.js.in" "${CMAKE_SOURCE_DIR}/scripts/configure_bazel.js" @ONLY)

execute_process(
  COMMAND "${NODE_EXECUTABLE}" --unhandled-rejections=strict --trace-uncaught --trace-warnings scripts/configure_bazel.js
  WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
  COMMAND_ECHO STDERR
  COMMAND_ERROR_IS_FATAL ANY
)

if("${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
  set(COMPILATION_MODE dbg)
else()
  set(COMPILATION_MODE opt)
endif()

if (WIN32)
  set(mediapipe_BINARY_DIR "${mediapipe_SOURCE_DIR}/bazel-out/x64_windows-${COMPILATION_MODE}/bin")
else()
  set(mediapipe_BINARY_DIR "${mediapipe_SOURCE_DIR}/bazel-out/k8-${COMPILATION_MODE}/bin")
endif()

set(COMPILATION_MODE "${COMPILATION_MODE}" PARENT_SCOPE)
set(MEDIAPIPE_ADDON_PACKAGE "${MEDIAPIPE_ADDON_PACKAGE}" PARENT_SCOPE)
set(MEDIAPIPE_ADDON_REPOSITORIES "${MEDIAPIPE_ADDON_REPOSITORIES}" PARENT_SCOPE)
set(MEDIAPIPE_ADDON_RULES_DEPENDENCIES "${MEDIAPIPE_ADDON_RULES_DEPENDENCIES}" PARENT_SCOPE)
set(mediapipe_BINARY_DIR "${mediapipe_BINARY_DIR}" PARENT_SCOPE)
set(mediapipe_SOURCE_DIR "${mediapipe_SOURCE_DIR}" PARENT_SCOPE)
