rockspec_format = "3.0"
package = "mediapipe_lua"
version = "scm-1"
source = {
   url = "git+https://github.com/smbape/lua-mediapipe.git"
}
description = {
   summary = "Mediapipe bindings for lua",
   detailed = [[
      Mediapipe bindings for luajit and lua 5.1/5.2/5.3/5.4.

      Linux/Windows users:
      I recommend you to try installing the prebuilt binary with
      luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 mediapipe_lua

      Or to specify the target lua version with one of the following commands
      luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 mediapipe_lua 0.10.24luajit2.1
      luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 mediapipe_lua 0.10.24lua5.4
      luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 mediapipe_lua 0.10.24lua5.3
      luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 mediapipe_lua 0.10.24lua5.2
      luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 mediapipe_lua 0.10.24lua5.1

      Those prebuilt binaries should work on windows and many linux distributions and have been tested on:
        - Windows 11
        - Ubuntu 20.04
        - Ubuntu 22.04
        - Ubuntu 24.04
        - Debian 10
        - Debian 11
        - Debian 12
        - Fedora 38
        - Fedora 39
        - Fedora 40
        - Almalinux 8
        - Almalinux 9

      If the prebuilt binary does not work or you want a custom build, then I recommend you to host your own binary rocks by following the instructions at
      https://github.com/smbape/lua-mediapipe/tree/v0.1.0#hosting-you-own-binary-rocks

      Otherwise, follow the instructions at https://github.com/smbape/lua-mediapipe/tree/v0.1.0#prerequisites-to-source-rock-install
      before attempting to install the source rock with

      luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 opencv_lua 4.11.0
      luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 mediapipe_lua 0.10.24
   ]],
   homepage = "https://github.com/smbape/lua-mediapipe",
   issues_url = "git+https://github.com/smbape/lua-mediapipe.git",
   license = "MIT",
   labels = { "mediapipe" },
}
dependencies = {
   "lua >= 5.1, < 5.5",
   "opencv_lua >= 4.11.0, < 5.0.0"
}
build = {
   type = "cmake",
   variables = {
      WITH_LUA_ROCKS = "ON",
      CMAKE_INSTALL_PREFIX = "$(PREFIX)",
      LUA_BINDIR = "$(LUA_BINDIR)",
      LUA_DIR = "$(LUA_DIR)",
      LUA_INCDIR = "$(LUA_INCDIR)",
   },
   copy_directories = {
      "docs",
   },
}
