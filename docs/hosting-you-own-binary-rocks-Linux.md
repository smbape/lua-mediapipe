# Hosting you own binary rocks on Linux

## Table Of Contents

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Prerequisites](#prerequisites)
  - [[Ubuntu, Debian] Install needed packages:](#ubuntu-debian-install-needed-packages)
  - [[Fedora] Install needed packages:](#fedora-install-needed-packages)
  - [[Almalinux 8] Install needed packages:](#almalinux-8-install-needed-packages)
  - [[Almalinux 9] Install needed packages:](#almalinux-9-install-needed-packages)
- [Build System Environment](#build-system-environment)
- [Download the source code](#download-the-source-code)
- [Build](#build)
- [Testing our custom prebuilt binary](#testing-our-custom-prebuilt-binary)
  - [Prepare](#prepare)
  - [Initialize our test project and install our custom prebuilt binary](#initialize-our-test-project-and-install-our-custom-prebuilt-binary)
  - [Test CUDA](#test-cuda)
- [Hosting on a web server](#hosting-on-a-web-server)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

Here we will build a custom mediapipe with the folling modifications:
  - Add NVIDIA CUDA support.

The procedure has been tested on :
  - [Ubuntu 22.04 (Jammy Jellyfish)](https://releases.ubuntu.com/jammy/)

## Prerequisites

  - Install [CUDA Toolkit](https://developer.nvidia.com/cuda-downloads?target_os=Windows&target_arch=x86_64&target_version=11&target_type=exe_network)
  - Download [cuDNN](https://developer.nvidia.com/cudnn-downloads?target_os=Windows&target_arch=x86_64&target_version=10&target_type=exe_local) compatible with the **CUDA Toolkit** version you installed, and extract the contents of the `bin`, `include` and `lib` directories inside the `bin`, `include` and `lib` directories of the **CUDA Toolkit** directory.
  - Download [NVIDIA Video Codec SDK 12.2.72](https://developer.nvidia.com/designworks/video-codec-sdk/secure/12.2/video_codec_sdk_12.2.72.zip) and extract the contents of the `Interface` and `Lib` directories inside the `include` and `lib` directories of the **CUDA Toolkit** directory.
  - Install [CMake >= 3.25](https://cmake.org/download/)
  - Install [LuaRocks](https://github.com/luarocks/luarocks/wiki/Installation-instructions-for-Unix)
  - Install [Ninja](https://ninja-build.org/)
  - Install [NodeJS](https://nodejs.org/en/download/current)
  - \[optional\] [Hosted you own opencv_lua binary rocks on Linux with NVIDIA CUDA support](https://github.com/smbape/lua-opencv/blob/main/docs/hosting-you-own-binary-rocks-Linux.md)

### [Ubuntu, Debian] Install needed packages:
```sh
sudo apt install -y build-essential curl git libavcodec-dev libavformat-dev libdc1394-dev \
        libjpeg-dev libpng-dev libreadline-dev libswscale-dev libtbb-dev \
        ninja-build patchelf pkg-config python3-pip python3-venv qtbase5-dev unzip wget zip
```

### [Fedora] Install needed packages:
```sh
sudo dnf install -y curl gcc gcc-c++ git \
        libjpeg-devel libpng-devel readline-devel make patch tbb-devel \
        libavcodec-free-devel libavformat-free-devel libdc1394-devel libswscale-free-devel \
        patchelf pkg-config python3-pip qt5-qtbase-devel unzip wget zip
```

### [Almalinux 8] Install needed packages:
```sh
sudo dnf install -y curl gcc-toolset-12-gcc gcc-toolset-12-gcc-c++ git \
        libjpeg-devel libpng-devel readline-devel make patch tbb-devel \
        patchelf pkg-config python3.12-pip qt5-qtbase-devel unzip wget zip && \
sudo config-manager --set-enabled powertools && \
sudo dnf install -y epel-release && \
sudo dnf install -y https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-8.noarch.rpm
sudo dnf install -y https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-8.noarch.rpm && \
sudo dnf update -y && \
sudo dnf install -y ffmpeg-devel && \
source /opt/rh/gcc-toolset-12/enable
```

### [Almalinux 9] Install needed packages:
```sh
sudo dnf install -y curl gcc gcc-c++ git \
        libjpeg-devel libpng-devel readline-devel make patch tbb-devel \
        patchelf pkg-config python3-pip qt5-qtbase-devel unzip wget zip && \
sudo config-manager --set-enabled crb && \
sudo dnf install -y epel-release && \
sudo dnf install -y https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-9.noarch.rpm
sudo dnf install -y https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-9.noarch.rpm && \
sudo dnf update -y && \
sudo dnf install -y libavcodec-free-devel libavformat-free-devel libdc1394-devel libswscale-free-devel
```

## Build System Environment

We will name our LuaRocks pakcage **mediapipe_lua-custom** in order to avoid conflict with the original package name

In this example, we will use the following directories: 
  - The **Lua binary directory** is _/io/luarocks-binaries-custom/lua-mediapipe/out/prepublish/build/mediapipe_lua-custom//out/install/Linux-GCC-Release/bin_
  - The **LuaRocks binary directory** is _/io/luarocks-binaries-custom/lua-mediapipe/out/prepublish/build/mediapipe_lua-custom/out/build.luaonly/Linux-GCC-Release/luarocks/luarocks-prefix/src/luarocks-build/bin_
  - The **build directory** is _/io/luarocks-binaries-custom/build_
  - The **server directory** is _/io/luarocks-binaries-custom/server_
  - The **test directory** is _/io/luarocks-binaries-custom/test_

## Download the source code

```sh
git clone --depth 1 --branch v0.1.0 https://github.com/smbape/lua-mediapipe.git /io/luarocks-binaries-custom/build && \
cd /io/luarocks-binaries-custom/build && \
npm ci
```

## Build

```sh
# --lua-versions luajit-2.1,5.1,5.2,5.3,5.4
node scripts/prepublish.js --pack --server=/io/luarocks-binaries-custom/server --lua-versions luajit-2.1 --name=mediapipe_lua-custom \
    --repair --plat linux_x86_64 --exclude "libc.so.*;libgcc_s.so.*;libstdc++.so.*;libm.so.*;libxcb.so.*;libQt*;libcu*;libnp*;libGL*;libEGL*;opencv_lua.so" \
    --opencv-server=/io/luarocks-binaries-custom/server \
    --opencv-name=opencv_lua-custom \
    -DWITH_CUDA=ON \
    -DWITH_CUDNN=ON \
    -DOPENCV_DNN_CUDA=ON \
    -DCUDA_ARCH_BIN=$(nvidia-smi --query-gpu=compute_cap --format=csv | sed /compute_cap/d)
```

## Testing our custom prebuilt binary

Open a new terminal.

### Prepare

Add your **Lua binary directory** to the PATH environment variable
```sh
export PATH="/io/luarocks-binaries-custom/lua-mediapipe/out/prepublish/build/mediapipe_lua-custom/out/install/Linux-GCC-Release/bin:$PATH"
```

Add your **LuaRocks binary directory** to the PATH environment variable
```sh
export PATH="/io/luarocks-binaries-custom/lua-mediapipe/out/prepublish/build/mediapipe_lua-custom/out/build.luaonly/Linux-GCC-Release/luarocks/luarocks-prefix/src/luarocks-build/bin:$PATH"
```

### Initialize our test project and install our custom prebuilt binary

```sh
mkdir /io/luarocks-binaries-custom/test && \
cd /io/luarocks-binaries-custom/test && \
luarocks --lua-version 5.1 --lua-dir "$(dirname "$(dirname "$(command -v luajit)")")" init --lua-versions "5.1,5.2,5.3,5.4" && \
luarocks install --server=/io/luarocks-binaries-custom/server opencv_lua-custom && \
luarocks install --server=/io/luarocks-binaries-custom/server mediapipe_lua-custom
```

### Test CUDA

```sh
./luarocks install --deps-only /io/luarocks-binaries-custom/lua-mediapipe/samples/samples-scm-1.rockspec && \
./lua /io/luarocks-binaries-custom/lua-mediapipe/samples/dnn/object_detection/object_detection.lua ssd_tf --input Megamind.avi --backend 5 --target 6
```

## Hosting on a web server

Alternatively, If you want an installation over http/s, upload the contents of **server directory** into an http/s server.

For example, if you uploaded it into http://example.com/binary-rock/, you can install the prebuilt binary with

```sh
luarocks install --server=http://example.com/binary-rock mediapipe_lua-custom
```
