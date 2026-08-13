#!/usr/bin/env lua

--[[
Sources:
    https://colab.research.google.com/github/google-ai-edge/mediapipe-samples/blob/3d23f0e459907af064c3e7494dbb180851e1694c/examples/face_landmarker/python/%5BMediaPipe_Python_Tasks%5D_Face_Landmarker.ipynb
    https://github.com/google-ai-edge/mediapipe-samples/blob/3d23f0e459907af064c3e7494dbb180851e1694c/examples/face_landmarker/python/%5BMediaPipe_Python_Tasks%5D_Face_Landmarker.ipynb

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

local download_utils = mediapipe.tasks.lua.core.download_utils

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

    local face_landmarks_list = detection_result.face_landmarks
    local annotated_image = cv2.cvtColor(rgb_image, cv2.COLOR_RGB2BGR)

    -- Loop through the detected faces to visualize.
    for _, face_landmarks in ipairs(face_landmarks_list) do
        -- Draw the face landmarks.


        drawing_utils.draw_landmarks(mediapipe_lua.kwargs({
            image = annotated_image,
            landmark_list = face_landmarks,
            connections = vision.FaceLandmarksConnections.FACE_LANDMARKS_TESSELATION,
            landmark_drawing_spec = {},
            connection_drawing_spec = drawing_styles.get_default_face_mesh_tesselation_style(scale)
        }))
        drawing_utils.draw_landmarks(mediapipe_lua.kwargs({
            image = annotated_image,
            landmark_list = face_landmarks,
            connections = vision.FaceLandmarksConnections.FACE_LANDMARKS_CONTOURS,
            landmark_drawing_spec = {},
            connection_drawing_spec = drawing_styles.get_default_face_mesh_contours_style(mediapipe_lua.kwargs({ style = 1, scale = scale }))
        }))
        drawing_utils.draw_landmarks(mediapipe_lua.kwargs({
            image = annotated_image,
            landmark_list = face_landmarks,
            connections = vision.FaceLandmarksConnections.FACE_LANDMARKS_LEFT_IRIS,
            landmark_drawing_spec = {},
            connection_drawing_spec = drawing_styles.get_default_face_mesh_iris_connections_style(scale)
        }))
        drawing_utils.draw_landmarks(mediapipe_lua.kwargs({
            image = annotated_image,
            landmark_list = face_landmarks,
            connections = vision.FaceLandmarksConnections.FACE_LANDMARKS_RIGHT_IRIS,
            landmark_drawing_spec = {},
            connection_drawing_spec = drawing_styles.get_default_face_mesh_iris_connections_style(scale)
        }))
    end

    return annotated_image
end


-- STEP 1: Import the necessary modules.
local mp = mediapipe
local lua = mediapipe.tasks.lua
local vision = mediapipe.tasks.lua.vision

-- STEP 2: Create a FaceLandmarker object.
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
local annotated_image = draw_landmarks_on_image(image:mat_view(), detection_result)
resize_and_show(annotated_image, "face_landmarker")
cv2.waitKey()
