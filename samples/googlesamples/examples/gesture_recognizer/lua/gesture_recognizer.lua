#!/usr/bin/env lua

--[[
Sources:
    https://colab.research.google.com/github/google-ai-edge/mediapipe-samples/blob/88792a956f9996c728b92d19ef7fac99cef8a4fe/examples/gesture_recognizer/python/gesture_recognizer.ipynb
    https://github.com/google-ai-edge/mediapipe-samples/blob/88792a956f9996c728b92d19ef7fac99cef8a4fe/examples/gesture_recognizer/python/gesture_recognizer.ipynb

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
    { file = "thumbs_down.jpg", hash = "sha256=080b589bf3b91ba10cc6c03645be3b5b491a8ca8c8f7d65b5f32c563ae266af9" },
    { file = "victory.jpg",     hash = "sha256=6ac265f3ace6a6c4ac4a9079b63fcce4ab6517272afb1e430857f55ef324fde6" },
    { file = "thumbs_up.jpg",   hash = "sha256=2aee0e3a69ba5f0d3287597e61d265f4f3ac2a44ccec198dddd2639b0c8ef7ba" },
    { file = "pointing_up.jpg", hash = "sha256=f4a701316b63dd8fa56e622f2b3042766369ccc189f0d89513f803cd985b993b" },
}

local IMAGE_FILENAMES = {}
for i, kwargs in ipairs(IMAGE_DOWNLOADS) do
    kwargs.url = "https://storage.googleapis.com/mediapipe-tasks/gesture_recognizer/" .. kwargs.file
    kwargs.file = MEDIAPIPE_SAMPLES_DATA_PATH .. "/" .. kwargs.file
    download_utils.download(mediapipe_lua.kwargs(kwargs))
    IMAGE_FILENAMES[i] = kwargs.file
end

local MODEL_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/gesture_recognizer.task"
local MODEL_URL = "https://storage.googleapis.com/mediapipe-models/gesture_recognizer/gesture_recognizer/float16/1/gesture_recognizer.task"
local MODEL_HASH = "sha256=97952348cf6a6a4915c2ea1496b4b37ebabc50cbbf80571435643c455f2b0482"
download_utils.download(mediapipe_lua.kwargs({
    file = MODEL_FILE,
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
