cmake_minimum_required(VERSION 3.25)

project(mediapipe LANGUAGES C CXX ASM)

set(DEFAULT_BUILD_TYPE "Release")

if((NOT DEFINED CMAKE_BUILD_TYPE) OR ("${CMAKE_BUILD_TYPE} " STREQUAL " "))
    message(STATUS "Setting build type to '${DEFAULT_BUILD_TYPE}' as none was specified.")
    set(CMAKE_BUILD_TYPE "${DEFAULT_BUILD_TYPE}" CACHE STRING "Choose the type of build." FORCE)
endif()

# Set the possible values of build type for cmake-gui
set(CMAKE_CONFIGURATION_TYPES "Debug;Release;MinSizeRel;RelWithDebInfo" CACHE STRING "Configs" FORCE)
set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "${CMAKE_CONFIGURATION_TYPES}")

set(BUILD_SHARED_LIBS ON CACHE BOOL "Build shared libraries (.dll/.so) instead of static ones (.lib/.a)")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(MSVC AND NOT (CMAKE_GENERATOR STREQUAL "Ninja"))
    add_compile_options(/MP)
endif()

if(POLICY CMP0091)
    cmake_policy(SET CMP0091 NEW) # CMake 3.15+: leave MSVC runtime selection out of default CMAKE_<LANG>_FLAGS_<CONFIG> flags
endif()

include(cmake/list_commands.cmake)

# ===============
# Lua
# ===============
include(cmake/FindLua.cmake)

# ===============
# Luarocks
# ===============
add_subdirectory(luarocks)

set(LUA_ONLY "$ENV{LUA_ONLY}")
if (LUA_ONLY)
    message(STATUS "Processing Lua related targets only")
    unset(LUA_INCLUDE_DIR CACHE)
    unset(LUA_INTERPRETER CACHE)
    unset(LUA_LIBRARY CACHE)
    return()
endif()

# ===============
# Python
# ===============
include(cmake/UsePython3Venv.cmake)
if (UNIX)
    pip_install(build auditwheel)
endif()

# Needed python packages
pip_install(absl-py mediapipe numpy opencv-python)

# ===============
# Node
# ===============
find_program(NODE_EXECUTABLE NAMES node REQUIRED)

if (WIN32)
    find_program(NPM_EXECUTABLE NAMES npm.cmd REQUIRED)
else()
    find_program(NPM_EXECUTABLE NAMES npm REQUIRED)
endif()

if(NOT EXISTS "${CMAKE_SOURCE_DIR}/node_modules")
    execute_process(
        COMMAND "${NPM_EXECUTABLE}" ci
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        COMMAND_ECHO STDERR
        COMMAND_ERROR_IS_FATAL ANY
    )
endif()

# ===============
# OpenCV Lua
# ===============
if (WITH_LUA_ROCKS)
    # Compute the installation prefix relative CMAKE_INSTALL_PREFIX.
    string(REGEX REPLACE "/luarocks/rocks-([^/]+)/.+$" "/lua/\\1" LUA_MODULES_LIB "${CMAKE_INSTALL_PREFIX}")
    if (EXISTS "${LUA_MODULES_LIB}/opencv_lua/devel")
        list(APPEND CMAKE_PREFIX_PATH "${LUA_MODULES_LIB}/opencv_lua/devel")
    endif()
    unset(OpenCVLua_DIR CACHE)
endif()

find_package(OpenCVLua REQUIRED)
set(OpenCV_LIBS opencv_lua::opencv_lua)
set(OpenCV_VERSION "${OpenCVLua_VERSION}")
string(REPLACE "." "" OpenCV_DLLVERSION ${OpenCV_VERSION})

# ===============
# CURL
# ===============
include(cmake/FindCURL.cmake)

# ===============
# Mediapipe
# ===============
add_subdirectory(mediapipe)

# ===============
# OpenCV hdr parser
# ===============
add_subdirectory(opencv_hdr_parser)

# ===============
# Mediapipe Lua
# ===============
add_subdirectory(mediapipe_lua "mediapipe_lua${LUA_MULTI_CONFIG_SUFFIX}")
