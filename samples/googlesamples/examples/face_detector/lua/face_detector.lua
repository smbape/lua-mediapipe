#!/usr/bin/env lua

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
