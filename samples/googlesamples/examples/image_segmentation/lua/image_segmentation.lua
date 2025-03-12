#!/usr/bin/env lua

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
    { file = "segmentation_input_rotation0.jpg", hash = "sha256=5bf58d8af1f1c33224f3f3bc0ce451c8daf0739cc15a86d59d8c3bf2879afb97" },
}

local IMAGE_FILENAMES = {}
for i, kwargs in ipairs(IMAGE_DOWNLOADS) do
    kwargs.url = "https://storage.googleapis.com/mediapipe-assets/" .. kwargs.file
    kwargs.file = MEDIAPIPE_SAMPLES_DATA_PATH .. "/" .. kwargs.file
    download_utils.download(mediapipe_lua.kwargs(kwargs))
    IMAGE_FILENAMES[i] = kwargs.file
end

local MODEL_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/deeplab_v3.tflite"
local MODEL_URL = "https://storage.googleapis.com/mediapipe-models/image_segmenter/deeplab_v3/float32/1/deeplab_v3.tflite"
local MODEL_HASH = "sha256=ff36e24d40547fe9e645e2f4e8745d1876d6e38b332d39a82f0bf0f5d1d561b3"
download_utils.download(mediapipe_lua.kwargs({
    file = MODEL_FILE,
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
