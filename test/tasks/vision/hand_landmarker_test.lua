#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/tasks/python/test/vision/hand_landmarker_test.py
--]]

local unpack = table.unpack or unpack ---@diagnostic disable-line: deprecated
local INDEX_BASE = 1 -- lua is 1-based indexed

local _assert = require("_assert")
local _mat_utils = require("_mat_utils") ---@diagnostic disable-line: unused-local
local test_utils = require("test_utils")

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe
local google = mediapipe_lua.google
local std = mediapipe_lua.std

local text_format = google.protobuf.text_format
local image_module = mediapipe.lua._framework_bindings.image
local landmarks_detection_result_pb2 = mediapipe.tasks.cc.components.containers.proto.landmarks_detection_result_pb2
local landmark_detection_result_module = mediapipe.tasks.lua.components.containers.landmark_detection_result
local base_options_module = mediapipe.tasks.lua.core.base_options
local hand_landmarker = mediapipe.tasks.lua.vision.hand_landmarker
local image_processing_options_module = mediapipe.tasks.lua.vision.core.image_processing_options
local running_mode_module = mediapipe.tasks.lua.vision.core.vision_task_running_mode

local _LandmarksDetectionResultProto = (
    landmarks_detection_result_pb2.LandmarksDetectionResult)
local _BaseOptions = base_options_module.BaseOptions
local _LandmarksDetectionResult = (
    landmark_detection_result_module.LandmarksDetectionResult)
local _Image = image_module.Image
local _HandLandmarker = hand_landmarker.HandLandmarker
local _HandLandmarkerOptions = hand_landmarker.HandLandmarkerOptions
local _HandLandmarkerResult = hand_landmarker.HandLandmarkerResult
local _RUNNING_MODE = running_mode_module.VisionTaskRunningMode
local _ImageProcessingOptions = image_processing_options_module.ImageProcessingOptions

local _HAND_LANDMARKER_BUNDLE_ASSET_FILE = 'hand_landmarker.task'
local _NO_HANDS_IMAGE = 'cats_and_dogs.jpg'
local _TWO_HANDS_IMAGE = 'right_hands.jpg'
local _THUMB_UP_IMAGE = 'thumb_up.jpg'
local _THUMB_UP_LANDMARKS = 'thumb_up_landmarks.pbtxt'
local _POINTING_UP_IMAGE = 'pointing_up.jpg'
local _POINTING_UP_LANDMARKS = 'pointing_up_landmarks.pbtxt'
local _POINTING_UP_ROTATED_IMAGE = 'pointing_up_rotated.jpg'
local _POINTING_UP_ROTATED_LANDMARKS = 'pointing_up_rotated_landmarks.pbtxt'
local _LANDMARKS_MARGIN = 0.03
local _HANDEDNESS_MARGIN = 0.05

local _TEST_DATA_DIR = test_utils.get_resource_dir() .. '/mediapipe/tasks/testdata/vision'

local ModelFileType = {
    FILE_CONTENT = 1,
    FILE_NAME = 2,
}

local function _get_expected_hand_landmarker_result(file_path)
    local landmarks_detection_result_file_path = test_utils.get_test_data_path(file_path)
    local f = io.open(landmarks_detection_result_file_path, 'rb')
    local landmarks_detection_result_proto = _LandmarksDetectionResultProto()
    -- Use this if a .pb file is available.
    -- landmarks_detection_result_proto.ParseFromString(f:read('*all'))
    text_format.Parse(f:read('*all'), landmarks_detection_result_proto)
    local landmarks_detection_result = _LandmarksDetectionResult.create_from_pb2(
        landmarks_detection_result_proto)
    return _HandLandmarkerResult(mediapipe_lua.kwargs({
        handedness = { landmarks_detection_result.categories },
        hand_landmarks = { landmarks_detection_result.landmarks },
        hand_world_landmarks = { landmarks_detection_result.world_landmarks }
    }))
end

local function setUp(self)
    test_utils.download_test_files(_TEST_DATA_DIR, {
        {
            output = _HAND_LANDMARKER_BUNDLE_ASSET_FILE,
            url = "https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task"
        },
        _NO_HANDS_IMAGE,
        _TWO_HANDS_IMAGE,
        _THUMB_UP_IMAGE,
        _THUMB_UP_LANDMARKS,
        _POINTING_UP_IMAGE,
        _POINTING_UP_LANDMARKS,
        _POINTING_UP_ROTATED_IMAGE,
        _POINTING_UP_ROTATED_LANDMARKS,
    })

    self.test_image = _Image.create_from_file(test_utils.get_test_data_path(_THUMB_UP_IMAGE))
    self.model_path = test_utils.get_test_data_path(_HAND_LANDMARKER_BUNDLE_ASSET_FILE)
end

