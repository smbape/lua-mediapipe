#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/tasks/python/test/vision/pose_landmarker_test.py
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
local image_module = mediapipe.lua._framework_bindings.image
local landmarks_detection_result_pb2 = mediapipe.tasks.cc.components.containers.proto.landmarks_detection_result_pb2
local landmark_detection_result_module = mediapipe.tasks.lua.components.containers.landmark_detection_result
local base_options_module = mediapipe.tasks.lua.core.base_options
local pose_landmarker = mediapipe.tasks.lua.vision.pose_landmarker
local image_processing_options_module = mediapipe.tasks.lua.vision.core.image_processing_options
local running_mode_module = mediapipe.tasks.lua.vision.core.vision_task_running_mode

local PoseLandmarkerResult = pose_landmarker.PoseLandmarkerResult
local _LandmarksDetectionResultProto = (
    landmarks_detection_result_pb2.LandmarksDetectionResult
)
local _BaseOptions = base_options_module.BaseOptions
local _LandmarksDetectionResult = (
    landmark_detection_result_module.LandmarksDetectionResult
)
local _Image = image_module.Image
local _PoseLandmarker = pose_landmarker.PoseLandmarker
local _PoseLandmarkerOptions = pose_landmarker.PoseLandmarkerOptions
local _RUNNING_MODE = running_mode_module.VisionTaskRunningMode
local _ImageProcessingOptions = image_processing_options_module.ImageProcessingOptions

local _POSE_LANDMARKER_BUNDLE_ASSET_FILE = 'pose_landmarker.task'
local _BURGER_IMAGE = 'burger.jpg'
local _POSE_IMAGE = 'pose.jpg'
local _POSE_LANDMARKS = 'pose_landmarks.pbtxt'
local _LANDMARKS_MARGIN = 0.03

local _TEST_DATA_DIR = test_utils.get_resource_dir() .. '/mediapipe/tasks/testdata/vision'

local function _get_expected_pose_landmarker_result(file_path)
    local landmarks_detection_result_file_path = test_utils.get_test_data_path(
        file_path
    )
    local f = io.open(landmarks_detection_result_file_path, 'rb')
    local landmarks_detection_result_proto = _LandmarksDetectionResultProto()

    -- Use this if a .pb file is available.
    -- landmarks_detection_result_proto.ParseFromString(f:read('*all'))
    text_format.Parse(f:read('*all'), landmarks_detection_result_proto)

    local landmarks_detection_result = _LandmarksDetectionResult.create_from_pb2(
        landmarks_detection_result_proto
    )

    return PoseLandmarkerResult(mediapipe_lua.kwargs({
        pose_landmarks = { landmarks_detection_result.landmarks },
        pose_world_landmarks = {},
    }))
end

local ModelFileType = {
    FILE_CONTENT = 1,
    FILE_NAME = 2,
}

local function setUp(self)
    test_utils.download_test_files(_TEST_DATA_DIR, {
        _POSE_LANDMARKER_BUNDLE_ASSET_FILE,
        _BURGER_IMAGE,
        _POSE_IMAGE,
        _POSE_LANDMARKS,
    })

    self.test_image = _Image.create_from_file(
        test_utils.get_test_data_path(_POSE_IMAGE)
    )
    self.model_path = test_utils.get_test_data_path(
        _POSE_LANDMARKER_BUNDLE_ASSET_FILE
    )
end

function _assert._expect_pose_landmarks_correct(
    self, actual_landmarks, expected_landmarks, margin
)
    -- Expects to have the same number of poses detected.
    self.assertLen(actual_landmarks, #expected_landmarks)

    for i, _ in ipairs(actual_landmarks) do
        for j, elem in ipairs(actual_landmarks[i]) do
            self.assertAlmostEqual(elem.x, expected_landmarks[i][j].x, mediapipe_lua.kwargs({ delta = margin }))
            self.assertAlmostEqual(elem.y, expected_landmarks[i][j].y, mediapipe_lua.kwargs({ delta = margin }))
        end
    end
end

function _assert._expect_pose_landmarker_results_correct(
    self,
    actual_result,
    expected_result,
    output_segmentation_masks,
    margin
)
    self:_expect_pose_landmarks_correct(
        actual_result.pose_landmarks, expected_result.pose_landmarks, margin
    )
    if output_segmentation_masks then
        self.assertIsInstance(actual_result.segmentation_masks, "table")
        for _, mask in ipairs(actual_result.segmentation_masks) do
            self.assertIsInstance(mask, _Image)
        end
    else
        self.assertIsNone(actual_result.segmentation_masks)
    end
end

local function test_create_from_file_succeeds_with_valid_model_path(self)
    -- Creates with default option and valid model file successfully.
    local landmarker = _PoseLandmarker.create_from_model_path(self.model_path)
    self.assertIsInstance(landmarker, _PoseLandmarker)
end

local function test_create_from_options_succeeds_with_valid_model_path(self)
    -- Creates with options containing model file successfully.
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    local options = _PoseLandmarkerOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local landmarker = _PoseLandmarker.create_from_options(options)
    self.assertIsInstance(landmarker, _PoseLandmarker)
end

local function test_create_from_options_succeeds_with_valid_model_content(self)
    -- Creates with options containing model content successfully.
    local f = io.open(self.model_path, 'rb')
    local model_content = f:read('*all')
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_buffer = model_content }))
    local options = _PoseLandmarkerOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local landmarker = _PoseLandmarker.create_from_options(options)
    self.assertIsInstance(landmarker, _PoseLandmarker)
