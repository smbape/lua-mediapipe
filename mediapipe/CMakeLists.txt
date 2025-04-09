cmake_minimum_required(VERSION 3.25)

project(mediapipe)

set(Mediapipe_VERSION 0.10.22 CACHE STRING "Choose the mediapipe version.")
set_property(CACHE Mediapipe_VERSION PROPERTY STRINGS "0.10.22" "0.10.21" "0.10.20")
string(REPLACE "." "" Mediapipe_DLLVERSION ${Mediapipe_VERSION})

set(Mediapipe_URL_HASH_SHA256_01022 25af3c4cc44dfe929eea226ab6cd0dd53a54fbb199db877cc96aa63d0e45d745)
set(Mediapipe_URL_HASH_SHA256_01021 6492ad36697cca309fe9526c64d65c8844e8128aebc85c390a97c375008d1c34)
set(Mediapipe_URL_HASH_SHA256_01020 ae0abfc544a37a46f46e20f73010ddbe43cf12b0853701b763d3df1ab986dd36)

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
    URL             https://fossies.org/linux/misc/mediapipe-${Mediapipe_VERSION}.tar.gz
                    https://github.com/google-ai-edge/mediapipe/archive/refs/tags/v${Mediapipe_VERSION}.tar.gz
    URL_HASH        SHA256=${Mediapipe_URL_HASH_SHA256_${Mediapipe_DLLVERSION}}
    PATCH_COMMAND   "${PATCH_EXECUTABLE}" -p 1 -d "<SOURCE_DIR>" -i "${CMAKE_SOURCE_DIR}/patches/001-mediapipe-src.patch"
)

file(CREATE_LINK "${CMAKE_SOURCE_DIR}" "${mediapipe_SOURCE_DIR}/${MEDIAPIPE_ADDON_PACKAGE}" SYMBOLIC)

function(revert_old_patch_and_apply_new_patch)
    set(options)
    set(oneValueArgs
        EXECUTABLE
        OLD_PATCHFILE
        NEW_PATCHFILE
        WORKING_DIRECTORY
    )
    set(multiValueArgs)
    cmake_parse_arguments(PARSE_ARGV 0 patch
        "${options}" "${oneValueArgs}" "${multiValueArgs}"
    )

    if (patch_UNPARSED_ARGUMENTS)
        string(REPLACE ";" ", " patch_UNPARSED_ARGUMENTS "${patch_UNPARSED_ARGUMENTS}")
        message(FATAL_ERROR "Unknown arguments [${patch_UNPARSED_ARGUMENTS}]")
    endif()

    foreach(keyword IN ITEMS EXECUTABLE OLD_PATCHFILE NEW_PATCHFILE WORKING_DIRECTORY)
        if (NOT patch_${keyword})
            message(FATAL_ERROR "${keyword} argument is missing")
        endif()
    endforeach()

    foreach(arg IN LISTS options)
        if (patch_${arg})
            set(patch_${arg} ${arg})
        else()
            unset(patch_${arg})
        endif()
    endforeach()


    # check if patch_NEW_PATCHFILE has been applied
    execute_process(
        COMMAND "${patch_EXECUTABLE}" -p 1 -i "${patch_NEW_PATCHFILE}" -R --dry-run -s
        WORKING_DIRECTORY "${patch_WORKING_DIRECTORY}"
        RESULT_VARIABLE new_patchfile_applied_result
    )

    if (NOT new_patchfile_applied_result EQUAL 0)
        if (EXISTS "${patch_OLD_PATCHFILE}")
            # check if the previous patch can be reversed
            execute_process(
                COMMAND "${patch_EXECUTABLE}" -p 1 -i "${patch_OLD_PATCHFILE}" -R --dry-run -s
                WORKING_DIRECTORY "${patch_WORKING_DIRECTORY}"
                RESULT_VARIABLE old_patchfile_applied_result
            )

            if (old_patchfile_applied_result EQUAL 0)
                # reverse the previous patch
                execute_process(
                    COMMAND "${patch_EXECUTABLE}" -p 1 -i "${patch_OLD_PATCHFILE}" -R
                    WORKING_DIRECTORY "${patch_WORKING_DIRECTORY}"
                    COMMAND_ECHO STDERR
                    COMMAND_ERROR_IS_FATAL ANY
                )
            endif()
        endif()

        # check that the new patch can be applied
        execute_process(
            COMMAND "${patch_EXECUTABLE}" -p 1 -i "${patch_NEW_PATCHFILE}" --dry-run -s
            WORKING_DIRECTORY "${patch_WORKING_DIRECTORY}"
            COMMAND_ECHO STDERR
            COMMAND_ERROR_IS_FATAL ANY
        )

        # apply the new patch
        execute_process(
            COMMAND "${patch_EXECUTABLE}" -p 1 -i "${patch_NEW_PATCHFILE}"
            WORKING_DIRECTORY "${patch_WORKING_DIRECTORY}"
            COMMAND_ECHO STDERR
            COMMAND_ERROR_IS_FATAL ANY
        )
    endif()

    configure_file("${patch_NEW_PATCHFILE}" "${patch_OLD_PATCHFILE}" COPYONLY)
