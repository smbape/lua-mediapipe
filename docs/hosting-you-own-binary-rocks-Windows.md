# Hosting you own binary rocks on Windows

## Table Of Contents

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Prerequisites](#prerequisites)
- [Build System Environment](#build-system-environment)
- [Open GIT BASH in the **build directory**](#open-git-bash-in-the-build-directory)
- [Download the source code](#download-the-source-code)
- [Build](#build)
- [Testing our custom prebuilt binary](#testing-our-custom-prebuilt-binary)
  - [Prepare](#prepare)
  - [Initialize our test project and install our custom prebuilt binary](#initialize-our-test-project-and-install-our-custom-prebuilt-binary)
  - [Test](#test)
- [Hosting on a web server](#hosting-on-a-web-server)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

Here we will build a custom opencv with the folling modifications:
  - Add the contrib modules.
  - Add the freetype module.
  - Enable experimental support of UTF-16 (wide character) strings on Windows.
  - Add NVIDIA CUDA support.

The procedure has been tested on:
  - Windows 11.

## Prerequisites

  - Install [CMake >= 3.25](https://cmake.org/download/)
  - Install [Git](https://git-scm.com/)
  - Install [NodeJS](https://nodejs.org/en/download/current)
  - Install [Python](https://www.python.org/downloads/)
  - Install [Visual Studio 2022 >= 17.13.0](https://visualstudio.microsoft.com/fr/downloads/)
  - \[optional\] [Hosted you own opencv_lua binary rocks on Windows with NVIDIA CUDA support](https://github.com/smbape/lua-opencv/blob/main/docs/hosting-you-own-binary-rocks-Windows.md)

In your windows search, search and open the `x64 Native Tools Command Prompt for VS 2022`

From here on, commands will be executed within the opened Command Prompt.

## Build System Environment

We will name our LuaRocks pakcage **mediapipe_lua-custom** in order to avoid conflict with the original package name

In this example, we will use the following directories: 
  - The **Lua binary directory** is _D:\luarocks-binaries-custom\lua-mediapipe\out\prepublish\build\mediapipe_lua-custom\out\install\x64-Release\bin_
  - The **LuaRocks binary directory** is _D:\luarocks-binaries-custom\lua-mediapipe\out\prepublish\build\mediapipe_lua-custom\out\build.luaonly\x64-Release\luarocks\luarocks-prefix\src\luarocks_
  - The **build directory** is _D:\luarocks-binaries-custom\build_
  - The **server directory** is _D:\luarocks-binaries-custom\server_
  - The **test directory** is _D:\luarocks-binaries-custom\test_

## Open GIT BASH in the **build directory**

```cmd
"%ProgramW6432%\Git\bin\bash.exe" -l -i
```

## Download the source code

```sh
git clone --depth 1 --branch v0.1.0 https://github.com/smbape/lua-mediapipe.git /d/luarocks-binaries-custom/lua-mediapipe && \
cd /d/luarocks-binaries-custom/lua-mediapipe && \
npm ci
```

## Build

```sh
# --lua-versions luajit-2.1,5.1,5.2,5.3,5.4
TMPDIR=/d/luarocks-binaries-custom/tmp && \
node scripts/prepublish.js --pack --server="/d/luarocks-binaries-custom/server" --lua-versions luajit-2.1 --name=mediapipe_lua-custom \
    --opencv-server=/d/luarocks-binaries-custom/server \
    --opencv-name=opencv_lua-custom
```

## Testing our custom prebuilt binary

Open a new Command Prompt terminal. It doesn't have to be a Visual Studio command prompt

### Prepare

Add your **Lua binary directory** to the PATH environment variable
```cmd
set PATH=D:\luarocks-binaries-custom\lua-mediapipe\out\prepublish\build\mediapipe_lua-custom\out\install\x64-Release\bin;%PATH%
```

Add your **LuaRocks binary directory** to the PATH environment variable
```cmd
set PATH=D:\luarocks-binaries-custom\lua-mediapipe\out\prepublish\build\mediapipe_lua-custom\out\build.luaonly\x64-Release\luarocks\luarocks-prefix\src\luarocks;%PATH%
```

### Initialize our test project and install our custom prebuilt binary

```cmd
mkdir "D:\luarocks-binaries-custom\test"
cd /d "D:\luarocks-binaries-custom\test"
luarocks --lua-version "5.1" --lua-dir "D:\luarocks-binaries-custom\lua-mediapipe\out\prepublish\build\mediapipe_lua-custom\out\install\x64-Release" init --lua-versions "5.1,5.2,5.3,5.4"
luarocks install "--server=D:\luarocks-binaries-custom\server" mediapipe_lua-custom
```

Replace the content of `lua.bat` with the following content

```cmd
@echo off
setlocal
IF "%*"=="" (set I=-i) ELSE (set I=)
set "LUAROCKS_SYSCONFDIR=C:\Program Files\luarocks"
set LUA_MODULES=%~dp0lua_modules
set "PATH=%LUA_MODULES%\lib\lua\5.1;%LUA_MODULES%\bin;%APPDATA%\luarocks\bin;C:\vcpkg\installed\x64-windows\bin;%PATH%"
"D:\luarocks-binaries-custom\lua-mediapipe\out\prepublish\build\mediapipe_lua-custom\out\install\x64-Release\bin\luajit.exe" -e "package.path=\"%LUA_MODULES:\=\\%\\share\\lua\\5.1\\?.lua;%LUA_MODULES:\=\\%\\share\\lua\\5.1\\?\\init.lua;%APPDATA:\=\\%\\luarocks\\share\\lua\\5.1\\?.lua;%APPDATA:\=\\%\\luarocks\\share\\lua\\5.1\\?\\init.lua;\"..package.path;package.cpath=\"%LUA_MODULES:\=\\%\\lib\\lua\\5.1\\?.dll;%APPDATA:\=\\%\\luarocks\\lib\\lua\\5.1\\?.dll;\"..package.cpath" %I% %*
exit /b %ERRORLEVEL%
```

### Test

Create a file `test-mediapipe.lua`

```lua
local INDEX_BASE = 1 -- lua is 1-based indexed

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe

local download_utils = mediapipe.lua.solutions.download_utils

local MEDIAPIPE_SAMPLES_DATA_PATH = "testdata"

local MODEL_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/bert_classifier.tflite"
local MODEL_URL = "https://storage.googleapis.com/mediapipe-models/text_classifier/bert_classifier/float32/1/bert_classifier.tflite"
local MODEL_HASH = "sha256=9b45012ab143d88d61e10ea501d6c8763f7202b86fa987711519d89bfa2a88b1"
download_utils.download(mediapipe_lua.kwargs({
    file = MODEL_FILE,
    url = MODEL_URL,
    hash = MODEL_HASH,
}))


-- Define the input text that you wants the model to classify.
local INPUT_TEXT = "I'm looking forward to what will come next."

-- STEP 1: Import the necessary modules.
local lua = mediapipe.tasks.lua
local text = mediapipe.tasks.lua.text

-- STEP 2: Create an TextClassifier object.
local base_options = lua.BaseOptions(mediapipe_lua.kwargs({ model_asset_path = MODEL_FILE }))
local options = text.TextClassifierOptions(mediapipe_lua.kwargs({ base_options = base_options }))
local classifier = text.TextClassifier.create_from_options(options)

-- STEP 3: Classify the input text.
local classification_result = classifier:classify(INPUT_TEXT)

-- STEP 4: Process the classification result. In this case, print out the most likely category.
local top_category = classification_result.classifications[0 + INDEX_BASE].categories[0 + INDEX_BASE]
print(("%s: (%.2f)"):format(top_category.category_name, top_category.score))

```

Execute the `test-mediapipe.lua` script

```cmd
lua.bat test-mediapipe.lua
```

## Hosting on a web server

Alternatively, If you want an installation over http/s, upload the contents of **server directory** into an http/s server.

For example, if you uploaded it into http://example.com/binary-rock/, you can install the prebuilt binary with

```sh
luarocks install --server=http://example.com/binary-rock mediapipe_lua-custom
```
