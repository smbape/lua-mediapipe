# Hosting you own binary rocks on Linux

## Table Of Contents

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Prerequisites](#prerequisites)
  - [[Debian, Ubuntu] Install needed packages:](#debian-ubuntu-install-needed-packages)
  - [[Fedora] Install needed packages:](#fedora-install-needed-packages)
  - [[Almalinux 8] Install needed packages:](#almalinux-8-install-needed-packages)
  - [[Almalinux 9, 10] Install needed packages:](#almalinux-9-10-install-needed-packages)
- [Build System Environment](#build-system-environment)
- [Download the source code](#download-the-source-code)
- [Build](#build)
- [Testing our custom prebuilt binary](#testing-our-custom-prebuilt-binary)
  - [Prepare](#prepare)
  - [Initialize our test project and install our custom prebuilt binary](#initialize-our-test-project-and-install-our-custom-prebuilt-binary)
  - [Test GPU](#test-gpu)
- [Hosting on a web server](#hosting-on-a-web-server)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

Here we will build a custom mediapipe with the folling modifications:
  - Add GPU support.
  - Add NVIDIA CUDA support.

The procedure has been tested on :
  - [Ubuntu 24.04 (Jammy Jellyfish)](https://releases.ubuntu.com/jammy/)

> [!WARNING]  
> GPU usage on Linux desktop is experimental:
>   [Reducing Latency for Hand-Tracking Solution in Python](https://github.com/google-ai-edge/mediapipe/issues/5789)
>   [How to make sure gesture recognition is running successfully on the gpu？](https://github.com/google-ai-edge/mediapipe/issues/4988)

## Prerequisites

  - Install [CUDA Toolkit](https://developer.nvidia.com/cuda-downloads?target_os=Linux)
  - Download [cuDNN](https://developer.nvidia.com/cudnn-downloads?target_os=Linux) compatible with the **CUDA Toolkit** version you installed, and extract the contents of the `bin`, `include` and `lib` directories inside the `bin`, `include` and `lib` directories of the **CUDA Toolkit** directory.
  - Download [NVIDIA Video Codec SDK 12.2.72](https://developer.nvidia.com/designworks/video-codec-sdk/secure/12.2/video_codec_sdk_12.2.72.zip) and extract the contents of the `Interface` and `Lib` directories inside the `include` and `lib` directories of the **CUDA Toolkit** directory.
  - Install [CMake >= 3.25](https://cmake.org/download/)
  - Install [LuaRocks](https://github.com/luarocks/luarocks/wiki/Installation-instructions-for-Unix)
  - Install [Ninja](https://ninja-build.org/)
  - Install [NodeJS](https://nodejs.org/en/download/current)
  - Install [Python 3.9...<3.13](https://www.python.org/downloads/)
  - Install [Bazelisk](https://github.com/bazelbuild/bazelisk)
  - Install [gcc >= 14](https://gcc.gnu.org/) or [Clang >= 18](https://clang.llvm.org/)
  - \[optional\] [Hosted you own opencv_lua binary rocks on Linux with NVIDIA CUDA support](https://github.com/smbape/lua-opencv/blob/main/docs/hosting-you-own-binary-rocks-Linux.md)

### [Debian, Ubuntu] Install needed packages:
```sh
sudo apt install -y build-essential curl git libavcodec-dev libavformat-dev libdc1394-dev \
    liblapacke-dev libjpeg-dev libopenblas-dev libpng-dev libreadline-dev libswscale-dev libtbb-dev \
    patchelf pkg-config python3-pip python3-venv qtbase5-dev unzip wget zip
sudo apt install -y libtbbmalloc2 || apt install -y libtbb2
```

### [Fedora] Install needed packages:
```sh
sudo dnf install -y curl dejavu-sans-fonts gcc gcc-c++ git \
    lapack-devel libjpeg-devel libpng-devel make openblas-devel patch patchelf pkg-config \
    python3-pip qt5-qtbase-devel readline-devel tbb-devel unzip wget zip \
    libavcodec-free-devel libavformat-free-devel libdc1394-devel libswscale-free-devel
```

### [Almalinux 8] Install needed packages:
```sh
sudo dnf install -y curl dejavu-sans-fonts git \
    libjpeg-devel libpng-devel make patch pkg-config \
    qt5-qtbase-devel readline-devel tbb-devel unzip wget zip \
    openssl-devel && \
sudo config-manager --set-enabled powertools && \
sudo dnf install -y almalinux-release-devel epel-release && \
sudo dnf install -y https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-8.noarch.rpm
sudo dnf install -y https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-8.noarch.rpm && \
sudo dnf update -y && \
sudo dnf install -y ffmpeg-devel gcc-toolset-12-gcc gcc-toolset-12-gcc-c++ lapack-devel libdc1394-devel openblas-devel patchelf python3.12-pip && \
source /opt/rh/gcc-toolset-12/enable
```

### [Almalinux 9, 10] Install needed packages:
```sh
sudo dnf install -y curl dejavu-sans-fonts gcc gcc-c++ git \
    libjpeg-devel libpng-devel make patch pkg-config \
    python3-pip qt5-qtbase-devel readline-devel tbb-devel unzip wget zip \
    openssl-devel && \
sudo config-manager --set-enabled crb && \
sudo dnf install -y almalinux-release-devel epel-release && \
sudo dnf install -y https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-9.noarch.rpm
sudo dnf install -y https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-9.noarch.rpm && \
sudo dnf update -y && \
sudo dnf install -y lapack-devel libavcodec-free-devel libavformat-free-devel libdc1394-devel libswscale-free-devel openblas-devel patchelf
```

## Build System Environment

We will name our LuaRocks pakcage **mediapipe_lua-custom** in order to avoid conflict with the original package name

In this example, we will use the following directories: 
  - The **Lua binary directory** is _/io/luarocks-binaries-custom/lua-mediapipe/out/prepublish/build/mediapipe_lua-custom//out/install/Linux-GCC-Release/bin_
  - The **LuaRocks binary directory** is _/io/luarocks-binaries-custom/lua-mediapipe/out/prepublish/build/mediapipe_lua-custom/out/build.luaonly/Linux-GCC-Release/luarocks/luarocks-prefix/src/luarocks-build/bin_
  - The **build directory** is _/io/luarocks-binaries-custom/build_
  - The **server directory** is _/io/luarocks-binaries-custom/server_
  - The **test directory** is _/io/luarocks-binaries-custom/test/lua-mediapipe_

## Download the source code

```sh
git clone --depth 1 --branch v0.1.1 https://github.com/smbape/lua-mediapipe.git /io/luarocks-binaries-custom/build && \
cd /io/luarocks-binaries-custom/build && \
npm ci
```

## Build

```sh
# --lua-versions luajit-2.1,5.1,5.2,5.3,5.4,5.5
node scripts/prepublish.js --pack --server=/io/luarocks-binaries-custom/server --lua-versions luajit-2.1 --name=mediapipe_lua-custom \
    -DENABLE_REPAIR=ON \
    -DAUDITWHEEL_exclude="opencv_lua.so;libGL*;libEGL*;libxcb.so.*;libxcb-*.so.*;libQt*;libcublas.so.*;libcuda.so.*;libcudnn.so.*;libcufft.so.*;libnpp*;libnvcuvid.so.*;libnvidia-encode.so.*;libOpenCL.so.*;libopenblas.so.*" \
    --opencv-server=/io/luarocks-binaries-custom/server \
    --opencv-name=opencv_lua-custom \
    -DMEDIAPIPE_DISABLE_GPU=OFF \
    -DWITH_CUDA=ON \
    -DWITH_CUDNN=ON \
    -DOPENCV_DNN_CUDA=ON \
    -DCUDA_ARCH_BIN=$(nvidia-smi --query-gpu=compute_cap --format=csv | sed /compute_cap/d)
```

  - `-DAUDITWHEEL_exclude="opencv_lua.so;libGL\*;libEGL\*;libxcb.so.\*;libxcb-\*.so.\*;libQt\*;libcublas.so.\*;libcuda.so.\*;libcudnn.so.\*;libcufft.so.\*;libnpp\*;libnvcuvid.so.\*;libnvidia-encode.so.\*;libOpenCL.so.\*;libopenblas.so.\*"`: exclude shared libraries, that if vendored, may conflict (opencv_lua.so;libGL\*;libEGL\*;libxcb.so.\*;libxcb-\*.so.\*) with the system shared libraries or heavily increase (+850 Mo) the size of the binary rock (libQt\*;libcublas.so.\*;libcuda.so.\*;libcudnn.so.\*;libcufft.so.\*;libnpp\*;libnvcuvid.so.\*;libnvidia-encode.so.\*;libOpenCL.so.\*;libopenblas.so.\*).

  See [pypa/auditwheel](https://pypi.org/project/auditwheel/) for more information

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
mkdir -p /io/luarocks-binaries-custom/test/lua-mediapipe && \
cd /io/luarocks-binaries-custom/test/lua-mediapipe && \
luarocks --lua-version 5.1 init --lua-versions "5.1,5.2,5.3,5.4,5.5" && \
luarocks install --server=/io/luarocks-binaries-custom/server opencv_lua-custom && \
luarocks install --server=/io/luarocks-binaries-custom/server mediapipe_lua-custom
```

### Test GPU

Create a file `test-mediapipe.lua`

```lua
--[[
Sources:
    https://colab.research.google.com/github/google-ai-edge/mediapipe-samples/blob/3d23f0e459907af064c3e7494dbb180851e1694c/examples/pose_landmarker/python/%5BMediaPipe_Python_Tasks%5D_Pose_Landmarker.ipynb
    https://github.com/google-ai-edge/mediapipe-samples/blob/3d23f0e459907af064c3e7494dbb180851e1694c/examples/pose_landmarker/python/%5BMediaPipe_Python_Tasks%5D_Pose_Landmarker.ipynb

Title: Pose Landmarks Detection with MediaPipe Tasks
--]]

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe

local opencv_lua = require("opencv_lua")
local cv2 = opencv_lua.cv

local function resize_and_show(image, title, show)
    if title == nil then title = "" end
    if show == nil then show = true end

    local DESIRED_HEIGHT = 480
    local DESIRED_WIDTH = 480
    local w = image.width
    local h = image.height

    if h < w then
        h = math.floor(h / (w / DESIRED_WIDTH))
        w = DESIRED_WIDTH
    else
        w = math.floor(w / (h / DESIRED_HEIGHT))
        h = DESIRED_HEIGHT
    end

    local interpolation = (function()
        if DESIRED_WIDTH > image.width or DESIRED_HEIGHT > image.height then
            return cv2.INTER_CUBIC
        end
        return cv2.INTER_AREA
    end)()

    if show then
        local img = cv2.resize(image, { w, h }, opencv_lua.kwargs(({ interpolation = interpolation })))
        cv2.imshow(title, img)
    end

    return w / image.width
end

local download_utils = mediapipe.tasks.lua.core.download_utils

local function download_test_files(test_files)
    for _, kwargs in ipairs(test_files) do
        download_utils.download(mediapipe_lua.kwargs(kwargs))
    end
end

local MEDIAPIPE_SAMPLES_DATA_PATH = "testdata"

local IMAGE_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/girl-4051811_960_720.jpg"
local IMAGE_URL = "https://cdn.pixabay.com/photo/2019/03/12/20/39/girl-4051811_960_720.jpg"
local IMAGE_HASH = "sha256=99e0649aa4f2553b0213982f544146565a1028877c4bb9fbe3884453659d8cdc"
local MODEL_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/pose_landmarker_heavy.task"
local MODEL_URL =
"https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_heavy/float16/1/pose_landmarker_heavy.task"
local MODEL_HASH = "sha256=64437af838a65d18e5ba7a0d39b465540069bc8aae8308de3e318aad31fcbc7b"

download_test_files({
    {
        output = IMAGE_FILE,
        url = IMAGE_URL,
        hash = IMAGE_HASH,
    },
    {
        output = MODEL_FILE,
        url = MODEL_URL,
        hash = MODEL_HASH,
    },
})

local drawing_utils = mediapipe.tasks.lua.vision.drawing_utils
local drawing_styles = mediapipe.tasks.lua.vision.drawing_styles
local vision = mediapipe.tasks.lua.vision

local function draw_landmarks_on_image(rgb_image, detection_result)
    local scale = 1 / resize_and_show(rgb_image, nil, false)
    local pose_landmarks_list = detection_result.pose_landmarks
    local annotated_image = cv2.cvtColor(rgb_image, cv2.COLOR_RGB2BGR)

    local pose_landmark_style = drawing_styles.get_default_pose_landmarks_style(scale)
    local pose_connection_style = drawing_utils.DrawingSpec(mediapipe_lua.kwargs({ color = { 0, 255, 0 }, thickness = 2 }))

    for _, pose_landmarks in ipairs(pose_landmarks_list) do
        drawing_utils.draw_landmarks(mediapipe_lua.kwargs({
            image = annotated_image,
            landmark_list = pose_landmarks,
            connections = vision.PoseLandmarksConnections.POSE_LANDMARKS,
            landmark_drawing_spec = pose_landmark_style,
            connection_drawing_spec = pose_connection_style
        }))
    end

    return annotated_image
end

-- STEP 1: Import the necessary modules.
local mp = mediapipe
local lua = mediapipe.tasks.lua
local vision = mediapipe.tasks.lua.vision

-- STEP 2: Create an PoseLandmarker object.
local base_options = lua.BaseOptions(mediapipe_lua.kwargs({ model_asset_path = MODEL_FILE, delegate = lua.BaseOptions.Delegate.GPU }))
local options = vision.PoseLandmarkerOptions(mediapipe_lua.kwargs({
    base_options = base_options,
    output_segmentation_masks = true
}))
local detector = vision.PoseLandmarker.create_from_options(options)

-- STEP 3: Load the input image.
local image = mp.Image.create_from_file(IMAGE_FILE)

-- STEP 4: Detect pose landmarks from the input image.
local detection_result = detector:detect(image)

-- STEP 5: Process the detection result. In this case, visualize it.
local annotated_image = draw_landmarks_on_image(image:mat_view(), detection_result)

-- Display the image
resize_and_show(annotated_image, "Pose Landmarks Detection with MediaPipe Tasks : Image")

-- Visualize the pose segmentation mask.
local segmentation_mask = detection_result.segmentation_masks[0]:mat_view()
local visualized_mask = segmentation_mask:convertTo(cv2.CV_8U, opencv_lua.kwargs({ alpha = 255 }))
resize_and_show(visualized_mask, "Pose Landmarks Detection with MediaPipe Tasks : Mask")

cv2.waitKey()
```

Execute the `test-mediapipe.lua` script

```cmd
./lua test-mediapipe.lua
```

## Hosting on a web server

Alternatively, If you want an installation over http/s, upload the contents of **server directory** into an http/s server.

For example, if you uploaded it into http://example.com/binary-rock/, you can install the prebuilt binary with

```sh
luarocks install --server=http://example.com/binary-rock mediapipe_lua-custom
```
