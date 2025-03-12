#!/usr/bin/env lua

--[[
Sources:
    https://colab.research.google.com/github/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/face_landmarker/python/%5BMediaPipe_Python_Tasks%5D_Face_Landmarker.ipynb
    https://github.com/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/face_landmarker/python/%5BMediaPipe_Python_Tasks%5D_Face_Landmarker.ipynb

Title: Face Landmarks Detection with MediaPipe Tasks
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

local function download_test_files(test_files)
    for _, kwargs in ipairs(test_files) do
        download_utils.download(mediapipe_lua.kwargs(kwargs))
    end
end

local MEDIAPIPE_SAMPLES_DATA_PATH = mediapipe_lua.fs_utils.findFile("samples") .. "/testdata"

local IMAGE_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/business-person.png"
local IMAGE_URL = "https://storage.googleapis.com/mediapipe-assets/business-person.png"
local IMAGE_HASH = "sha256=1f61cf0603cef77ffca4e24848ddf8290b5651d03b957e93b742c9ef963b5c11"
local MODEL_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/face_landmarker.task"
local MODEL_URL = "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task"
local MODEL_HASH = "sha256=64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff"

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

    local face_landmarks_list = detection_result.face_landmarks
    local annotated_image = rgb_image:copy()

    -- Loop through the detected faces to visualize.
    for idx = 1, #face_landmarks_list do
        local face_landmarks = face_landmarks_list[idx]

        -- Draw the face landmarks.
        local face_landmarks_proto = landmark_pb2.NormalizedLandmarkList()
        for _, landmark in ipairs(face_landmarks) do
            face_landmarks_proto.landmark:append(
                landmark_pb2.NormalizedLandmark(mediapipe_lua.kwargs({ x = landmark.x, y = landmark.y, z = landmark.z }))
            )
        end

        solutions.drawing_utils.draw_landmarks(mediapipe_lua.kwargs({
            image = annotated_image,
            landmark_list = face_landmarks_proto,
            connections = solutions.face_mesh.FACEMESH_TESSELATION,
            landmark_drawing_spec = {},
            connection_drawing_spec = solutions.drawing_styles
                    .get_default_face_mesh_tesselation_style(scale)
        }))
        solutions.drawing_utils.draw_landmarks(mediapipe_lua.kwargs({
            image = annotated_image,
            landmark_list = face_landmarks_proto,
            connections = solutions.face_mesh.FACEMESH_CONTOURS,
            landmark_drawing_spec = {},
            connection_drawing_spec = solutions.drawing_styles
                    .get_default_face_mesh_contours_style(mediapipe_lua.kwargs({ style = 1, scale = scale }))
        }))
        solutions.drawing_utils.draw_landmarks(mediapipe_lua.kwargs({
            image = annotated_image,
            landmark_list = face_landmarks_proto,
            connections = solutions.face_mesh.FACEMESH_IRISES,
            landmark_drawing_spec = {},
            connection_drawing_spec = solutions.drawing_styles
                    .get_default_face_mesh_iris_connections_style(scale)
        }))
    end

    return annotated_image
end


-- STEP 1: Import the necessary modules.
local mp = mediapipe
local lua = mediapipe.tasks.lua
local vision = mediapipe.tasks.lua.vision

-- STEP 2: Create an FaceLandmarker object.
local base_options = lua.BaseOptions(mediapipe_lua.kwargs({ model_asset_path = MODEL_FILE }))
local options = vision.FaceLandmarkerOptions(mediapipe_lua.kwargs({
    base_options = base_options,
    output_face_blendshapes = true,
    output_facial_transformation_matrixes = true,
    num_faces = 1
}))
local detector = vision.FaceLandmarker.create_from_options(options)

-- STEP 3: Load the input image.
local image = mp.Image.create_from_file(IMAGE_FILE)

-- STEP 4: Detect face landmarks from the input image.
local detection_result = detector:detect(image)

-- STEP 5: Process the detection result. In this case, visualize it.
local annotated_image = draw_landmarks_on_image(cv2.cvtColor(image:mat_view(), cv2.COLOR_RGB2BGR), detection_result)
resize_and_show(annotated_image, "face_landmarker")
cv2.waitKey()
