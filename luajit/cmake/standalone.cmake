#
# Configuration for standalone build
#
set(LUAJIT_CONFIG_SCRIPT "")
cmake_script_append_var(LUAJIT_CONFIG_SCRIPT
    luajit_SRC
    LUA_INCLUDE_DIR
    LUA_INCLUDE_DIRS

    DISABLE_FFI
    ENABLE_LUA52COMPAT
    DISABLE_JIT
    ENABLE_GC64
    DISABLE_GC64
    USE_SYSMALLOC
    USE_VALGRIND
    USE_GDBJIT

    USE_APICHECK
    USE_ASSERT

    NUMMODE

    TARGET_ARCH
    HOST_XCFLAGS
)
set(CMAKE_HELPER_SCRIPT "${luajit_BINARY_DIR}/LuaJITConfig.cmake")
file(WRITE "${CMAKE_HELPER_SCRIPT}" "${LUAJIT_CONFIG_SCRIPT}")
