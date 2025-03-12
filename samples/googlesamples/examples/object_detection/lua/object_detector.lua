#!/usr/bin/env lua

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
