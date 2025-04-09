#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/tasks/python/test/vision/face_landmarker_test.py
--]]

local unpack = table.unpack or unpack ---@diagnostic disable-line: deprecated

local _assert = require("_assert")
local _mat_utils = require("_mat_utils") ---@diagnostic disable-line: unused-local
local test_utils = require("test_utils")

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe
local google = mediapipe_lua.google
local std = mediapipe_lua.std

local text_format = google.protobuf.text_format
local landmark_pb2 = mediapipe.framework.formats.landmark_pb2
local image_module = mediapipe.lua._framework_bindings.image
local landmark_module = mediapipe.tasks.lua.components.containers.landmark
local base_options_module = mediapipe.tasks.lua.core.base_options
local face_landmarker = mediapipe.tasks.lua.vision.face_landmarker
local running_mode_module = mediapipe.tasks.lua.vision.core.vision_task_running_mode

local _BaseOptions = base_options_module.BaseOptions
local _NormalizedLandmark = landmark_module.NormalizedLandmark
local _Image = image_module.Image
local _FaceLandmarker = face_landmarker.FaceLandmarker
local _FaceLandmarkerOptions = face_landmarker.FaceLandmarkerOptions
local _RUNNING_MODE = running_mode_module.VisionTaskRunningMode

local _FACE_LANDMARKER_BUNDLE_ASSET_FILE = 'face_landmarker_v2.task'
local _PORTRAIT_IMAGE = 'portrait.jpg'
local _CAT_IMAGE = 'cat.jpg'
local _PORTRAIT_EXPECTED_FACE_LANDMARKS = 'portrait_expected_face_landmarks.pbtxt'
local _PORTRAIT_EXPECTED_BLENDSHAPES = 'portrait_expected_blendshapes.pbtxt'
local _LANDMARKS_MARGIN = 0.03
local _BLENDSHAPES_MARGIN = 0.13
local _FACIAL_TRANSFORMATION_MATRIX_MARGIN = 0.02

local _TEST_DATA_DIR = test_utils.get_resource_dir() .. '/mediapipe/tasks/testdata/vision'


