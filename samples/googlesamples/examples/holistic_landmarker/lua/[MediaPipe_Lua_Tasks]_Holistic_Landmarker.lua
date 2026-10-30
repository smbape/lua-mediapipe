#!/usr/bin/env lua

--[[
Sources:
    https://colab.research.google.com/github/google-ai-edge/mediapipe-samples/blob/7f3cf17410db91f8e084a46f7517df15bce3479a/examples/holistic_landmarker/python/[MediaPipe_Python_Tasks]_Holistic_Landmarker.ipynb
    https://github.com/google-ai-edge/mediapipe-samples/blob/7f3cf17410db91f8e084a46f7517df15bce3479a/examples/holistic_landmarker/python/[MediaPipe_Python_Tasks]_Holistic_Landmarker.ipynb

Title: Holistic Landmarks Detection with MediaPipe Tasks
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

local download_utils = mediapipe.tasks.lua.core.download_utils

local function download_test_files(test_files)
    for _, kwargs in ipairs(test_files) do
        download_utils.download(mediapipe_lua.kwargs(kwargs))
    end
end

local MEDIAPIPE_SAMPLES_DATA_PATH = mediapipe_lua.fs_utils.findFile("samples") .. "/testdata"

local IMAGE_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/business-person.png"
local IMAGE_URL = "https://storage.googleapis.com/mediapipe-tasks/holistic_landmarker/business-person.png"
local IMAGE_HASH = "sha256=1f61cf0603cef77ffca4e24848ddf8290b5651d03b957e93b742c9ef963b5c11"
local MODEL_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/holistic_landmarker.task"
local MODEL_URL = "https://storage.googleapis.com/mediapipe-models/holistic_landmarker/holistic_landmarker/float16/1/holistic_landmarker.task"
local MODEL_HASH = "sha256=e2dab61191e2dcd0a15f943d8e3ed1dce13c82dfa597b9dd39f562975a50c3f8"

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

local vision = mediapipe.tasks.lua.vision
local drawing_utils = mediapipe.tasks.lua.vision.drawing_utils
local drawing_styles = mediapipe.tasks.lua.vision.drawing_styles

local function draw_landmarks_on_image(rgb_image, detection_result)
    -- Compute the scale to make drawn elements visible when the image is resized for display
    local scale = 1 / resize_and_show(rgb_image, nil, false)

    local pose_landmarks = detection_result.pose_landmarks
    local face_landmarks = detection_result.face_landmarks
    local left_hand_landmarks = detection_result.left_hand_landmarks
    local right_hand_landmarks = detection_result.right_hand_landmarks
    local annotated_image = cv2.cvtColor(rgb_image, cv2.COLOR_RGB2BGR)

    -- Draw pose landmarks.
    if #pose_landmarks ~= 0 then
        local pose_landmark_style = drawing_styles.get_default_pose_landmarks_style(mediapipe_lua.kwargs({ scale = scale }))
        local pose_connection_style = drawing_utils.DrawingSpec(mediapipe_lua.kwargs({ color = { 0, 255, 0 }, thickness = 2 * scale }))
        drawing_utils.draw_landmarks(mediapipe_lua.kwargs({
            image = annotated_image,
            landmark_list = pose_landmarks,
            connections = vision.PoseLandmarksConnections.POSE_LANDMARKS,
            landmark_drawing_spec = pose_landmark_style,
            connection_drawing_spec = pose_connection_style
        }))
    end

    -- Draw face landmarks.
    if #face_landmarks ~= 0 then
        drawing_utils.draw_landmarks(mediapipe_lua.kwargs({
            image = annotated_image,
            landmark_list = face_landmarks,
            connections = vision.FaceLandmarksConnections.FACE_LANDMARKS_TESSELATION,
            landmark_drawing_spec = {},
            connection_drawing_spec = drawing_styles.get_default_face_mesh_tesselation_style(mediapipe_lua.kwargs({ scale = scale }))
        }))
        drawing_utils.draw_landmarks(mediapipe_lua.kwargs({
            image = annotated_image,
            landmark_list = face_landmarks,
            connections = vision.FaceLandmarksConnections.FACE_LANDMARKS_CONTOURS,
            landmark_drawing_spec = {},
            connection_drawing_spec = drawing_styles.get_default_face_mesh_contours_style(mediapipe_lua.kwargs({ scale = scale }))
        }))
        drawing_utils.draw_landmarks(mediapipe_lua.kwargs({
            image = annotated_image,
            landmark_list = face_landmarks,
            connections = vision.FaceLandmarksConnections.FACE_LANDMARKS_LEFT_IRIS,
            landmark_drawing_spec = {},
            connection_drawing_spec = drawing_styles.get_default_face_mesh_iris_connections_style(mediapipe_lua.kwargs({ scale = scale }))
        }))
        drawing_utils.draw_landmarks(mediapipe_lua.kwargs({
            image = annotated_image,
            landmark_list = face_landmarks,
            connections = vision.FaceLandmarksConnections.FACE_LANDMARKS_RIGHT_IRIS,
            landmark_drawing_spec = {},
            connection_drawing_spec = drawing_styles.get_default_face_mesh_iris_connections_style(mediapipe_lua.kwargs({ scale = scale }))
        }))
    end

    -- Draw hand landmarks.
    if #left_hand_landmarks ~= 0 then
        drawing_utils.draw_landmarks(mediapipe_lua.kwargs({
            image = annotated_image,
            landmark_list = left_hand_landmarks,
            connections = vision.HandLandmarksConnections.HAND_CONNECTIONS,
            landmark_drawing_spec = drawing_styles.get_default_hand_landmarks_style(mediapipe_lua.kwargs({ scale = scale })),
            connection_drawing_spec = drawing_styles.get_default_hand_connections_style(mediapipe_lua.kwargs({ scale = scale }))
        }))
    end

    if #right_hand_landmarks ~= 0 then
        drawing_utils.draw_landmarks(mediapipe_lua.kwargs({
            image = annotated_image,
            landmark_list = right_hand_landmarks,
            connections = vision.HandLandmarksConnections.HAND_CONNECTIONS,
            landmark_drawing_spec = drawing_styles.get_default_hand_landmarks_style(mediapipe_lua.kwargs({ scale = scale })),
            connection_drawing_spec = drawing_styles.get_default_hand_connections_style(mediapipe_lua.kwargs({ scale = scale }))
        }))
    end

    return annotated_image
end

-- STEP 1: Import the necessary modules.
local mp = mediapipe
local lua = mediapipe.tasks.lua
local vision = mediapipe.tasks.lua.vision

-- STEP 2: Create a HolisticLandmarker object.
local base_options = lua.BaseOptions(mediapipe_lua.kwargs({ model_asset_path = MODEL_FILE }))
local options = vision.HolisticLandmarkerOptions(mediapipe_lua.kwargs({
    base_options = base_options,
    output_face_blendshapes = true,
    output_segmentation_mask = true
}))
local detector = vision.HolisticLandmarker.create_from_options(options)

-- STEP 3: Load the input image.
local image = mp.Image.create_from_file(IMAGE_FILE)

-- STEP 4: Detect holistic landmarks from the input image.
local detection_result = detector:detect(image)

-- STEP 5: Process the detection result. In this case, visualize it.
local annotated_image = draw_landmarks_on_image(image:mat_view(), detection_result)
resize_and_show(annotated_image, "holistic_landmarker")
cv2.waitKey()
