#!/usr/bin/env lua

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
    { file = "burger.jpg", hash = "sha256=08151ebb48f30a6cfbea02168ec0f3c0f1694d64c8d0f75ca08a63a89302853f" },
    { file = "cat.jpg",    hash = "sha256=a83aa74a3d1d9bbc8bf92065e6e4d1ba217438a9f4a95f35287b2e8316e83859" },
}

local IMAGE_FILENAMES = {}
for i, kwargs in ipairs(IMAGE_DOWNLOADS) do
    kwargs.url = "https://storage.googleapis.com/mediapipe-tasks/image_classifier/" .. kwargs.file
    kwargs.file = MEDIAPIPE_SAMPLES_DATA_PATH .. "/" .. kwargs.file
    download_utils.download(mediapipe_lua.kwargs(kwargs))
    IMAGE_FILENAMES[i] = kwargs.file
end

local MODEL_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/efficientnet_lite0.tflite"
local MODEL_URL = "https://storage.googleapis.com/mediapipe-models/image_classifier/efficientnet_lite0/float32/1/efficientnet_lite0.tflite"
local MODEL_HASH = "sha256=6c7ab0a6e5dcbf38a8c33b960996a55a3b4300b36a018c4545801de3a3c8bde0"
download_utils.download(mediapipe_lua.kwargs({
    file = MODEL_FILE,
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