end

local function test_detect(
    self,
    model_file_type,
    output_segmentation_masks,
    expected_detection_result
)
    local base_options

    -- Creates pose landmarker.
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

    local options = _PoseLandmarkerOptions(mediapipe_lua.kwargs({
        base_options = base_options,
        output_segmentation_masks = output_segmentation_masks,
    }))
    local landmarker = _PoseLandmarker.create_from_options(options)

    -- Performs pose landmarks detection on the input.
    local detection_result = landmarker:detect(self.test_image)

    -- Comparing results.
    self:_expect_pose_landmarker_results_correct(
        detection_result,
        expected_detection_result,
        output_segmentation_masks,
        _LANDMARKS_MARGIN
    )
end

local function test_empty_detection_outputs(self)
    -- Creates pose landmarker.
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    local options = _PoseLandmarkerOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local landmarker = _PoseLandmarker.create_from_options(options)

    -- Load an image with no poses.
    local test_image = _Image.create_from_file(
        test_utils.get_test_data_path(_BURGER_IMAGE)
    )

    -- Performs pose landmarks detection on the input.
    local detection_result = landmarker:detect(test_image)
    -- Comparing results.
    self.assertEmpty(detection_result.pose_landmarks)
    self.assertEmpty(detection_result.pose_world_landmarks)
end

local function test_detect_for_video(
    self, image_path, rotation, output_segmentation_masks, expected_result
)
    local test_image = _Image.create_from_file(
        test_utils.get_test_data_path(image_path)
    )

    -- Set rotation parameters using ImageProcessingOptions.
    local image_processing_options = _ImageProcessingOptions(mediapipe_lua.kwargs({
        rotation_degrees = rotation
    }))

    local options = _PoseLandmarkerOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
        output_segmentation_masks = output_segmentation_masks,
        running_mode = _RUNNING_MODE.VIDEO,
    }))

    local landmarker = _PoseLandmarker.create_from_options(options)
    for timestamp = 0, 300 - 30, 30 do
        local result = landmarker:detect_for_video(
            test_image, timestamp, image_processing_options
        )
        if result.pose_landmarks then
            self:_expect_pose_landmarker_results_correct(
                result,
                expected_result,
                output_segmentation_masks,
                _LANDMARKS_MARGIN
            )
        else
            self.assertEqual(result, expected_result)
        end
    end
end

local function test_detect_async_calls(
    self, image_path, rotation, output_segmentation_masks, expected_result
)
    local test_image = _Image.create_from_file(
        test_utils.get_test_data_path(image_path)
    )
    -- Set rotation parameters using ImageProcessingOptions.
    local image_processing_options = _ImageProcessingOptions(mediapipe_lua.kwargs({
        rotation_degrees = rotation
    }))
    local observed_timestamp_ms = -1

    local function check_result(result, output_image, timestamp_ms)
        if result.pose_landmarks then
            self:_expect_pose_landmarker_results_correct(
                result,
                expected_result,
                output_segmentation_masks,
                _LANDMARKS_MARGIN
            )
        else
            self.assertEqual(result, expected_result)
        end
        self.assertMatEqual(output_image:mat_view(), test_image:mat_view())
        self.assertLess(observed_timestamp_ms, timestamp_ms)
        observed_timestamp_ms = timestamp_ms
    end

    local options = _PoseLandmarkerOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
        output_segmentation_masks = output_segmentation_masks,
        running_mode = _RUNNING_MODE.LIVE_STREAM,
        result_callback = check_result,
    }))

    local landmarker = _PoseLandmarker.create_from_options(options)
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

describe("PoseLandmarkerTest", function()
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
            false,
            _get_expected_pose_landmarker_result(_POSE_LANDMARKS),
        },
        {
            ModelFileType.FILE_CONTENT,
            false,
            _get_expected_pose_landmarker_result(_POSE_LANDMARKS),
        },
        {
            ModelFileType.FILE_NAME,
            true,
            _get_expected_pose_landmarker_result(_POSE_LANDMARKS),
        },
        {
            ModelFileType.FILE_CONTENT,
            true,
            _get_expected_pose_landmarker_result(_POSE_LANDMARKS),
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
            _POSE_IMAGE,
            0,
            false,
            _get_expected_pose_landmarker_result(_POSE_LANDMARKS),
        },
        {
            _POSE_IMAGE,
            0,
            true,
            _get_expected_pose_landmarker_result(_POSE_LANDMARKS),
        },
        { _BURGER_IMAGE, 0, false, PoseLandmarkerResult({}, {}) },
    }) do
        it("should test_detect_for_video " .. _, function()
            test_detect_for_video(_assert, unpack(args))
        end)
    end

    for _, args in ipairs({
        {
            _POSE_IMAGE,
            0,
            false,
            _get_expected_pose_landmarker_result(_POSE_LANDMARKS),
        },
        {
            _POSE_IMAGE,
            0,
            true,
            _get_expected_pose_landmarker_result(_POSE_LANDMARKS),
        },
        { _BURGER_IMAGE, 0, false, PoseLandmarkerResult({}, {}) },
    }) do
        it("should test_detect_async_calls " .. _, function()
            test_detect_async_calls(_assert, unpack(args))
        end)
    end
end)
