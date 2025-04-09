#!/usr/bin/env lua

--[[
Sources:
    https://colab.research.google.com/github/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/pose_landmarker/python/%5BMediaPipe_Python_Tasks%5D_Pose_Landmarker.ipynb
    https://github.com/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/pose_landmarker/python/%5BMediaPipe_Python_Tasks%5D_Pose_Landmarker.ipynb

Title: Pose Landmarks Detection with MediaPipe Tasks
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

local function download_test_files(test_files)
    for _, kwargs in ipairs(test_files) do
        download_utils.download(mediapipe_lua.kwargs(kwargs))
    end
end

local MEDIAPIPE_SAMPLES_DATA_PATH = mediapipe_lua.fs_utils.findFile("samples") .. "/testdata"

local IMAGE_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/girl-4051811_960_720.jpg"
local IMAGE_URL = "https://cdn.pixabay.com/photo/2019/03/12/20/39/girl-4051811_960_720.jpg"
local IMAGE_HASH = "sha256=99e0649aa4f2553b0213982f544146565a1028877c4bb9fbe3884453659d8cdc"
local MODEL_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/pose_landmarker_heavy.task"
local MODEL_URL = "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_heavy/float16/1/pose_landmarker_heavy.task"
local MODEL_HASH = "sha256=64437af838a65d18e5ba7a0d39b465540069bc8aae8308de3e318aad31fcbc7b"

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

local solutions = mediapipe.solutions
local landmark_pb2 = mediapipe.framework.formats.landmark_pb2

local function draw_landmarks_on_image(rgb_image, detection_result)
    local scale = 1 / resize_and_show(rgb_image, nil, false)
    local pose_landmarks_list = detection_result.pose_landmarks
    local annotated_image = rgb_image:copy()

    -- Loop through the detected poses to visualize.
    for idx = 1, #pose_landmarks_list do
        local pose_landmarks = pose_landmarks_list[idx]

        -- Draw the pose landmarks.
        local pose_landmarks_proto = landmark_pb2.NormalizedLandmarkList()
        for _, landmark in ipairs(pose_landmarks) do
            pose_landmarks_proto.landmark:append(
                landmark_pb2.NormalizedLandmark(mediapipe_lua.kwargs({ x = landmark.x, y = landmark.y, z = landmark.z }))
            )
        end

        solutions.drawing_utils.draw_landmarks(
            annotated_image,
            pose_landmarks_proto,
            solutions.pose.POSE_CONNECTIONS,
            solutions.drawing_styles.get_default_pose_landmarks_style(scale))
    end
    return annotated_image
end

-- STEP 1: Import the necessary modules.
local mp = mediapipe
local lua = mediapipe.tasks.lua
local vision = mediapipe.tasks.lua.vision

-- STEP 2: Create an PoseLandmarker object.
local base_options = lua.BaseOptions(mediapipe_lua.kwargs({ model_asset_path = MODEL_FILE }))
local options = vision.PoseLandmarkerOptions(mediapipe_lua.kwargs({
    base_options = base_options,
    output_segmentation_masks = true
}))
local detector = vision.PoseLandmarker.create_from_options(options)

-- STEP 3: Load the input image.
local image = mp.Image.create_from_file(IMAGE_FILE)

-- STEP 4: Detect pose landmarks from the input image.
local detection_result = detector:detect(image)

-- STEP 5: Process the detection result. In this case, visualize it.
local annotated_image = draw_landmarks_on_image(image:mat_view(), detection_result)

-- Display the image
resize_and_show(cv2.cvtColor(annotated_image, cv2.COLOR_RGB2BGR), "Pose Landmarks Detection with MediaPipe Tasks : Image")

-- Visualize the pose segmentation mask.
local segmentation_mask = detection_result.segmentation_masks[0 + INDEX_BASE]:mat_view()
local visualized_mask = segmentation_mask:convertTo(cv2.CV_8U, opencv_lua.kwargs({ alpha = 255 }))
resize_and_show(visualized_mask, "Pose Landmarks Detection with MediaPipe Tasks : Mask")

cv2.waitKey()