---@param file_path string
---@return NormalizedLandmark[]
local function _get_expected_face_landmarks(file_path)
    local proto_file_path = test_utils.get_test_data_path(file_path)
    local face_landmarks_results = {}
    local f = io.open(proto_file_path, 'rb')
    local proto = landmark_pb2.NormalizedLandmarkList()
    text_format.Parse(f:read('*all'), proto)
    local face_landmarks = {}
    for _, landmark in ipairs(proto.landmark:table()) do
        face_landmarks[#face_landmarks + 1] = _NormalizedLandmark.create_from_pb2(landmark)
    end
    face_landmarks_results[#face_landmarks_results + 1] = face_landmarks
    return face_landmarks_results
end

local ModelFileType = {
    FILE_CONTENT = 1,
    FILE_NAME = 2,
}

local function setUp(self)
    test_utils.download_test_files(_TEST_DATA_DIR, {
        _FACE_LANDMARKER_BUNDLE_ASSET_FILE,
        _PORTRAIT_IMAGE,
        _CAT_IMAGE,
        _PORTRAIT_EXPECTED_FACE_LANDMARKS,
        _PORTRAIT_EXPECTED_BLENDSHAPES,
    })

    self.test_image = _Image.create_from_file(test_utils.get_test_data_path(_PORTRAIT_IMAGE))
    self.model_path = test_utils.get_test_data_path(_FACE_LANDMARKER_BUNDLE_ASSET_FILE)
end

function _assert._expect_landmarks_correct(self, actual_landmarks, expected_landmarks)
    -- Expects to have the same number of faces detected.
    self.assertLen(actual_landmarks, #expected_landmarks)

    for i = 1, #actual_landmarks do
        for j, elem in ipairs(actual_landmarks[i]) do
            self.assertAlmostEqual(
                elem.x, expected_landmarks[i][j].x, mediapipe_lua.kwargs({ delta = _LANDMARKS_MARGIN })
            )
            self.assertAlmostEqual(
                elem.y, expected_landmarks[i][j].y, mediapipe_lua.kwargs({ delta = _LANDMARKS_MARGIN })
            )
        end
    end
end

function _assert._expect_blendshapes_correct(
    self, actual_blendshapes, expected_blendshapes
)
    -- Expects to have the same number of blendshapes.
    self.assertLen(actual_blendshapes, #expected_blendshapes)

    for i = 1, #actual_blendshapes do
        for j, elem in ipairs(actual_blendshapes[i]) do
            self.assertEqual(elem.index, expected_blendshapes[i][j].index)
            self.assertAlmostEqual(
                elem.score,
                expected_blendshapes[i][j].score,
                mediapipe_lua.kwargs({ delta = _BLENDSHAPES_MARGIN })
            )
        end
    end
end

function _assert._expect_facial_transformation_matrixes_correct(
    self, actual_matrix_list, expected_matrix_list
)
    self.assertLen(actual_matrix_list, #expected_matrix_list)

    for i, elem in ipairs(actual_matrix_list) do
        self.assertEqual(elem.shape[0], expected_matrix_list[i].shape[0])
        self.assertEqual(elem.shape[1], expected_matrix_list[i].shape[1])
        self.assertSequenceAlmostEqual(
            elem.flatten(),
            expected_matrix_list[i].flatten(),
            mediapipe_lua.kwargs({ delta = _FACIAL_TRANSFORMATION_MATRIX_MARGIN })
        )
    end
end

local function test_create_from_file_succeeds_with_valid_model_path(self)
    -- Creates with default option and valid model file successfully.
    local landmarker = _FaceLandmarker.create_from_model_path(self.model_path)
    self.assertIsInstance(landmarker, _FaceLandmarker)
end

local function test_create_from_options_succeeds_with_valid_model_path(self)
    -- Creates with options containing model file successfully.
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    local options = _FaceLandmarkerOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local landmarker = _FaceLandmarker.create_from_options(options)
    self.assertIsInstance(landmarker, _FaceLandmarker)
end

local function test_create_from_options_succeeds_with_valid_model_content(self)
    -- Creates with options containing model content successfully.
    local f = io.open(self.model_path, 'rb')
    local model_content = f:read('*all')
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_buffer = model_content }))
    local options = _FaceLandmarkerOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local landmarker = _FaceLandmarker.create_from_options(options)
    self.assertIsInstance(landmarker, _FaceLandmarker)
end

local function test_detect(
    self,
    model_file_type,
    model_name,
    expected_face_landmarks,
    expected_face_blendshapes,
    expected_facial_transformation_matrixes
)
    local base_options

    -- Creates face landmarker.
    local model_path = test_utils.get_test_data_path(model_name)
    if model_file_type == ModelFileType.FILE_NAME then
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = model_path }))
    elseif model_file_type == ModelFileType.FILE_CONTENT then
        local f = io.open(model_path, 'rb')
        local model_content = f:read('*all')
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_buffer = model_content }))
    else
        -- Should never happen
        error('model_file_type is invalid.')
    end

    local options = _FaceLandmarkerOptions(mediapipe_lua.kwargs({
        base_options = base_options,
        output_face_blendshapes = (not not expected_face_blendshapes),
        output_facial_transformation_matrixes = (not not expected_facial_transformation_matrixes),
    }))
    local landmarker = _FaceLandmarker.create_from_options(options)

    -- Performs face landmarks detection on the input.
    local detection_result = landmarker:detect(self.test_image)

    -- Comparing results.
    if expected_face_landmarks ~= nil then
        self:_expect_landmarks_correct(
            detection_result.face_landmarks, expected_face_landmarks
        )
    end

    if expected_face_blendshapes ~= nil then
        self:_expect_blendshapes_correct(
            detection_result.face_blendshapes, expected_face_blendshapes
        )
    end

    if expected_facial_transformation_matrixes ~= nil then
        self:_expect_facial_transformation_matrixes_correct(
            detection_result.facial_transformation_matrixes,
            expected_facial_transformation_matrixes
        )
    end
end

local function test_empty_detection_outputs(self)
    local options = _FaceLandmarkerOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    }))
    local landmarker = _FaceLandmarker.create_from_options(options)

    -- Load the image with no faces.
    local no_faces_test_image = _Image.create_from_file(
        test_utils.get_test_data_path(_CAT_IMAGE)
    )

    -- Performs face landmarks detection on the input.
    local detection_result = landmarker:detect(no_faces_test_image)

    self.assertEmpty(detection_result.face_landmarks)
    self.assertEmpty(detection_result.face_blendshapes)
    self.assertEmpty(detection_result.facial_transformation_matrixes)
end

local function test_detect_for_video(
    self,
    model_name,
    expected_face_landmarks,
    expected_face_blendshapes,
    expected_facial_transformation_matrixes
)
    -- Creates face landmarker.
    local model_path = test_utils.get_test_data_path(model_name)
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = model_path }))

    local options = _FaceLandmarkerOptions(mediapipe_lua.kwargs({
        base_options = base_options,
        running_mode = _RUNNING_MODE.VIDEO,
        output_face_blendshapes = (not not expected_face_blendshapes),
        output_facial_transformation_matrixes = (not not expected_facial_transformation_matrixes),
    }))

    local landmarker = _FaceLandmarker.create_from_options(options)
    for timestamp = 0, 300 - 30, 30 do
        -- Performs face landmarks detection on the input.
        local detection_result = landmarker:detect_for_video(
            self.test_image, timestamp
        )

        -- Comparing results.
        if expected_face_landmarks ~= nil then
            self:_expect_landmarks_correct(
                detection_result.face_landmarks, expected_face_landmarks
            )
        end

        if expected_face_blendshapes ~= nil then
            self:_expect_blendshapes_correct(
                detection_result.face_blendshapes, expected_face_blendshapes
            )
        end

        if expected_facial_transformation_matrixes ~= nil then
            self:_expect_facial_transformation_matrixes_correct(
                detection_result.facial_transformation_matrixes,
                expected_facial_transformation_matrixes
            )
        end
    end