function _assert._expect_hand_landmarks_correct(
    self, actual_landmarks, expected_landmarks, margin
)
    -- Expects to have the same number of hands detected.
    self.assertLen(actual_landmarks, #expected_landmarks)

    for i = 1, #actual_landmarks do
        for j, elem in ipairs(actual_landmarks[i]) do
            self.assertAlmostEqual(elem.x, expected_landmarks[i][j].x, mediapipe_lua.kwargs({ delta = margin }))
            self.assertAlmostEqual(elem.y, expected_landmarks[i][j].y, mediapipe_lua.kwargs({ delta = margin }))
        end
    end
end

function _assert._expect_handedness_correct(
    self, actual_handedness, expected_handedness, margin
)
    -- Expects to have the same number of hands detected.
    self.assertLen(actual_handedness, #expected_handedness)

    if #expected_handedness == 0 then
        return
    end

    -- Actual top handedness matches expected top handedness.
    local actual_top_handedness = actual_handedness[0 + INDEX_BASE][0 + INDEX_BASE]
    local expected_top_handedness = expected_handedness[0 + INDEX_BASE][0 + INDEX_BASE]
    self.assertEqual(actual_top_handedness.index, expected_top_handedness.index)
    self.assertEqual(actual_top_handedness.category_name,
        expected_top_handedness.category_name)
    self.assertAlmostEqual(
        actual_top_handedness.score, expected_top_handedness.score, mediapipe_lua.kwargs({ delta = margin })
    )
end

function _assert._expect_hand_landmarker_results_correct(
    self,
    actual_result,
    expected_result
)
    self:_expect_hand_landmarks_correct(
        actual_result.hand_landmarks,
        expected_result.hand_landmarks,
        _LANDMARKS_MARGIN
    )
    self:_expect_handedness_correct(
        actual_result.handedness, expected_result.handedness, _HANDEDNESS_MARGIN
    )
end

local function test_create_from_file_succeeds_with_valid_model_path(self)
    -- Creates with default option and valid model file successfully.
    local landmarker = _HandLandmarker.create_from_model_path(self.model_path)
    self.assertIsInstance(landmarker, _HandLandmarker)
end

local function test_create_from_options_succeeds_with_valid_model_path(self)
    -- Creates with options containing model file successfully.
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    local options = _HandLandmarkerOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local landmarker = _HandLandmarker.create_from_options(options)
    self.assertIsInstance(landmarker, _HandLandmarker)
end

local function test_create_from_options_succeeds_with_valid_model_content(self)
    -- Creates with options containing model content successfully.
    local f = io.open(self.model_path, 'rb')
    local model_content = f:read('*all')
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_buffer = model_content }))
    local options = _HandLandmarkerOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local landmarker = _HandLandmarker.create_from_options(options)
    self.assertIsInstance(landmarker, _HandLandmarker)
end

local function test_detect(self, model_file_type, expected_detection_result)
    local base_options

    -- Creates hand landmarker.
    if model_file_type == ModelFileType.FILE_NAME then
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    elseif model_file_type == ModelFileType.FILE_CONTENT then
        local f = io.open(self.model_path, 'rb')
        local model_content = f:read('*all')
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_buffer = model_content }))
    else
        -- Should never happen
        error('model_file_type is invalid.')
    end

    local options = _HandLandmarkerOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local landmarker = _HandLandmarker.create_from_options(options)

    -- Performs hand landmarks detection on the input.
    local detection_result = landmarker:detect(self.test_image)
    -- Comparing results.
    self:_expect_hand_landmarker_results_correct(
        detection_result, expected_detection_result
    )
end

local function test_detect_succeeds_with_num_hands(self)
    -- Creates hand landmarker.
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    local options = _HandLandmarkerOptions(mediapipe_lua.kwargs({ base_options = base_options, num_hands = 2 }))
    local landmarker = _HandLandmarker.create_from_options(options)

    -- Load the two hands image.
    local test_image = _Image.create_from_file(
        test_utils.get_test_data_path(_TWO_HANDS_IMAGE))

    -- Performs hand landmarks detection on the input.
    local detection_result = landmarker:detect(test_image)

    -- Comparing results.
    self.assertLen(detection_result.handedness, 2)
end

local function test_detect_succeeds_with_rotation(self)
    -- Creates hand landmarker.
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    local options = _HandLandmarkerOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local landmarker = _HandLandmarker.create_from_options(options)

    -- Load the pointing up rotated image.
    local test_image = _Image.create_from_file(
        test_utils.get_test_data_path(_POINTING_UP_ROTATED_IMAGE))

    -- Set rotation parameters using ImageProcessingOptions.
    local image_processing_options = _ImageProcessingOptions(mediapipe_lua.kwargs({ rotation_degrees = -90 }))

    -- Performs hand landmarks detection on the input.
    local detection_result = landmarker:detect(test_image, image_processing_options)
    local expected_detection_result = _get_expected_hand_landmarker_result(
        _POINTING_UP_ROTATED_LANDMARKS)

    -- Comparing results.
    self:_expect_hand_landmarker_results_correct(
        detection_result, expected_detection_result
    )
end

