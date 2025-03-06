#!/usr/bin/env lua

--[[
Sources:
    https://colab.research.google.com/github/google-ai-edge/mediapipe-samples/blob/88792a956f9996c728b92d19ef7fac99cef8a4fe/examples/hand_landmarker/python/hand_landmarker.ipynb
    https://github.com/google-ai-edge/mediapipe-samples/blob/88792a956f9996c728b92d19ef7fac99cef8a4fe/examples/hand_landmarker/python/hand_landmarker.ipynb

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
