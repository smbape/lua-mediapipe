# Mediapipe bindings for lua

Mediapipe bindings for luajit and lua 5.1/5.2/5.3/5.4.

The aim is to make it as easy to use as [mediapipe-python](https://pypi.org/project/mediapipe/).

Therefore the [Mediapipe documentation](https://github.com/google-ai-edge/mediapipe) should be the reference.

## Table Of Contents

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Installation](#installation)
  - [Prerequisites to source rock install](#prerequisites-to-source-rock-install)
    - [Windows](#windows)
    - [Linux](#linux)
      - [Debian, Ubuntu](#debian-ubuntu)
      - [Fedora](#fedora)
      - [Almalinux 8](#almalinux-8)
      - [Almalinux 9](#almalinux-9)
  - [How to install](#how-to-install)
- [Examples](#examples)
  - [Face Detection with MediaPipe Tasks](#face-detection-with-mediapipe-tasks)
  - [Face Landmarks Detection with MediaPipe Tasks](#face-landmarks-detection-with-mediapipe-tasks)
  - [Face Stylizer](#face-stylizer)
  - [Gesture Recognizer with MediaPipe Tasks](#gesture-recognizer-with-mediapipe-tasks)
  - [Hand Landmarks Detection with MediaPipe Tasks](#hand-landmarks-detection-with-mediapipe-tasks)
  - [Image Classifier with MediaPipe Tasks](#image-classifier-with-mediapipe-tasks)
  - [Image Embedding with MediaPipe Tasks](#image-embedding-with-mediapipe-tasks)
  - [Image Segmenter](#image-segmenter)
  - [Interactive Image Segmenter](#interactive-image-segmenter)
  - [Language Detector with MediaPipe Tasks](#language-detector-with-mediapipe-tasks)
  - [Object Detection with MediaPipe Tasks](#object-detection-with-mediapipe-tasks)
  - [Pose Landmarks Detection with MediaPipe Tasks](#pose-landmarks-detection-with-mediapipe-tasks)
  - [Text Classifier with MediaPipe Tasks](#text-classifier-with-mediapipe-tasks)
  - [Text Embedding with MediaPipe Tasks](#text-embedding-with-mediapipe-tasks)
- [Running examples](#running-examples)
  - [Prerequisites to run examples](#prerequisites-to-run-examples)
    - [Windows](#windows-1)
    - [Linux](#linux-1)
  - [Initialize the project](#initialize-the-project)
    - [Windows](#windows-2)
    - [Linux](#linux-2)
- [Hosting you own binary rocks](#hosting-you-own-binary-rocks)
- [Keyword arguments](#keyword-arguments)
- [How to translate python code](#how-to-translate-python-code)
  - [Python translation example](#python-translation-example)
- [Lua Gotchas](#lua-gotchas)
  - [1-indexed](#1-indexed)
  - [Instance method calls](#instance-method-calls)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Installation

Prebuilt binaries are available for [LuaJIT 2.1](https://luajit.org/) and [Lua 5.1/5.2/5.3/5.4](https://www.lua.org/versions.html), and only on Windows and Linux.

### Prerequisites to source rock install

#### Windows

  - Install [Git](https://git-scm.com/)
  - Install [LuaRocks](https://github.com/luarocks/luarocks/wiki/Installation-instructions-for-Windows)
  - Install [NodeJS](https://nodejs.org/en/download/current)
  - Install [Python](https://www.python.org/downloads/)
  - Install [Visual Studio 2022 >= 17.13.0 with .NET Desktop and C++ Desktop](https://visualstudio.microsoft.com/fr/downloads/)
  - In your windows search, search and open the `x64 Native Tools Command Prompt for VS 2022`

#### Linux

  - Install [CMake >= 3.25](https://cmake.org/download/)
  - Install [LuaRocks](https://github.com/luarocks/luarocks/wiki/Installation-instructions-for-Unix)
  - Install [Ninja](https://ninja-build.org/)
  - Install [NodeJS](https://nodejs.org/en/download/current)
  - Install needed packages (see below for you corresponding distribution).
  - Tell luarocks to use [Ninja](https://ninja-build.org/) as cmake generator `luarocks config --scope project cmake_generator Ninja`

##### Debian, Ubuntu

```sh
sudo apt install -y build-essential curl git libavcodec-dev libavformat-dev libdc1394-dev \
        libjpeg-dev libpng-dev libreadline-dev libswscale-dev libtbb-dev libssl-dev \
        patchelf pkg-config python3-pip python3-venv qtbase5-dev unzip wget zip
sudo apt install -y libtbbmalloc2 || apt install -y libtbb2
```

##### Fedora

```sh
sudo dnf install -y curl gcc gcc-c++ git \
        libjpeg-devel libpng-devel readline-devel make patch tbb-devel openssl-devel \
        libavcodec-free-devel libavformat-free-devel libdc1394-devel libswscale-free-devel \
        patchelf pkg-config python3-pip qt5-qtbase-devel unzip wget zip
```

##### Almalinux 8

```sh
sudo dnf install -y curl gcc-toolset-12-gcc gcc-toolset-12-gcc-c++ git \
        libjpeg-devel libpng-devel readline-devel make patch tbb-devel openssl-devel \
        pkg-config python3.12-pip qt5-qtbase-devel unzip wget zip && \
sudo config-manager --set-enabled powertools && \
sudo dnf install -y epel-release && \
sudo dnf install -y https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-8.noarch.rpm
sudo dnf install -y https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-8.noarch.rpm && \
sudo dnf update -y && \
sudo dnf install -y ffmpeg-devel patchelf && \
source /opt/rh/gcc-toolset-12/enable
```

##### Almalinux 9

```sh
sudo dnf install -y curl gcc gcc-c++ git \
        libjpeg-devel libpng-devel readline-devel make patch tbb-devel openssl-devel \
        pkg-config python3-pip qt5-qtbase-devel unzip wget zip && \
sudo config-manager --set-enabled crb && \
sudo dnf install -y epel-release && \
sudo dnf install -y https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-9.noarch.rpm
sudo dnf install -y https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-9.noarch.rpm && \
sudo dnf update -y && \
sudo dnf install -y libavcodec-free-devel libavformat-free-devel libdc1394-devel libswscale-free-devel patchelf
```

### How to install

I recommend you to try installing the prebuilt binary, if you are not using luajit, with

```sh
luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 mediapipe_lua
```

Or to specify the target lua version with one of the following commands

```sh
luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 mediapipe_lua 0.10.24luajit2.1
luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 mediapipe_lua 0.10.24lua5.4
luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 mediapipe_lua 0.10.24lua5.3
luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 mediapipe_lua 0.10.24lua5.2
luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 mediapipe_lua 0.10.24lua5.1
```

Those prebuilt binaries should work on Windows and many linux distributions and have been tested on:
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

If none of the above works for you, then install the source rock with

```sh
luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 opencv_lua 4.11.0
luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 mediapipe_lua 0.10.24
```

## Examples

On Windows, the lua_modules modules should be added to the PATH environment variable, as shown with `luarocks path`

```cmd
set "PATH=%LUA_MODULES%\bin;%APPDATA%\luarocks\bin;%PATH%"
```

`LUA_MODULES` is a variable pointing to your lua_modules folder.

For example, in your lua project, initialized with `luarocks init`, modify the file `lua.bat` and after the line with `set "LUAROCKS_SYSCONFDIR=`, add

```cmd
set LUA_MODULES=%~dp0lua_modules
set "PATH=%LUA_MODULES%\bin;%APPDATA%\luarocks\bin;%PATH%"
```

<!-- EXAMPLES_START generated examples please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN node scripts/update-readme.js TO UPDATE -->

### Face Detection with MediaPipe Tasks

```lua
--[[
Sources:
    https://colab.research.google.com/github/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/face_detector/python/face_detector.ipynb
    https://github.com/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/face_detector/python/face_detector.ipynb

Title: Face Detection with MediaPipe Tasks
--]]

local unpack = table.unpack or unpack ---@diagnostic disable-line: deprecated
local INDEX_BASE = 1 -- lua is 1-based indexed

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe

local opencv_lua = require("opencv_lua")
local round = opencv_lua.math.round
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

local download_utils = mediapipe.lua.solutions.download_utils

local function download_test_files(test_files)
    for _, kwargs in ipairs(test_files) do
        download_utils.download(mediapipe_lua.kwargs(kwargs))
    end
end

local MEDIAPIPE_SAMPLES_DATA_PATH = mediapipe_lua.fs_utils.findFile("samples") .. "/testdata"

local IMAGE_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/brother-sister-girl-family-boy-977170.jpg"
local IMAGE_URL = "https://i.imgur.com/Vu2Nqwb.jpg"
local IMAGE_HASH = "sha256=d584853ffb096fe584a099e6a0ea33150a37c96d812574c85c465512d9b0d2ac"
local MODEL_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/blaze_face_short_range.tflite"
local MODEL_URL = "https://storage.googleapis.com/mediapipe-models/face_detector/blaze_face_short_range/float16/1/blaze_face_short_range.tflite"
local MODEL_HASH = "sha256=b4578f35940bf5a1a655214a1cce5cab13eba73c1297cd78e1a04c2380b0152f"

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

local function isclose(a, b)
    return math.abs(a - b) <= 1e-6
end

local function _normalized_to_pixel_coordinates(
    normalized_x, normalized_y,
    image_width, image_height
)
    --[[ Converts normalized value pair to pixel coordinates. --]]

    -- Checks if the float value is between 0 and 1.
    local function is_valid_normalized_value(value)
        return (value > 0 or isclose(0, value)) and (value < 1 or
            isclose(1, value))
    end

    if not (is_valid_normalized_value(normalized_x) and
            is_valid_normalized_value(normalized_y)) then
        -- TODO: Draw coordinates even if it's outside of the image bounds.
        return nil
    end

    local x_px = math.min(math.floor(normalized_x * image_width), image_width - 1)
    local y_px = math.min(math.floor(normalized_y * image_height), image_height - 1)
    return { x_px, y_px }
end

--[[ Draws bounding boxes and keypoints on the input image and return it.
Args:
    image: The input RGB image.
    detection_result: The list of all "Detection" entities to be visualize.
Returns:
    Image with bounding boxes.
--]]
local function visualize(image, detection_result, scale)
    local MARGIN = math.floor(10 * scale) -- pixels
    local ROW_SIZE = 10                   -- pixels
    local FONT_SIZE = scale
    local FONT_THICKNESS = math.floor(2 * scale)
    local TEXT_COLOR = { 255, 0, 0 }      -- red

    local annotated_image = image:copy()
    local height, width, _ = unpack(image.shape)

    local color, thickness, radius = { 0, 255, 0 }, math.floor(2 * scale), math.floor(2 * scale)

    for _, detection in ipairs(detection_result.detections) do
        -- Draw bounding_box
        local bbox = detection.bounding_box
        local start_point = { bbox.origin_x, bbox.origin_y }
        local end_point = { bbox.origin_x + bbox.width, bbox.origin_y + bbox.height }
        cv2.rectangle(annotated_image, start_point, end_point, TEXT_COLOR, 3)

        -- Draw keypoints
        for _, keypoint in ipairs(detection.keypoints) do
            local keypoint_px = _normalized_to_pixel_coordinates(keypoint.x, keypoint.y,
                width, height)
            cv2.circle(annotated_image, keypoint_px, thickness, color, radius)
        end

        -- Draw label and score
        local category = detection.categories[0 + INDEX_BASE]
        local category_name = category.category_name
        category_name = (function()
            if category_name == nil then return '' end
            return category_name
        end)()
        local probability = round(category.score, 2)
        local result_text = category_name .. ' (' .. tostring(probability) .. ')'
        local text_location = { MARGIN + bbox.origin_x,
            MARGIN + ROW_SIZE + bbox.origin_y }
        cv2.putText(annotated_image, result_text, text_location, cv2.FONT_HERSHEY_PLAIN,
            FONT_SIZE, TEXT_COLOR, FONT_THICKNESS)
    end

    return annotated_image
end

-- STEP 1: Import the necessary modules.
local mp = mediapipe
local lua = mediapipe.tasks.lua
local vision = mediapipe.tasks.lua.vision

-- STEP 2: Create an FaceDetector object.
local base_options = lua.BaseOptions(mediapipe_lua.kwargs({ model_asset_path = MODEL_FILE }))
local options = vision.FaceDetectorOptions(mediapipe_lua.kwargs({ base_options = base_options }))
local detector = vision.FaceDetector.create_from_options(options)

-- STEP 3: Load the input image.
local image = mp.Image.create_from_file(IMAGE_FILE)

-- Compute the scale to make drawn elements visible when the image is resized for display
local scale = 1 / resize_and_show(image, nil, false)

-- STEP 4: Detect faces in the input image.
local detection_result = detector:detect(image)

-- STEP 5: Process the detection result. In this case, visualize it.
local image_copy = image:mat_view()
local annotated_image = visualize(image_copy, detection_result, scale)
local bgr_annotated_image = cv2.cvtColor(annotated_image, cv2.COLOR_RGB2BGR)
resize_and_show(bgr_annotated_image, "face_detector")
cv2.waitKey()

```

### Face Landmarks Detection with MediaPipe Tasks

```lua
--[[
Sources:
    https://colab.research.google.com/github/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/face_landmarker/python/%5BMediaPipe_Python_Tasks%5D_Face_Landmarker.ipynb
    https://github.com/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/face_landmarker/python/%5BMediaPipe_Python_Tasks%5D_Face_Landmarker.ipynb

Title: Face Landmarks Detection with MediaPipe Tasks
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

local download_utils = mediapipe.lua.solutions.download_utils

local function download_test_files(test_files)
    for _, kwargs in ipairs(test_files) do
        download_utils.download(mediapipe_lua.kwargs(kwargs))
    end
end

local MEDIAPIPE_SAMPLES_DATA_PATH = mediapipe_lua.fs_utils.findFile("samples") .. "/testdata"

local IMAGE_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/business-person.png"
local IMAGE_URL = "https://storage.googleapis.com/mediapipe-assets/business-person.png"
local IMAGE_HASH = "sha256=1f61cf0603cef77ffca4e24848ddf8290b5651d03b957e93b742c9ef963b5c11"
local MODEL_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/face_landmarker.task"
local MODEL_URL = "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task"
local MODEL_HASH = "sha256=64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff"

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

local solutions = mediapipe.solutions
local landmark_pb2 = mediapipe.framework.formats.landmark_pb2

local function draw_landmarks_on_image(rgb_image, detection_result)
    -- Compute the scale to make drawn elements visible when the image is resized for display
    local scale = 1 / resize_and_show(rgb_image, nil, false)

    local face_landmarks_list = detection_result.face_landmarks
    local annotated_image = rgb_image:copy()

    -- Loop through the detected faces to visualize.
    for idx = 1, #face_landmarks_list do
        local face_landmarks = face_landmarks_list[idx]

        -- Draw the face landmarks.
        local face_landmarks_proto = landmark_pb2.NormalizedLandmarkList()
        for _, landmark in ipairs(face_landmarks) do
            face_landmarks_proto.landmark:append(
                landmark_pb2.NormalizedLandmark(mediapipe_lua.kwargs({ x = landmark.x, y = landmark.y, z = landmark.z }))
            )
        end

        solutions.drawing_utils.draw_landmarks(mediapipe_lua.kwargs({
            image = annotated_image,
            landmark_list = face_landmarks_proto,
            connections = solutions.face_mesh.FACEMESH_TESSELATION,
            landmark_drawing_spec = {},
            connection_drawing_spec = solutions.drawing_styles
                    .get_default_face_mesh_tesselation_style(scale)
        }))
        solutions.drawing_utils.draw_landmarks(mediapipe_lua.kwargs({
            image = annotated_image,
            landmark_list = face_landmarks_proto,
            connections = solutions.face_mesh.FACEMESH_CONTOURS,
            landmark_drawing_spec = {},
            connection_drawing_spec = solutions.drawing_styles
                    .get_default_face_mesh_contours_style(mediapipe_lua.kwargs({ style = 1, scale = scale }))
        }))
        solutions.drawing_utils.draw_landmarks(mediapipe_lua.kwargs({
            image = annotated_image,
            landmark_list = face_landmarks_proto,
            connections = solutions.face_mesh.FACEMESH_IRISES,
            landmark_drawing_spec = {},
            connection_drawing_spec = solutions.drawing_styles
                    .get_default_face_mesh_iris_connections_style(scale)
        }))
    end

    return annotated_image
end


-- STEP 1: Import the necessary modules.
local mp = mediapipe
local lua = mediapipe.tasks.lua
local vision = mediapipe.tasks.lua.vision

-- STEP 2: Create an FaceLandmarker object.
local base_options = lua.BaseOptions(mediapipe_lua.kwargs({ model_asset_path = MODEL_FILE }))
local options = vision.FaceLandmarkerOptions(mediapipe_lua.kwargs({
    base_options = base_options,
    output_face_blendshapes = true,
    output_facial_transformation_matrixes = true,
    num_faces = 1
}))
local detector = vision.FaceLandmarker.create_from_options(options)

-- STEP 3: Load the input image.
local image = mp.Image.create_from_file(IMAGE_FILE)

-- STEP 4: Detect face landmarks from the input image.
local detection_result = detector:detect(image)

-- STEP 5: Process the detection result. In this case, visualize it.
local annotated_image = draw_landmarks_on_image(cv2.cvtColor(image:mat_view(), cv2.COLOR_RGB2BGR), detection_result)
resize_and_show(annotated_image, "face_landmarker")
cv2.waitKey()

```

### Face Stylizer

```lua
--[[
Sources:
    https://colab.research.google.com/github/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/face_stylizer/python/face_stylizer.ipynb
    https://github.com/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/face_stylizer/python/face_stylizer.ipynb

Title: Face Stylizer
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

local download_utils = mediapipe.lua.solutions.download_utils

local function download_test_files(test_files)
    for _, kwargs in ipairs(test_files) do
        download_utils.download(mediapipe_lua.kwargs(kwargs))
    end
end

local MEDIAPIPE_SAMPLES_DATA_PATH = mediapipe_lua.fs_utils.findFile("samples") .. "/testdata"

local IMAGE_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/business-person.png"
local IMAGE_URL = "https://storage.googleapis.com/mediapipe-assets/business-person.png"
local IMAGE_HASH = "sha256=1f61cf0603cef77ffca4e24848ddf8290b5651d03b957e93b742c9ef963b5c11"
local MODEL_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/face_stylizer_color_sketch.task"
local MODEL_URL = "https://storage.googleapis.com/mediapipe-models/face_stylizer/blaze_face_stylizer/float32/latest/face_stylizer_color_sketch.task"
local MODEL_HASH = "sha256=c22ae91703d9c3432f00b419c93590f3be3f3b98f7714b22431a702f8e76afff"

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

-- STEP 1: Import the necessary modules.
local mp = mediapipe
local lua = mediapipe.tasks.lua
local vision = mediapipe.tasks.lua.vision

-- Preview the images.
resize_and_show(cv2.imread(IMAGE_FILE), "face_stylizer: preview")

-- STEP 2: Create an FaceLandmarker object.
local base_options = lua.BaseOptions(mediapipe_lua.kwargs(({ model_asset_path = MODEL_FILE })))
local options = vision.FaceStylizerOptions(mediapipe_lua.kwargs(({ base_options = base_options })))
local stylizer = vision.FaceStylizer.create_from_options(options)

-- STEP 3: Load the input image.
local image = mp.Image.create_from_file(IMAGE_FILE)

-- STEP 4: Retrieve the stylized image
local stylized_image = stylizer:stylize(image)

-- STEP 5: Show the stylized image
local rgb_stylized_image = cv2.cvtColor(stylized_image:mat_view(), cv2.COLOR_RGB2BGR)
resize_and_show(rgb_stylized_image, "face_stylizer: stylized")
cv2.waitKey()

```

### Gesture Recognizer with MediaPipe Tasks

```lua
--[[
Sources:
    https://colab.research.google.com/github/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/gesture_recognizer/python/gesture_recognizer.ipynb
    https://github.com/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/gesture_recognizer/python/gesture_recognizer.ipynb

Title: Gesture Recognizer with MediaPipe Tasks
--]]

local INDEX_BASE = 1 -- lua is 1-based indexed

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

local download_utils = mediapipe.lua.solutions.download_utils

local MEDIAPIPE_SAMPLES_DATA_PATH = mediapipe_lua.fs_utils.findFile("samples") .. "/testdata"

local IMAGE_DOWNLOADS = {
    { output = "thumbs_down.jpg", hash = "sha256=080b589bf3b91ba10cc6c03645be3b5b491a8ca8c8f7d65b5f32c563ae266af9" },
    { output = "victory.jpg",     hash = "sha256=6ac265f3ace6a6c4ac4a9079b63fcce4ab6517272afb1e430857f55ef324fde6" },
    { output = "thumbs_up.jpg",   hash = "sha256=2aee0e3a69ba5f0d3287597e61d265f4f3ac2a44ccec198dddd2639b0c8ef7ba" },
    { output = "pointing_up.jpg", hash = "sha256=f4a701316b63dd8fa56e622f2b3042766369ccc189f0d89513f803cd985b993b" },
}

local IMAGE_FILENAMES = {}
for i, kwargs in ipairs(IMAGE_DOWNLOADS) do
    kwargs.url = "https://storage.googleapis.com/mediapipe-tasks/gesture_recognizer/" .. kwargs.output
    kwargs.output = MEDIAPIPE_SAMPLES_DATA_PATH .. "/" .. kwargs.output
    download_utils.download(mediapipe_lua.kwargs(kwargs))
    IMAGE_FILENAMES[i] = kwargs.output
end

local MODEL_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/gesture_recognizer.task"
local MODEL_URL = "https://storage.googleapis.com/mediapipe-models/gesture_recognizer/gesture_recognizer/float16/1/gesture_recognizer.task"
local MODEL_HASH = "sha256=97952348cf6a6a4915c2ea1496b4b37ebabc50cbbf80571435643c455f2b0482"
download_utils.download(mediapipe_lua.kwargs({
    output = MODEL_FILE,
    url = MODEL_URL,
    hash = MODEL_HASH,
}))

local mp = mediapipe
local landmark_pb2 = mediapipe.framework.formats.landmark_pb2

local mp_hands = mp.solutions.hands
local mp_drawing = mp.solutions.drawing_utils
local mp_drawing_styles = mp.solutions.drawing_styles

--[[ Displays an image with the gesture category and its score along with the hand landmarks. --]]
local function display_image_with_gestures_and_hand_landmarks(image, gesture, hands_landmarks)
    -- Display gestures and hand landmarks.
    local annotated_image = cv2.cvtColor(image:mat_view(), cv2.COLOR_RGB2BGR)
    local title = ("%s (%.2f)"):format(gesture.category_name, gesture.score)

    -- Compute the scale to make drawn elements visible when the image is resized for display
    local scale = 1 / resize_and_show(annotated_image, nil, false)

    for _, hand_landmarks in ipairs(hands_landmarks) do
        local hand_landmarks_proto = landmark_pb2.NormalizedLandmarkList()

        for _, landmark in ipairs(hand_landmarks) do
            hand_landmarks_proto.landmark:append(landmark_pb2.NormalizedLandmark(
                mediapipe_lua.kwargs({ x = landmark.x, y = landmark.y, z = landmark.z })
            ))
        end

        mp_drawing.draw_landmarks(
            annotated_image,
            hand_landmarks_proto,
            mp_hands.HAND_CONNECTIONS,
            mp_drawing_styles.get_default_hand_landmarks_style(scale),
            mp_drawing_styles.get_default_hand_connections_style(scale))
    end

    resize_and_show(annotated_image, title)
end

-- STEP 1: Import the necessary modules.
local lua = mediapipe.tasks.lua
local vision = mediapipe.tasks.lua.vision

-- STEP 2: Create an GestureRecognizer object.
local base_options = lua.BaseOptions(mediapipe_lua.kwargs({ model_asset_path = MODEL_FILE }))
local options = vision.GestureRecognizerOptions(mediapipe_lua.kwargs({ base_options = base_options }))
local recognizer = vision.GestureRecognizer.create_from_options(options)

for _, image_file_name in ipairs(IMAGE_FILENAMES) do
    -- STEP 3: Load the input image.
    local image = mp.Image.create_from_file(image_file_name)

    -- STEP 4: Recognize gestures in the input image.
    local recognition_result = recognizer:recognize(image)

    -- STEP 5: Process the result. In this case, visualize it.
    local top_gesture = recognition_result.gestures[0 + INDEX_BASE][0 + INDEX_BASE]
    local hands_landmarks = recognition_result.hand_landmarks
    display_image_with_gestures_and_hand_landmarks(image, top_gesture, hands_landmarks)
end

cv2.waitKey()

```

### Hand Landmarks Detection with MediaPipe Tasks

```lua
--[[
Sources:
    https://colab.research.google.com/github/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/hand_landmarker/python/hand_landmarker.ipynb
    https://github.com/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/hand_landmarker/python/hand_landmarker.ipynb

Title: Hand Landmarks Detection with MediaPipe Tasks
--]]

local unpack = table.unpack or unpack ---@diagnostic disable-line: deprecated
local INDEX_BASE = 1 -- lua is 1-based indexed
local int = math.floor

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

local download_utils = mediapipe.lua.solutions.download_utils

local function download_test_files(test_files)
    for _, kwargs in ipairs(test_files) do
        download_utils.download(mediapipe_lua.kwargs(kwargs))
    end
end

local MEDIAPIPE_SAMPLES_DATA_PATH = mediapipe_lua.fs_utils.findFile("samples") .. "/testdata"

local IMAGE_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/woman_hands.jpg"
local IMAGE_URL = "https://storage.googleapis.com/mediapipe-tasks/hand_landmarker/woman_hands.jpg"
local IMAGE_HASH = "sha256=70cbeb38e198c9862202e0979c21a99b40ca980d3e7b250176c85b1636a40f12"
local MODEL_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/hand_landmarker.task"
local MODEL_URL = "https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task"
local MODEL_HASH = "sha256=fbc2a30080c3c557093b5ddfc334698132eb341044ccee322ccf8bcf3607cde1"

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

local solutions = mediapipe.solutions
local landmark_pb2 = mediapipe.framework.formats.landmark_pb2

local function draw_landmarks_on_image(rgb_image, detection_result)
    -- Compute the scale to make drawn elements visible when the image is resized for display
    local scale = 1 / resize_and_show(rgb_image, nil, false)

    local MARGIN = 10 * scale -- pixels
    local FONT_SIZE = scale
    local FONT_THICKNESS = math.floor(2 * scale)
    local HANDEDNESS_TEXT_COLOR = { 88, 205, 54 } -- vibrant green

    local hand_landmarks_list = detection_result.hand_landmarks
    local handedness_list = detection_result.handedness
    local annotated_image = rgb_image:copy()

    -- Loop through the detected hands to visualize.
    for idx = 1, #hand_landmarks_list do
        local hand_landmarks = hand_landmarks_list[idx]
        local handedness = handedness_list[idx]
        local min_x = 1
        local min_y = 1

        -- Draw the hand landmarks.
        local hand_landmarks_proto = landmark_pb2.NormalizedLandmarkList()
        for _, landmark in ipairs(hand_landmarks) do
            hand_landmarks_proto.landmark:append(landmark_pb2.NormalizedLandmark(mediapipe_lua.kwargs({
                x = landmark.x,
                y =
                        landmark.y,
                z = landmark.z
            })))
            min_x = math.min(min_x, landmark.x)
            min_y = math.min(min_y, landmark.y)
        end

        solutions.drawing_utils.draw_landmarks(
            annotated_image,
            hand_landmarks_proto,
            solutions.hands.HAND_CONNECTIONS,
            solutions.drawing_styles.get_default_hand_landmarks_style(),
            solutions.drawing_styles.get_default_hand_connections_style())

        -- Get the top left corner of the detected hand's bounding box.
        local height, width, _ = unpack(annotated_image.shape)
        local text_x = int(min_x * width)
        local text_y = int(min_y * height - MARGIN)

        -- Draw handedness (left or right hand) on the image.
        cv2.putText(annotated_image, handedness[0 + INDEX_BASE].category_name,
            { text_x, text_y }, cv2.FONT_HERSHEY_DUPLEX,
            FONT_SIZE, HANDEDNESS_TEXT_COLOR, FONT_THICKNESS, cv2.LINE_AA)
    end

    return annotated_image
end

-- STEP 1: Import the necessary modules.
local mp = mediapipe
local lua = mediapipe.tasks.lua
local vision = mediapipe.tasks.lua.vision

-- STEP 2: Create an HandLandmarker object.
local base_options = lua.BaseOptions(mediapipe_lua.kwargs({ model_asset_path = MODEL_FILE }))
local options = vision.HandLandmarkerOptions(mediapipe_lua.kwargs({
    base_options = base_options,
    num_hands = 2
}))
local detector = vision.HandLandmarker.create_from_options(options)

-- STEP 3: Load the input image.
local image = mp.Image.create_from_file(IMAGE_FILE)

-- STEP 4: Detect hand landmarks from the input image.
local detection_result = detector:detect(image)

-- STEP 5: Process the classification result. In this case, visualize it.
local annotated_image = draw_landmarks_on_image(cv2.cvtColor(image:mat_view(), cv2.COLOR_RGB2BGR), detection_result)
resize_and_show(annotated_image, "hand_landmarker")
cv2.waitKey()

```

### Image Classifier with MediaPipe Tasks

```lua
--[[
Sources:
    https://colab.research.google.com/github/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/image_classification/python/image_classifier.ipynb
    https://github.com/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/image_classification/python/image_classifier.ipynb

Title: Image Classifier with MediaPipe Tasks
--]]

local INDEX_BASE = 1 -- lua is 1-based indexed

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

local download_utils = mediapipe.lua.solutions.download_utils

local MEDIAPIPE_SAMPLES_DATA_PATH = mediapipe_lua.fs_utils.findFile("samples") .. "/testdata"

local IMAGE_DOWNLOADS = {
    { output = "burger.jpg", hash = "sha256=08151ebb48f30a6cfbea02168ec0f3c0f1694d64c8d0f75ca08a63a89302853f" },
    { output = "cat.jpg",    hash = "sha256=a83aa74a3d1d9bbc8bf92065e6e4d1ba217438a9f4a95f35287b2e8316e83859" },
}

local IMAGE_FILENAMES = {}
for i, kwargs in ipairs(IMAGE_DOWNLOADS) do
    kwargs.url = "https://storage.googleapis.com/mediapipe-tasks/image_classifier/" .. kwargs.output
    kwargs.output = MEDIAPIPE_SAMPLES_DATA_PATH .. "/" .. kwargs.output
    download_utils.download(mediapipe_lua.kwargs(kwargs))
    IMAGE_FILENAMES[i] = kwargs.output
end

local MODEL_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/efficientnet_lite0.tflite"
local MODEL_URL = "https://storage.googleapis.com/mediapipe-models/image_classifier/efficientnet_lite0/float32/1/efficientnet_lite0.tflite"
local MODEL_HASH = "sha256=6c7ab0a6e5dcbf38a8c33b960996a55a3b4300b36a018c4545801de3a3c8bde0"
download_utils.download(mediapipe_lua.kwargs({
    output = MODEL_FILE,
    url = MODEL_URL,
    hash = MODEL_HASH,
}))

-- STEP 1: Import the necessary modules.
local mp = mediapipe
local lua = mediapipe.tasks.lua
local vision = mediapipe.tasks.lua.vision

-- STEP 2: Create an ImageClassifier object.
local base_options = lua.BaseOptions(mediapipe_lua.kwargs({ model_asset_path = MODEL_FILE }))
local options = vision.ImageClassifierOptions(mediapipe_lua.kwargs({
    base_options = base_options, max_results = 4 }))
local classifier = vision.ImageClassifier.create_from_options(options)

for _, image_name in ipairs(IMAGE_FILENAMES) do
    -- STEP 3: Load the input image.
    local image = mp.Image.create_from_file(image_name)

    -- STEP 4: Classify the input image.
    local classification_result = classifier:classify(image)

    -- STEP 5: Process the classification result. In this case, visualize it.
    local top_category = classification_result.classifications[0 + INDEX_BASE].categories[0 + INDEX_BASE]
    local title = ("%s (%.2f)"):format(top_category.category_name, top_category.score)
    resize_and_show(cv2.cvtColor(image:mat_view(), cv2.COLOR_RGB2BGR), title)
end

cv2.waitKey()

```

### Image Embedding with MediaPipe Tasks

```lua
--[[
Sources:
    https://colab.research.google.com/github/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/image_embedder/python/image_embedder.ipynb
    https://github.com/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/image_embedder/python/image_embedder.ipynb

Title: Image Embedding with MediaPipe Tasks
--]]

local INDEX_BASE = 1 -- lua is 1-based indexed

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

local download_utils = mediapipe.lua.solutions.download_utils

local MEDIAPIPE_SAMPLES_DATA_PATH = mediapipe_lua.fs_utils.findFile("samples") .. "/testdata"

local IMAGE_DOWNLOADS = {
    { output = "burger.jpg",      hash = "sha256=97c15bbbf3cf3615063b1031c85d669de55839f59262bbe145d15ca75b36ecbf" },
    { output = "burger_crop.jpg", hash = "sha256=8f58de573f0bf59a49c3d86cfabb9ad4061481f574aa049177e8da3963dddc50" },
}

local IMAGE_FILENAMES = {}
for i, kwargs in ipairs(IMAGE_DOWNLOADS) do
    kwargs.url = "https://storage.googleapis.com/mediapipe-assets/" .. kwargs.output
    kwargs.output = MEDIAPIPE_SAMPLES_DATA_PATH .. "/" .. kwargs.output
    download_utils.download(mediapipe_lua.kwargs(kwargs))
    IMAGE_FILENAMES[i] = kwargs.output
end

local MODEL_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/mobilenet_v3_small.tflite"
local MODEL_URL = "https://storage.googleapis.com/mediapipe-models/image_embedder/mobilenet_v3_small/float32/1/mobilenet_v3_small.tflite"
local MODEL_HASH = "sha256=bbbb4c51a55a53905af1daec995ca1aae355046f8839bb8c9f5ce9271394bc40"
download_utils.download(mediapipe_lua.kwargs({
    output = MODEL_FILE,
    url = MODEL_URL,
    hash = MODEL_HASH,
}))

-- STEP 1: Import the necessary modules.
local mp = mediapipe
local lua = mediapipe.tasks.lua
local vision = mediapipe.tasks.lua.vision

-- STEP 2: Create options for Image Embedder
local base_options = lua.BaseOptions(mediapipe_lua.kwargs({ model_asset_path = MODEL_FILE }))
local l2_normalize = true --@param {type:"boolean"}
local quantize = true     --@param {type:"boolean"}
local options = vision.ImageEmbedderOptions(mediapipe_lua.kwargs({
    base_options = base_options, l2_normalize = l2_normalize, quantize = quantize }))

-- STEP 3: Create Image Embedder
local embedder = vision.ImageEmbedder.create_from_options(options)

-- STEP 4: Format images for MediaPipe
local first_image = mp.Image.create_from_file(IMAGE_FILENAMES[0 + INDEX_BASE])
local second_image = mp.Image.create_from_file(IMAGE_FILENAMES[1 + INDEX_BASE])
local first_embedding_result = embedder:embed(first_image)
local second_embedding_result = embedder:embed(second_image)

-- STEP 5: Calculate and print similarity
local similarity = vision.ImageEmbedder.cosine_similarity(
    first_embedding_result.embeddings[0 + INDEX_BASE],
    second_embedding_result.embeddings[0 + INDEX_BASE])
print("similarity = " .. similarity)

-- Display images
resize_and_show(cv2.cvtColor(first_image:mat_view(), cv2.COLOR_RGB2BGR), IMAGE_FILENAMES[0 + INDEX_BASE]:sub(#MEDIAPIPE_SAMPLES_DATA_PATH + 2))
resize_and_show(cv2.cvtColor(second_image:mat_view(), cv2.COLOR_RGB2BGR), IMAGE_FILENAMES[1 + INDEX_BASE]:sub(#MEDIAPIPE_SAMPLES_DATA_PATH + 2))
cv2.waitKey()

```

### Image Segmenter

```lua
--[[
Sources:
    https://colab.research.google.com/github/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/image_segmentation/python/image_segmentation.ipynb
    https://github.com/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/image_segmentation/python/image_segmentation.ipynb

Title: Image Segmenter
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

local download_utils = mediapipe.lua.solutions.download_utils

local MEDIAPIPE_SAMPLES_DATA_PATH = mediapipe_lua.fs_utils.findFile("samples") .. "/testdata"

local IMAGE_DOWNLOADS = {
    { output = "segmentation_input_rotation0.jpg", hash = "sha256=5bf58d8af1f1c33224f3f3bc0ce451c8daf0739cc15a86d59d8c3bf2879afb97" },
}

local IMAGE_FILENAMES = {}
for i, kwargs in ipairs(IMAGE_DOWNLOADS) do
    kwargs.url = "https://storage.googleapis.com/mediapipe-assets/" .. kwargs.output
    kwargs.output = MEDIAPIPE_SAMPLES_DATA_PATH .. "/" .. kwargs.output
    download_utils.download(mediapipe_lua.kwargs(kwargs))
    IMAGE_FILENAMES[i] = kwargs.output
end

local MODEL_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/deeplab_v3.tflite"
local MODEL_URL = "https://storage.googleapis.com/mediapipe-models/image_segmenter/deeplab_v3/float32/1/deeplab_v3.tflite"
local MODEL_HASH = "sha256=ff36e24d40547fe9e645e2f4e8745d1876d6e38b332d39a82f0bf0f5d1d561b3"
download_utils.download(mediapipe_lua.kwargs({
    output = MODEL_FILE,
    url = MODEL_URL,
    hash = MODEL_HASH,
}))

-- STEP 1: Import the necessary modules.
local mp = mediapipe
local lua = mediapipe.tasks.lua
local vision = mediapipe.tasks.lua.vision

local BG_COLOR = { 192, 192, 192 } -- gray
local FG_COLOR = { 255, 255, 255 } -- white

-- STEP 2: Create the options that will be used for ImageSegmenter
local base_options = lua.BaseOptions(mediapipe_lua.kwargs({ model_asset_path = MODEL_FILE }))
local options = vision.ImageSegmenterOptions(mediapipe_lua.kwargs({
    base_options = base_options,
    output_category_mask = true
}))

-- STEP 3: Create the image segmenter
local segmenter = vision.ImageSegmenter.create_from_options(options)

-- Loop through demo image(s)
for _, image_file_name in ipairs(IMAGE_FILENAMES) do
    -- STEP 4: Create the MediaPipe image file that will be segmented
    local image = mp.Image.create_from_file(image_file_name)

    -- STEP 5: Retrieve the mask for the segmented image
    local segmentation_result = segmenter:segment(image)
    local category_mask = segmentation_result.category_mask

    -- mediapipe uses RGB images while opencv uses BGR images
    local image_data = cv2.cvtColor(image:mat_view(), cv2.COLOR_RGB2BGR)

    -- Generate a solid color images for showing the output segmentation mask.
    local fg_image = cv2.Mat(image_data:size(), cv2.CV_8UC3, FG_COLOR)
    local bg_image = cv2.Mat(image_data:size(), cv2.CV_8UC3, BG_COLOR)

    -- The foreground mask corresponds to all 'i' pixels where category_mask[i] > 0.2
    local fg_mask = cv2.compare(category_mask:mat_view(), 0.2, cv2.CMP_GT)

    -- Draw fg_image on bg_image only where fg_mask should apply
    local output_image = bg_image:copy()
    fg_image:copyTo(opencv_lua.kwargs({ mask = fg_mask, dst = output_image }))
    resize_and_show(output_image, "Segmentation mask of " .. image_file_name:sub(#MEDIAPIPE_SAMPLES_DATA_PATH + 2))

    -- Blur the image only where fg_mask should not apply
    local blurred_image = cv2.GaussianBlur(image_data, { 55, 55 }, 0)
    image_data:copyTo(opencv_lua.kwargs({ mask = fg_mask, dst = blurred_image }))
    resize_and_show(blurred_image, "Blurred background of " .. image_file_name:sub(#MEDIAPIPE_SAMPLES_DATA_PATH + 2))
end

cv2.waitKey()

```

### Interactive Image Segmenter

```lua
--[[
Sources:
    https://colab.research.google.com/github/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/interactive_segmentation/python/interactive_segmenter.ipynb
    https://github.com/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/interactive_segmentation/python/interactive_segmenter.ipynb

Title: Interactive Image Segmenter
--]]

local int = math.floor

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

local download_utils = mediapipe.lua.solutions.download_utils

local MEDIAPIPE_SAMPLES_DATA_PATH = mediapipe_lua.fs_utils.findFile("samples") .. "/testdata"

local IMAGE_DOWNLOADS = {
    { output = "cats_and_dogs.jpg", hash = "sha256=a2eaa7ad3a1aae4e623dd362a5f737e8a88d122597ecd1a02b3e1444db56df9c" },
}

local IMAGE_FILENAMES = {}
for i, kwargs in ipairs(IMAGE_DOWNLOADS) do
    kwargs.url = "https://storage.googleapis.com/mediapipe-assets/" .. kwargs.output
    kwargs.output = MEDIAPIPE_SAMPLES_DATA_PATH .. "/" .. kwargs.output
    download_utils.download(mediapipe_lua.kwargs(kwargs))
    IMAGE_FILENAMES[i] = kwargs.output
end

local MODEL_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/magic_touch.tflite"
local MODEL_URL = "https://storage.googleapis.com/mediapipe-models/interactive_segmenter/magic_touch/float32/1/magic_touch.tflite"
local MODEL_HASH = "sha256=e24338a717c1b7ad8d159666677ef400babb7f33b8ad60c4d96db4ecf694cd25"
download_utils.download(mediapipe_lua.kwargs({
    output = MODEL_FILE,
    url = MODEL_URL,
    hash = MODEL_HASH,
}))

local function isclose(a, b)
    return math.abs(a - b) <= 1e-6
end

local function _normalized_to_pixel_coordinates(
    normalized_x, normalized_y,
    image_width, image_height
)
    --[[ Converts normalized value pair to pixel coordinates. --]]

    -- Checks if the float value is between 0 and 1.
    local function is_valid_normalized_value(value)
        return (value > 0 or isclose(0, value)) and (value < 1 or
            isclose(1, value))
    end

    if not (is_valid_normalized_value(normalized_x) and
            is_valid_normalized_value(normalized_y)) then
        -- TODO: Draw coordinates even if it's outside of the image bounds.
        return nil
    end

    local x_px = math.min(math.floor(normalized_x * image_width), image_width - 1)
    local y_px = math.min(math.floor(normalized_y * image_height), image_height - 1)
    return { x_px, y_px }
end


-- STEP 1: Import the necessary modules.
local mp = mediapipe

local lua = mediapipe.tasks.lua
local vision = mediapipe.tasks.lua.vision
local containers = mediapipe.tasks.lua.components.containers

local x = 0.68                      --@param {type:"slider", min:0, max:1, step:0.01}
local y = 0.68                      --@param {type:"slider", min:0, max:1, step:0.01}

local BG_COLOR = { 192, 192, 192 }  -- gray
local FG_COLOR = { 255, 255, 255 }  -- white
local OVERLAY_COLOR = { 100, 100, 0 } -- cyan

local RegionOfInterest = vision.InteractiveSegmenterRegionOfInterest
local NormalizedKeypoint = containers.keypoint.NormalizedKeypoint

-- Create the options that will be used for InteractiveSegmenter
local base_options = lua.BaseOptions(mediapipe_lua.kwargs({ model_asset_path = MODEL_FILE }))
local options = vision.InteractiveSegmenterOptions(mediapipe_lua.kwargs({
    base_options = base_options,
    output_category_mask = true
}))

-- Create the interactive segmenter
local segmenter = vision.InteractiveSegmenter.create_from_options(options)

local color = { 255, 255, 0 }

-- Loop through demo image(s)
for _, image_file_name in ipairs(IMAGE_FILENAMES) do
    -- Create the MediaPipe image file that will be segmented
    local image = mp.Image.create_from_file(image_file_name)

    -- Retrieve the masks for the segmented image
    local roi = RegionOfInterest(mediapipe_lua.kwargs({
        format = RegionOfInterest.Format.KEYPOINT,
        keypoint = NormalizedKeypoint(x, y)
    }))
    local segmentation_result = segmenter:segment(image, roi)
    local category_mask = segmentation_result.category_mask

    -- mediapipe uses RGB images while opencv uses BGR images
    local image_data = cv2.cvtColor(image:mat_view(), cv2.COLOR_RGB2BGR)

    -- Generate a solid color images for showing the output segmentation mask.
    local fg_image = cv2.Mat(image_data:size(), cv2.CV_8UC3, FG_COLOR)
    local bg_image = cv2.Mat(image_data:size(), cv2.CV_8UC3, BG_COLOR)

    -- The foreground mask corresponds to all 'i' pixels where category_mask[i] > 0.2
    local fg_mask = cv2.compare(category_mask:mat_view(), 0.2, cv2.CMP_GT)

    -- Draw fg_image on bg_image only where fg_mask should apply
    local output_image = bg_image:copy()
    fg_image:copyTo(opencv_lua.kwargs({ mask = fg_mask, dst = output_image }))

    -- Compute the point of interest coordinates
    local keypoint_px = _normalized_to_pixel_coordinates(x, y, image.width, image.height)

    -- Compute the scale to make drawn elements visible when the image is resized for display
    local scale = 1 / resize_and_show(image, nil, false)

    local thickness = int(10 * scale)
    local radius = int(2 * scale)

    -- Draw a circle to denote the point of interest
    cv2.circle(output_image, keypoint_px, thickness, color, radius)

    -- Display the segmented image
    resize_and_show(output_image, "Segmentation mask of " .. image_file_name:sub(#MEDIAPIPE_SAMPLES_DATA_PATH + 2))

    -- Blur the image only where fg_mask the mask should not apply
    local blurred_image = cv2.GaussianBlur(image_data, { 55, 55 }, 0)
    image_data:copyTo(opencv_lua.kwargs({ mask = fg_mask, dst = blurred_image }))

    -- Draw a circle to denote the point of interest
    cv2.circle(blurred_image, keypoint_px, thickness, color, radius)

    -- Display the blurred image
    resize_and_show(blurred_image, "Blurred background of " .. image_file_name:sub(#MEDIAPIPE_SAMPLES_DATA_PATH + 2))

    -- Create an overlay image with the desired color (e.g., (255, 0, 0) for red)
    local overlayed_image = cv2.Mat(image_data:size(), cv2.CV_32FC3, OVERLAY_COLOR)

    -- Create an alpha channel based on the segmentation mask with the desired opacity (e.g., 0.7 for 70%)
    -- fg_mask values are 0 where the mask should not apply and 255 where it should
    -- multiplying by 0.7 / 255.0 gives values that are 0 where the mask should not apply and 0.7 where it should
    local alpha = fg_mask:convertTo(cv2.CV_32F, opencv_lua.kwargs({ alpha = 0.7 / 255.0 }))

    -- repeat the alpha mask for each image channel color
    alpha = cv2.merge({ alpha, alpha, alpha })

    -- Blend the original image and the overlay image based on the alpha channel
    overlayed_image = image_data:convertTo(cv2.CV_32F) * (1 - alpha) + overlayed_image * alpha
    overlayed_image = overlayed_image:convertTo(cv2.CV_8U)

    -- Draw a circle to denote the point of interest
    cv2.circle(overlayed_image, keypoint_px, thickness, color, radius)

    -- Display the overlayed image
    resize_and_show(overlayed_image, "Overlayed foreground of " .. image_file_name:sub(#MEDIAPIPE_SAMPLES_DATA_PATH + 2))
end

cv2.waitKey()

```

### Language Detector with MediaPipe Tasks

```lua
--[[
Sources:
    https://colab.research.google.com/github/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/language_detector/python/%5BMediaPipe_Python_Tasks%5D_Language_Detector.ipynb
    https://github.com/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/language_detector/python/%5BMediaPipe_Python_Tasks%5D_Language_Detector.ipynb

Title: Language Detector with MediaPipe Tasks
--]]

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe

local download_utils = mediapipe.lua.solutions.download_utils

local MEDIAPIPE_SAMPLES_DATA_PATH = mediapipe_lua.fs_utils.findFile("samples") .. "/testdata"

local MODEL_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/language_detector.tflite"
local MODEL_URL = "https://storage.googleapis.com/mediapipe-models/language_detector/language_detector/float32/latest/language_detector.tflite"
local MODEL_HASH = "sha256=7db4f23dfe1ad8966b050b419a865da451143fd43eb6b606a256aadeeb1e5417"
download_utils.download(mediapipe_lua.kwargs({
    output = MODEL_FILE,
    url = MODEL_URL,
    hash = MODEL_HASH,
}))


-- Define the input text that you wants the model to classify.
local INPUT_TEXT = "分久必合合久必分" --@param {type:"string"}

-- STEP 1: Import the necessary modules.
local lua = mediapipe.tasks.lua
local text = mediapipe.tasks.lua.text

-- STEP 2: Create a LanguageDetector object.
local base_options = lua.BaseOptions(mediapipe_lua.kwargs({ model_asset_path = MODEL_FILE }))
local options = text.LanguageDetectorOptions(mediapipe_lua.kwargs({ base_options = base_options }))
local detector = text.LanguageDetector.create_from_options(options)

-- STEP 3: Get the language detcetion result for the input text.
local detection_result = detector:detect(INPUT_TEXT)

-- STEP 4: Process the detection result and print the languages detected and
-- their scores.
for _, detection in ipairs(detection_result.detections) do
    print(("%s: (%.2f)"):format(detection.language_code, detection.probability))
end

```

### Object Detection with MediaPipe Tasks

```lua
--[[
Sources:
    https://colab.research.google.com/github/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/object_detection/python/object_detector.ipynb
    https://github.com/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/object_detection/python/object_detector.ipynb

Title: Object Detection with MediaPipe Tasks
--]]

local INDEX_BASE = 1 -- lua is 1-based indexed
local int = math.floor

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe

local opencv_lua = require("opencv_lua")
local cv2 = opencv_lua.cv
local round = opencv_lua.math.round

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

local download_utils = mediapipe.lua.solutions.download_utils

local function download_test_files(test_files)
    for _, kwargs in ipairs(test_files) do
        download_utils.download(mediapipe_lua.kwargs(kwargs))
    end
end

local MEDIAPIPE_SAMPLES_DATA_PATH = mediapipe_lua.fs_utils.findFile("samples") .. "/testdata"

local IMAGE_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/cat_and_dog.jpg"
local IMAGE_URL = "https://storage.googleapis.com/mediapipe-tasks/object_detector/cat_and_dog.jpg"
local IMAGE_HASH = "sha256=cfa90c34bb93021165e48bd22cfc20dbbb0440ff638a54878939bf30d362e824"
local MODEL_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/efficientdet_lite0.tflite"
local MODEL_URL = "https://storage.googleapis.com/mediapipe-models/object_detector/efficientdet_lite0/int8/1/efficientdet_lite0.tflite"
local MODEL_HASH = "sha256=0720bf247bd76e6594ea28fa9c6f7c5242be774818997dbbeffc4da460c723bb"

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

--[[
Draws bounding boxes on the input image and return it.
  Args:
    image: The input RGB image.
    detection_result: The list of all "Detection" entities to be visualize.
  Returns:
    Image with bounding boxes.
]]
local function visualize(
    image,
    detection_result,
    scale
)
    local MARGIN = int(10 * scale) -- pixels
    local ROW_SIZE = 10            -- pixels
    local FONT_SIZE = scale
    local FONT_THICKNESS = int(scale)
    local TEXT_COLOR = { 255, 0, 0 } -- red

    for _, detection in ipairs(detection_result.detections) do
        -- Draw bounding_box
        local bbox = detection.bounding_box
        local start_point = { bbox.origin_x, bbox.origin_y }
        local end_point = { bbox.origin_x + bbox.width, bbox.origin_y + bbox.height }
        cv2.rectangle(image, start_point, end_point, TEXT_COLOR, 3)

        -- Draw label and score
        local category = detection.categories[0 + INDEX_BASE]
        local category_name = category.category_name
        local probability = round(category.score, 2)
        local result_text = category_name .. ' (' .. tostring(probability) .. ')'
        local text_location = { MARGIN + bbox.origin_x,
            MARGIN + ROW_SIZE + bbox.origin_y }
        cv2.putText(image, result_text, text_location, cv2.FONT_HERSHEY_PLAIN,
            FONT_SIZE, TEXT_COLOR, FONT_THICKNESS)
    end

    return image
end

-- STEP 1: Import the necessary modules.
local mp = mediapipe
local lua = mediapipe.tasks.lua
local vision = mediapipe.tasks.lua.vision

-- STEP 2: Create an ObjectDetector object.
local base_options = lua.BaseOptions(mediapipe_lua.kwargs({ model_asset_path = MODEL_FILE }))
local options = vision.ObjectDetectorOptions(mediapipe_lua.kwargs({
    base_options = base_options,
    score_threshold = 0.5
}))
local detector = vision.ObjectDetector.create_from_options(options)

-- STEP 3: Load the input image.
local image = mp.Image.create_from_file(IMAGE_FILE)

-- Compute the scale to make drawn elements visible when the image is resized for display
local scale = 1 / resize_and_show(image, nil, false)

-- STEP 4: Detect objects in the input image.
local detection_result = detector:detect(image)

-- STEP 5: Process the detection result. In this case, visualize it.
local image_copy = image:mat_view()
local annotated_image = visualize(image_copy, detection_result, scale)
local rgb_annotated_image = cv2.cvtColor(annotated_image, cv2.COLOR_BGR2RGB)
resize_and_show(rgb_annotated_image, "object_detection")
cv2.waitKey()

```

### Pose Landmarks Detection with MediaPipe Tasks

```lua
--[[
Sources:
    https://colab.research.google.com/github/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/pose_landmarker/python/%5BMediaPipe_Python_Tasks%5D_Pose_Landmarker.ipynb
    https://github.com/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/pose_landmarker/python/%5BMediaPipe_Python_Tasks%5D_Pose_Landmarker.ipynb

Title: Pose Landmarks Detection with MediaPipe Tasks
--]]

local INDEX_BASE = 1 -- lua is 1-based indexed

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

local download_utils = mediapipe.lua.solutions.download_utils

local function download_test_files(test_files)
    for _, kwargs in ipairs(test_files) do
        download_utils.download(mediapipe_lua.kwargs(kwargs))
    end
end

local MEDIAPIPE_SAMPLES_DATA_PATH = mediapipe_lua.fs_utils.findFile("samples") .. "/testdata"

local IMAGE_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/girl-4051811_960_720.jpg"
local IMAGE_URL = "https://cdn.pixabay.com/photo/2019/03/12/20/39/girl-4051811_960_720.jpg"
local IMAGE_HASH = "sha256=99e0649aa4f2553b0213982f544146565a1028877c4bb9fbe3884453659d8cdc"
local MODEL_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/pose_landmarker_heavy.task"
local MODEL_URL = "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_heavy/float16/1/pose_landmarker_heavy.task"
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

local solutions = mediapipe.solutions
local landmark_pb2 = mediapipe.framework.formats.landmark_pb2

local function draw_landmarks_on_image(rgb_image, detection_result)
    local scale = 1 / resize_and_show(rgb_image, nil, false)
    local pose_landmarks_list = detection_result.pose_landmarks
    local annotated_image = rgb_image:copy()

    -- Loop through the detected poses to visualize.
    for idx = 1, #pose_landmarks_list do
        local pose_landmarks = pose_landmarks_list[idx]

        -- Draw the pose landmarks.
        local pose_landmarks_proto = landmark_pb2.NormalizedLandmarkList()
        for _, landmark in ipairs(pose_landmarks) do
            pose_landmarks_proto.landmark:append(
                landmark_pb2.NormalizedLandmark(mediapipe_lua.kwargs({ x = landmark.x, y = landmark.y, z = landmark.z }))
            )
        end

        solutions.drawing_utils.draw_landmarks(
            annotated_image,
            pose_landmarks_proto,
            solutions.pose.POSE_CONNECTIONS,
            solutions.drawing_styles.get_default_pose_landmarks_style(scale))
    end
    return annotated_image
end

-- STEP 1: Import the necessary modules.
local mp = mediapipe
local lua = mediapipe.tasks.lua
local vision = mediapipe.tasks.lua.vision

-- STEP 2: Create an PoseLandmarker object.
local base_options = lua.BaseOptions(mediapipe_lua.kwargs({ model_asset_path = MODEL_FILE }))
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
resize_and_show(cv2.cvtColor(annotated_image, cv2.COLOR_RGB2BGR), "Pose Landmarks Detection with MediaPipe Tasks : Image")

-- Visualize the pose segmentation mask.
local segmentation_mask = detection_result.segmentation_masks[0 + INDEX_BASE]:mat_view()
local visualized_mask = segmentation_mask:convertTo(cv2.CV_8U, opencv_lua.kwargs({ alpha = 255 }))
resize_and_show(visualized_mask, "Pose Landmarks Detection with MediaPipe Tasks : Mask")

cv2.waitKey()

```

### Text Classifier with MediaPipe Tasks

```lua
--[[
Sources:
    https://colab.research.google.com/github/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/text_classification/python/text_classifier.ipynb
    https://github.com/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/text_classification/python/text_classifier.ipynb

Title: Text Classifier with MediaPipe Tasks
--]]

local INDEX_BASE = 1 -- lua is 1-based indexed

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe

local download_utils = mediapipe.lua.solutions.download_utils

local MEDIAPIPE_SAMPLES_DATA_PATH = mediapipe_lua.fs_utils.findFile("samples") .. "/testdata"

local MODEL_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/bert_classifier.tflite"
local MODEL_URL = "https://storage.googleapis.com/mediapipe-models/text_classifier/bert_classifier/float32/1/bert_classifier.tflite"
local MODEL_HASH = "sha256=9b45012ab143d88d61e10ea501d6c8763f7202b86fa987711519d89bfa2a88b1"
download_utils.download(mediapipe_lua.kwargs({
    output = MODEL_FILE,
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

### Text Embedding with MediaPipe Tasks

```lua
--[[
Sources:
    https://colab.research.google.com/github/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/text_embedder/python/text_embedder.ipynb
    https://github.com/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/text_embedder/python/text_embedder.ipynb

Title: Text Embedding with MediaPipe Tasks
--]]

local INDEX_BASE = 1 -- lua is 1-based indexed

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe

local download_utils = mediapipe.lua.solutions.download_utils

local MEDIAPIPE_SAMPLES_DATA_PATH = mediapipe_lua.fs_utils.findFile("samples") .. "/testdata"

local MODEL_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/bert_embedder.tflite"
local MODEL_URL = "https://storage.googleapis.com/mediapipe-models/text_embedder/bert_embedder/float32/1/bert_embedder.tflite"
local MODEL_HASH = "sha256=02ae6279faf86c2cd4ff18f61876c878bcc0b572b472f0678897a184c4ac7ef6"
download_utils.download(mediapipe_lua.kwargs({
    output = MODEL_FILE,
    url = MODEL_URL,
    hash = MODEL_HASH,
}))

local lua = mediapipe.tasks.lua
local text = mediapipe.tasks.lua.text

-- Create your base options with the model that was downloaded earlier
local base_options = lua.BaseOptions(mediapipe_lua.kwargs({ model_asset_path = MODEL_FILE }))

-- Set your values for using normalization and quantization
local l2_normalize = true --@param {type:"boolean"}
local quantize = false    --@param {type:"boolean"}

-- Create the final set of options for the Embedder
local options = text.TextEmbedderOptions(mediapipe_lua.kwargs({
    base_options = base_options, l2_normalize = l2_normalize, quantize = quantize }))

local embedder = text.TextEmbedder.create_from_options(options)

-- Retrieve the first and second sets of text that will be compared
local first_text = "I'm feeling so good" --@param {type:"string"}
local second_text = "I'm okay I guess"   --@param {type:"string"}

-- Convert both sets of text to embeddings
local first_embedding_result = embedder:embed(first_text)
local second_embedding_result = embedder:embed(second_text)

-- Calculate and print similarity
local similarity = text.TextEmbedder.cosine_similarity(
    first_embedding_result.embeddings[0 + INDEX_BASE],
    second_embedding_result.embeddings[0 + INDEX_BASE])
print("similarity = " .. similarity)

```

<!-- EXAMPLES_END generated examples please keep comment here to allow auto update -->

## Running examples

All the examples in the samples directory can be run by folling theses instructions.

### Prerequisites to run examples

#### Windows

  - Install [Git](https://git-scm.com/)
  - Install [NodeJS](https://nodejs.org/en/download/current)
  - Install [Visual Studio 2022 >= 17.13.0 with '.NET desktop development' and 'Desktop development with C++'](https://visualstudio.microsoft.com/fr/downloads/)
  - In your windows search, search and open the `x64 Native Tools Command Prompt for VS 2022`

#### Linux

  - Install [NodeJS](https://nodejs.org/en/download/current)
  - Install [CMake >= 3.25](https://cmake.org/download/)
  - Install [Ninja](https://ninja-build.org/)
  - Install needed packages:
    - Debian, Ubuntu: `sudo apt install -y curl g++ gcc git libgl1 libglib2.0-0 libreadline-dev libsm6 libxext6 make python3-pip python3-venv unzip wget`
    - Fedora, Almalinux 9: `sudo dnf install -y curl gcc gcc-c++ git glib2 readline-devel libglvnd-glx libSM libXext make patch python3-pip unzip wget`
    - Almalinux 8: `sudo dnf install -y curl gcc gcc-c++ git glib2 readline-devel libglvnd-glx libSM libXext make patch python3.12-pip unzip wget`

### Initialize the project

#### Windows

```cmd
git clone --depth 1 --branch v0.1.0 https://github.com/smbape/lua-mediapipe.git
cd lua-mediapipe
@REM build.bat "-DLua_VERSION=luajit-2.1" --target luajit --install
@REM available versions are 5.1, 5.2, 5.3, 5.4
build.bat "-DLua_VERSION=5.4" --target lua --install
build.bat "-DLua_VERSION=5.4" --target luarocks
@REM luarocks\luarocks.bat install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 mediapipe_lua 0.10.24luajit2.1
luarocks\luarocks.bat install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 mediapipe_lua
luarocks\luarocks.bat install --deps-only samples\samples-scm-1.rockspec
npm ci
node scripts\test.js --Release
```

#### Linux

```sh
git clone --depth 1 --branch v0.1.0 https://github.com/smbape/lua-mediapipe.git
cd lua-mediapipe
# ./build.sh "-DLua_VERSION=luajit-2.1" --target luajit --install
# available versions are 5.1, 5.2, 5.3, 5.4
./build.sh "-DLua_VERSION=5.4" --target lua --install
./build.sh "-DLua_VERSION=5.4" --target luarocks
# ./luarocks/luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 mediapipe_lua 0.10.24luajit2.1
./luarocks/luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 mediapipe_lua
./luarocks/luarocks install --deps-only samples/samples-scm-1.rockspec
npm ci
node scripts/test.js --Release
```

## Hosting you own binary rocks

If the provided binray rocks are not suitable for your environnment, you can install the source rock.  
However, installing the source rock takes a long time (01h00mn on my computer).  
Therefore, it is not practical to repeat that process again.  
To avoid that long install time, you can host your own prebuilt binary rocks on a private server.

Windows: [Hosting you own binary rocks on Windows](docs/hosting-you-own-binary-rocks-Windows.md)

Linux: [Hosting you own binary rocks on Linux](docs/hosting-you-own-binary-rocks-Linux.md)

## Keyword arguments

Similar to python [keyword arguments](https://docs.python.org/3/glossary.html#term-argument) or c# [Named parameters](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/classes-and-structs/named-and-optional-arguments#named-arguments), keyword arguments free you from matching the order of arguments to the order of parameters in the parameter lists of called methods.

When a function has multiple default parameters, keyword arguments allow you to override only the needed parameters without specifying the previous default parameters.

As an example, given the documentation of mediapipe.lua.solutions.drawing_utils.draw_landmarks

```cpp
absl::Status mediapipe::lua::solutions::drawing_utils::draw_landmarks( cv::Mat&                                                                      image,
                                                                       const mediapipe::NormalizedLandmarkList&                                      landmark_list,
                                                                       const std::vector<std::tuple<int, int>>&                                      connections = std::vector<std::tuple<int, int>>(),
                                                                       const std::shared_ptr<mediapipe::lua::solutions::drawing_utils::DrawingSpec>& landmark_drawing_spec = std::make_shared<DrawingSpec>(RED_COLOR),
                                                                       const mediapipe::lua::solutions::drawing_utils::DrawingSpec&                  connection_drawing_spec = DrawingSpec(),
                                                                       const bool                                                                    is_drawing_landmarks = true );
lua:
    mediapipe.lua.solutions.drawing_utils.draw_landmarks( image, landmark_list[, connections[, landmark_drawing_spec[, connection_drawing_spec[, is_drawing_landmarks]]]] ) -> retval
```

the following expressions are equivalent:

```lua
mediapipe.lua.solutions.drawing_utils.draw_landmarks(image, landmark_list, connections, landmark_drawing_spec, connection_drawing_spec, is_drawing_landmarks)
mediapipe.lua.solutions.drawing_utils.draw_landmarks(image, landmark_list, connections, landmark_drawing_spec, connection_drawing_spec, mediapipe_lua.kwargs({ is_drawing_landmarks = is_drawing_landmarks }))
mediapipe.lua.solutions.drawing_utils.draw_landmarks(image, landmark_list, connections, landmark_drawing_spec, mediapipe_lua.kwargs({ connection_drawing_spec = connection_drawing_spec, is_drawing_landmarks = is_drawing_landmarks }))
mediapipe.lua.solutions.drawing_utils.draw_landmarks(image, landmark_list, connections, mediapipe_lua.kwargs({ landmark_drawing_spec = landmark_drawing_spec, connection_drawing_spec = connection_drawing_spec, is_drawing_landmarks = is_drawing_landmarks }))
mediapipe.lua.solutions.drawing_utils.draw_landmarks(image, landmark_list, mediapipe_lua.kwargs({ connections = connections, landmark_drawing_spec = landmark_drawing_spec, connection_drawing_spec = connection_drawing_spec, is_drawing_landmarks = is_drawing_landmarks }))
mediapipe.lua.solutions.drawing_utils.draw_landmarks(image, mediapipe_lua.kwargs({ landmark_list = landmark_list, connections = connections, landmark_drawing_spec = landmark_drawing_spec, connection_drawing_spec = connection_drawing_spec, is_drawing_landmarks = is_drawing_landmarks }))
mediapipe.lua.solutions.drawing_utils.draw_landmarks(mediapipe_lua.kwargs({ image = image, landmark_list = landmark_list, connections = connections, landmark_drawing_spec = landmark_drawing_spec, connection_drawing_spec = connection_drawing_spec, is_drawing_landmarks = is_drawing_landmarks }))
```

Of course, optional parameters are not mandatory. In other words, if you only want to change the `is_drawing_landmarks` parameter, you can do

```lua
mediapipe.lua.solutions.drawing_utils.draw_landmarks(image, landmark_list, mediapipe_lua.kwargs({ is_drawing_landmarks = false }))
```

## How to translate python code

The transformation will usually be straight from python.

`tuples` and `arrays` become `tables`.

`numpy` calls and `arrays` manipulations have their `cv.Mat` counter parts.

`keyword arguments` will be wrapped within `mediapipe_lua.kwargs`.

### Python translation example

```python
# Define the input text that you wants the model to classify.
INPUT_TEXT = "I'm looking forward to what will come next."

# STEP 1: Import the necessary modules.
from mediapipe.tasks import python
from mediapipe.tasks.python import text

# STEP 2: Create an TextClassifier object.
base_options = python.BaseOptions(model_asset_path="classifier.tflite")
options = text.TextClassifierOptions(base_options=base_options)
classifier = text.TextClassifier.create_from_options(options)

# STEP 3: Classify the input text.
classification_result = classifier.classify(INPUT_TEXT)

# STEP 4: Process the classification result. In this case, print out the most likely category.
top_category = classification_result.classifications[0].categories[0]
print(f'{top_category.category_name} ({top_category.score:.2f})')
```

```lua
local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe

-- Define the input text that you wants the model to classify.
local INPUT_TEXT = "I'm looking forward to what will come next."

-- STEP 1: Import the necessary modules.
local lua = mediapipe.tasks.lua
local text = mediapipe.tasks.lua.text

-- STEP 2: Create an TextClassifier object.
local base_options = lua.BaseOptions(mediapipe_lua.kwargs({ model_asset_path = "classifier.tflite" }))
local options = text.TextClassifierOptions(mediapipe_lua.kwargs({ base_options = base_options }))
local classifier = text.TextClassifier.create_from_options(options)

-- STEP 3: Classify the input text.
local classification_result = classifier:classify(INPUT_TEXT)

-- STEP 4: Process the classification result. In this case, print out the most likely category.
local top_category = classification_result.classifications[1].categories[1]
print(("%s: (%.2f)"):format(top_category.category_name, top_category.score))
```

## Lua Gotchas

### 1-indexed

Arrays are 1-indexed in `lua`, and 0-indexed in python. Therefore, if you see in python `p[0]`, you should write in lua `p[1]`

For example, in python

```python
top_category = classification_result.classifications[0].categories[0]
```

In lua

```lua
top_category = classification_result.classifications[1].categories[1]
```

### Instance method calls

Instance methods are called with `:` not `.`.

If you see in python

```python
classifier = text.TextClassifier.create_from_options(options)
classification_result = classifier.classify(INPUT_TEXT)
```

You should write in lua

```lua
classifier = text.TextClassifier.create_from_options(options)
classification_result = classifier:classify(INPUT_TEXT)
```