end

local function test_detect_async_calls(
    self,
    image_path,
    model_name,
    expected_face_landmarks,
    expected_face_blendshapes,
    expected_facial_transformation_matrixes
)
    local test_image = _Image.create_from_file(
        test_utils.get_test_data_path(image_path)
    )

    local observed_timestamp_ms = -1

    local function check_result(result, output_image, timestamp_ms)
        -- Comparing results.
        if expected_face_landmarks ~= nil then
            self:_expect_landmarks_correct(
                result.face_landmarks, expected_face_landmarks
            )
        end

        if expected_face_blendshapes ~= nil then
            self:_expect_blendshapes_correct(
                result.face_blendshapes, expected_face_blendshapes
            )
        end

        if expected_facial_transformation_matrixes ~= nil then
            self:_expect_facial_transformation_matrixes_correct(
                result.facial_transformation_matrixes,
                expected_facial_transformation_matrixes
            )
        end

        self.assertMatEqual(output_image:mat_view(), test_image:mat_view())
        self.assertLess(observed_timestamp_ms, timestamp_ms)
        observed_timestamp_ms = timestamp_ms
    end

    local model_path = test_utils.get_test_data_path(model_name)
    local options = _FaceLandmarkerOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = model_path })),
        running_mode = _RUNNING_MODE.LIVE_STREAM,
        output_face_blendshapes = (not not expected_face_blendshapes),
        output_facial_transformation_matrixes = (not not expected_facial_transformation_matrixes),
        result_callback = check_result,
    }))

    local landmarker = _FaceLandmarker.create_from_options(options)
    local now = std.chrono.steady_clock.now()
    for timestamp = 0, 300 - 30, 30 do
        if timestamp > 0 then
            mediapipe_lua.notifyCallbacks()
            std.this_thread.sleep_until(now + std.chrono.milliseconds(timestamp))
        end

        landmarker:detect_async(test_image, timestamp)
    end

    -- wait for detection end
    landmarker:close()
    mediapipe_lua.notifyCallbacks()

    self.assertEqual(observed_timestamp_ms, 300 - 30)
end

describe("FaceLandmarkerTest", function()
    setUp(_assert)

    it("should test_create_from_file_succeeds_with_valid_model_path", function()
        test_create_from_file_succeeds_with_valid_model_path(_assert)
    end)

    it("should test_create_from_options_succeeds_with_valid_model_path", function()
        test_create_from_options_succeeds_with_valid_model_path(_assert)
    end)

    it("should test_create_from_options_succeeds_with_valid_model_content", function()
        test_create_from_options_succeeds_with_valid_model_content(_assert)
    end)

    for _, args in ipairs({
        {
            ModelFileType.FILE_NAME,
            _FACE_LANDMARKER_BUNDLE_ASSET_FILE,
            _get_expected_face_landmarks(_PORTRAIT_EXPECTED_FACE_LANDMARKS),
            nil,
            nil,
        },
        {
            ModelFileType.FILE_CONTENT,
            _FACE_LANDMARKER_BUNDLE_ASSET_FILE,
            _get_expected_face_landmarks(_PORTRAIT_EXPECTED_FACE_LANDMARKS),
            nil,
            nil,
        },
    }) do
        it("should test_detect " .. _, function()
            test_detect(_assert, unpack(args))
        end)
    end

    it("should test_empty_detection_outputs", function()
        test_empty_detection_outputs(_assert)
    end)

    for _, args in ipairs({
        {
            _FACE_LANDMARKER_BUNDLE_ASSET_FILE,
            _get_expected_face_landmarks(_PORTRAIT_EXPECTED_FACE_LANDMARKS),
            nil,
            nil,
        },
    }) do
        it("should test_detect_for_video " .. _, function()
            test_detect_for_video(_assert, unpack(args))
        end)
    end

    for _, args in ipairs({
        {
            _PORTRAIT_IMAGE,
            _FACE_LANDMARKER_BUNDLE_ASSET_FILE,
            _get_expected_face_landmarks(_PORTRAIT_EXPECTED_FACE_LANDMARKS),
            nil,
            nil,
        },
    }) do
        it("should test_detect_async_calls " .. _, function()
            test_detect_async_calls(_assert, unpack(args))
        end)
    end
end)
