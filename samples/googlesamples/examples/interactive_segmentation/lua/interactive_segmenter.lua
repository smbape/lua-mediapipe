#!/usr/bin/env lua

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