local function test_empty_detection_outputs(self)
    local options = _HandLandmarkerOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })) }))
    local landmarker = _HandLandmarker.create_from_options(options)

    -- Load the image with no hands.
    local no_hands_test_image = _Image.create_from_file(
        test_utils.get_test_data_path(_NO_HANDS_IMAGE))

    -- Performs hand landmarks detection on the input.
    local detection_result = landmarker:detect(no_hands_test_image)

    self.assertEmpty(detection_result.hand_landmarks)
    self.assertEmpty(detection_result.hand_world_landmarks)
    self.assertEmpty(detection_result.handedness)
end

local function test_detect_for_video(self, image_path, rotation, expected_result)
    local test_image = _Image.create_from_file(
        test_utils.get_test_data_path(image_path))

    -- Set rotation parameters using ImageProcessingOptions.
    local image_processing_options = _ImageProcessingOptions(mediapipe_lua.kwargs({
        rotation_degrees = rotation }))

    local options = _HandLandmarkerOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
        running_mode = _RUNNING_MODE.VIDEO
    }))

    local landmarker = _HandLandmarker.create_from_options(options)
    for timestamp = 0, 300 - 30, 30 do
        local result = landmarker:detect_for_video(test_image, timestamp,
            image_processing_options)
        if (result.hand_landmarks and result.hand_world_landmarks and
                result.handedness) then
            self:_expect_hand_landmarker_results_correct(result, expected_result)
        else
            self.assertEqual(result, expected_result)
        end
    end
end

local function test_detect_async_calls(self, image_path, rotation, expected_result)
    local test_image = _Image.create_from_file(
        test_utils.get_test_data_path(image_path))

    -- Set rotation parameters using ImageProcessingOptions.
    local image_processing_options = _ImageProcessingOptions(mediapipe_lua.kwargs({
        rotation_degrees = rotation }))

    local observed_timestamp_ms = -1

    local function check_result(result, output_image, timestamp_ms)
        if (result.hand_landmarks and result.hand_world_landmarks and
                result.handedness) then
            self:_expect_hand_landmarker_results_correct(result, expected_result)
        else
            self.assertEqual(result, expected_result)
        end
        self.assertMatEqual(output_image:mat_view(), test_image:mat_view())
        self.assertLess(observed_timestamp_ms, timestamp_ms)
        observed_timestamp_ms = timestamp_ms
    end

    local options = _HandLandmarkerOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
        running_mode = _RUNNING_MODE.LIVE_STREAM,
        result_callback = check_result
    }))

    local landmarker = _HandLandmarker.create_from_options(options)
    local now = std.chrono.steady_clock.now()
    for timestamp = 0, 300 - 30, 30 do
        if timestamp > 0 then
            mediapipe_lua.notifyCallbacks()
            std.this_thread.sleep_until(now + std.chrono.milliseconds(timestamp))
        end

        landmarker:detect_async(test_image, timestamp, image_processing_options)
    end

    -- wait for detection end
    landmarker:close()
    mediapipe_lua.notifyCallbacks()

    self.assertEqual(observed_timestamp_ms, 300 - 30)
end

describe("HandLandmarkerTest", function()
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
        { ModelFileType.FILE_NAME,
            _get_expected_hand_landmarker_result(_THUMB_UP_LANDMARKS) },
        { ModelFileType.FILE_CONTENT,
            _get_expected_hand_landmarker_result(_THUMB_UP_LANDMARKS) },
    }) do
        it("should test_detect " .. _, function()
            test_detect(_assert, unpack(args))
        end)
    end

    it("should test_detect_succeeds_with_num_hands", function()
        test_detect_succeeds_with_num_hands(_assert)
    end)

    it("should test_detect_succeeds_with_rotation", function()
        test_detect_succeeds_with_rotation(_assert)
    end)

    it("should test_empty_detection_outputs", function()
        test_empty_detection_outputs(_assert)
    end)

    for _, args in ipairs({
        { _THUMB_UP_IMAGE, 0,
            _get_expected_hand_landmarker_result(_THUMB_UP_LANDMARKS) },
        { _POINTING_UP_IMAGE, 0,
            _get_expected_hand_landmarker_result(_POINTING_UP_LANDMARKS) },
        { _POINTING_UP_ROTATED_IMAGE, -90,
            _get_expected_hand_landmarker_result(_POINTING_UP_ROTATED_LANDMARKS) },
        { _NO_HANDS_IMAGE, 0, _HandLandmarkerResult({}, {}, {}) },
    }) do
        it("should test_detect_for_video " .. _, function()
            test_detect_for_video(_assert, unpack(args))
        end)
    end

    for _, args in ipairs({
        { _THUMB_UP_IMAGE, 0,
            _get_expected_hand_landmarker_result(_THUMB_UP_LANDMARKS) },
        { _POINTING_UP_IMAGE, 0,
            _get_expected_hand_landmarker_result(_POINTING_UP_LANDMARKS) },
        { _POINTING_UP_ROTATED_IMAGE, -90,
            _get_expected_hand_landmarker_result(_POINTING_UP_ROTATED_LANDMARKS) },
        { _NO_HANDS_IMAGE, 0, _HandLandmarkerResult({}, {}, {}) },
    }) do
        it("should test_detect_async_calls " .. _, function()
            test_detect_async_calls(_assert, unpack(args))
        end)
    end
end)
