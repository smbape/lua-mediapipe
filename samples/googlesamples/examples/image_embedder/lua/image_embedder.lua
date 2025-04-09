#!/usr/bin/env lua

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
