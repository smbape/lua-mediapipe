#!/usr/bin/env lua

--[[
Sources:
    https://colab.research.google.com/github/google-ai-edge/mediapipe-samples/blob/88792a956f9996c728b92d19ef7fac99cef8a4fe/examples/face_stylizer/python/face_stylizer.ipynb
    https://github.com/google-ai-edge/mediapipe-samples/blob/88792a956f9996c728b92d19ef7fac99cef8a4fe/examples/face_stylizer/python/face_stylizer.ipynb

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
        file = IMAGE_FILE,
        url = IMAGE_URL,
        hash = IMAGE_HASH,
    },
    {
        file = MODEL_FILE,
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
