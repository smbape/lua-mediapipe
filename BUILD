licenses(["notice"])  # Apache 2.0

package(default_visibility = ["//visibility:public"])

load("@rules_cc//cc:defs.bzl", "cc_library")
load(":rules_impl/library.bzl", "add_library")

config_setting(
    name = "opt_build",
    values = {"compilation_mode": "opt"},
)

config_setting(
    name = "windows-opt-dbg",
    values = {
        "compilation_mode": "opt",
        "strip": "never",
    },
    constraint_values = [
        "@platforms//os:windows",
        "@platforms//cpu:x86_64",
    ],
)

config_setting(
    name = "dbg_build",
    values = {"compilation_mode": "dbg"},
)

config_setting(
    name = "enable_odml_converter",
    define_values = {"ENABLE_ODML_CONVERTER": "1"},
    visibility = ["//visibility:public"],
)


MEDIAIPIPE_VERSION = ""
OUTPUT_NAME = "mediapipe_lua"


add_library(OUTPUT_NAME + "_lib",
    pchhdrs = ["generated/lua_generated_pch.hpp"],
    includes = ["src/include/", "src/", "generated/"],
    local_defines = [
        "CVAPI_EXPORTS",
        "LUAAPI_EXPORTS",
        "LUA_MODULE_NAME=$(LUA_MODULE_NAME)",
        "LUA_MODULE_VERSION=$(LUA_MODULE_VERSION)",
        "LUA_MODULE_LIB_NAME=$(LUA_MODULE_LIB_NAME)",
        "LUA_MODULE_LIB_VERSION=$(LUA_MODULE_LIB_VERSION)",

        # LINK : warning LNK4217: symbol 'curl_global_init' defined in 'libcurl.lo.lib(easy.obj)' is imported by 'download_utils.obj' in function '"public: __cdecl `"'
        "BUILDING_LIBCURL",

        # libcurl embeded configuration is in curl_config.h
        "HAVE_CONFIG_H",
    ],
    deps = ["@lua//:lua", "@libcurl//:libcurl_tool"],
)

alias(
    name = "lib_pch",
    actual = "_pch_" + OUTPUT_NAME + "_lib",
)


cc_binary(
    name = OUTPUT_NAME,
    deps = [ ":" + OUTPUT_NAME + "_lib" ],
    linkshared = True,
)

alias(
    name = "lib",
    actual = OUTPUT_NAME,
)