endfunction()

revert_old_patch_and_apply_new_patch(
    EXECUTABLE        "${PATCH_EXECUTABLE}"
    OLD_PATCHFILE     "${CMAKE_BINARY_DIR}/patches/001-mediapipe-src.patch"
    NEW_PATCHFILE     "${CMAKE_SOURCE_DIR}/patches/001-mediapipe-src.patch"
    WORKING_DIRECTORY "${mediapipe_SOURCE_DIR}"
)

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

get_target_property(curl_SOURCE_FILES curl SOURCES)
list(FILTER curl_SOURCE_FILES INCLUDE REGEX "\\.c(c|pp|xx)?$")
list(TRANSFORM curl_SOURCE_FILES PREPEND "${curl_SOURCE_DIR}/src/")
list(TRANSFORM curl_SOURCE_FILES REPLACE "/src/../" "/")

file(GLOB curl_tool_SOURCE_FILES
    "${curl_SOURCE_DIR}/lib/*.h"
    "${curl_SOURCE_DIR}/lib/*.hh"
    "${curl_SOURCE_DIR}/lib/*.hpp"
    "${curl_SOURCE_DIR}/lib/*.hxx"
    "${curl_SOURCE_DIR}/src/*.h"
    "${curl_SOURCE_DIR}/src/*.hh"
    "${curl_SOURCE_DIR}/src/*.hpp"
    "${curl_SOURCE_DIR}/src/*.hxx"
)

list(APPEND curl_tool_SOURCE_FILES ${curl_SOURCE_FILES})
list(TRANSFORM curl_tool_SOURCE_FILES REPLACE "${curl_SOURCE_DIR}/" "")

set(curl_tool_SOURCE_DIR "${mediapipe_BINARY_DIR}/curl_tool/curl_tool")
file(REMOVE_RECURSE "${curl_tool_SOURCE_DIR}")

execute_process(
    COMMAND "${NODE_EXECUTABLE}" --unhandled-rejections=strict --trace-uncaught --trace-warnings scripts/copy_relocate_includes.js "${curl_SOURCE_DIR}" "${curl_tool_SOURCE_DIR}" ${curl_tool_SOURCE_FILES}
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    COMMAND_ECHO STDERR
    COMMAND_ERROR_IS_FATAL ANY
)

set(curl_tool_BINARY_FILES lib/curl_config.h)
list(APPEND curl_tool_SOURCE_FILES ${curl_tool_BINARY_FILES})

execute_process(
    COMMAND "${NODE_EXECUTABLE}" --unhandled-rejections=strict --trace-uncaught --trace-warnings scripts/copy_relocate_includes.js "${curl_BINARY_DIR}" "${curl_tool_SOURCE_DIR}" ${curl_tool_BINARY_FILES}
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    COMMAND_ECHO STDERR
    COMMAND_ERROR_IS_FATAL ANY
)

list(TRANSFORM curl_tool_SOURCE_FILES PREPEND "${curl_tool_SOURCE_DIR}/")

add_library(libcurl_tool SHARED EXCLUDE_FROM_ALL ${curl_tool_SOURCE_FILES})
target_include_directories(libcurl_tool PUBLIC "${mediapipe_BINARY_DIR}/curl_tool")
target_include_directories(libcurl_tool PRIVATE "${curl_tool_SOURCE_DIR}/lib" "${curl_tool_SOURCE_DIR}/src")
target_compile_definitions(libcurl_tool PRIVATE HAVE_CONFIG_H)
target_link_libraries(libcurl_tool PUBLIC libcurl)

generate_bazel_library(
    OUTPUT_VARIABLE bazel_libcurl_tool
    TARGET          libcurl_tool
    NAME            libcurl
    PKGNAME         libcurl_tool
    NAME_OVERRIDES    "ZLIB,zlib_bundled"
    PKGNAME_OVERRIDES "zlib_bundled,ZLIB,zlib"
)
list(APPEND bazel_repositories "${bazel_libcurl_tool}")
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
