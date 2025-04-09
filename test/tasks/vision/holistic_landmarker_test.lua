#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/tasks/python/test/vision/holistic_landmarker_test.py
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
local holistic_result_pb2 = mediapipe.tasks.cc.vision.holistic_landmarker.proto.holistic_result_pb2
local base_options_module = mediapipe.tasks.lua.core.base_options
local holistic_landmarker = mediapipe.tasks.lua.vision.holistic_landmarker
local running_mode_module = mediapipe.tasks.lua.vision.core.vision_task_running_mode

local HolisticLandmarkerResult = holistic_landmarker.HolisticLandmarkerResult
local _HolisticResultProto = holistic_result_pb2.HolisticResult
local _BaseOptions = base_options_module.BaseOptions
local _Image = image_module.Image
local _HolisticLandmarker = holistic_landmarker.HolisticLandmarker
local _HolisticLandmarkerOptions = holistic_landmarker.HolisticLandmarkerOptions
local _RUNNING_MODE = running_mode_module.VisionTaskRunningMode

local _HOLISTIC_LANDMARKER_BUNDLE_ASSET_FILE = 'holistic_landmarker.task'
local _POSE_IMAGE = 'male_full_height_hands.jpg'
local _CAT_IMAGE = 'cat.jpg'
local _EXPECTED_HOLISTIC_RESULT = 'male_full_height_hands_result_cpu.pbtxt'
local _IMAGE_WIDTH = 638
local _IMAGE_HEIGHT = 1000
local _LANDMARKS_MARGIN = 0.03
local _BLENDSHAPES_MARGIN = 0.13
local _VIDEO_LANDMARKS_MARGIN = 0.03
local _VIDEO_BLENDSHAPES_MARGIN = 0.31
local _LIVE_STREAM_LANDMARKS_MARGIN = 0.03
local _LIVE_STREAM_BLENDSHAPES_MARGIN = 0.31

local _TEST_DATA_DIR = test_utils.get_resource_dir() .. '/mediapipe/tasks/testdata/vision'

local function _get_expected_holistic_landmarker_result(file_path)
    local holistic_result_file_path = test_utils.get_test_data_path(file_path)
    local f = io.open(holistic_result_file_path, 'rb')
    local holistic_result_proto = _HolisticResultProto()
    -- Use this if a .pb file is available.
    -- holistic_result_proto.ParseFromString(f.read('*alll'))
    text_format.Parse(f:read('*alll'), holistic_result_proto)
    local holistic_landmarker_result = HolisticLandmarkerResult.create_from_pb2(
        holistic_result_proto
    )
    return holistic_landmarker_result
end

local ModelFileType = {
    FILE_CONTENT = 1,
    FILE_NAME = 2,
}

local function setUp(self)
    test_utils.download_test_files(_TEST_DATA_DIR, {
        _HOLISTIC_LANDMARKER_BUNDLE_ASSET_FILE,
        _POSE_IMAGE,
        _CAT_IMAGE,
        _EXPECTED_HOLISTIC_RESULT,
    })

    self.test_image = _Image.create_from_file(test_utils.get_test_data_path(_POSE_IMAGE))
    self.model_path = test_utils.get_test_data_path(_HOLISTIC_LANDMARKER_BUNDLE_ASSET_FILE)
end

function _assert._expect_landmarks_correct(
    self, actual_landmarks, expected_landmarks, margin
)
    -- Expects to have the same number of landmarks detected.
    self.assertLen(actual_landmarks, #expected_landmarks)

    for i, elem in ipairs(actual_landmarks) do
        self.assertAlmostEqual(elem.x, expected_landmarks[i].x, mediapipe_lua.kwargs({ delta = margin }))
        self.assertAlmostEqual(elem.y, expected_landmarks[i].y, mediapipe_lua.kwargs({ delta = margin }))
    end
end

function _assert._expect_blendshapes_correct(
    self, actual_blendshapes, expected_blendshapes, margin
)
    -- Expects to have the same number of blendshapes.
    self.assertLen(actual_blendshapes, #expected_blendshapes)

    for i, elem in ipairs(actual_blendshapes) do
        self.assertEqual(elem.index, expected_blendshapes[i].index)
        self.assertEqual(
            elem.category_name, expected_blendshapes[i].category_name
        )
        self.assertAlmostEqual(
            elem.score,
            expected_blendshapes[i].score,
            mediapipe_lua.kwargs({ delta = margin })
        )
    end
end

function _assert._expect_holistic_landmarker_results_correct(
    self,
    actual_result,
    expected_result,
    output_segmentation_mask,
    landmarks_margin,
    blendshapes_margin
)
    self:_expect_landmarks_correct(
        actual_result.pose_landmarks,
        expected_result.pose_landmarks,
        landmarks_margin
    )
    self:_expect_landmarks_correct(
        actual_result.face_landmarks,
        expected_result.face_landmarks,
        landmarks_margin
    )
    self:_expect_blendshapes_correct(
        actual_result.face_blendshapes,
        expected_result.face_blendshapes,
        blendshapes_margin
    )
    if output_segmentation_mask then
        self.assertIsInstance(actual_result.segmentation_mask, _Image)
        self.assertEqual(actual_result.segmentation_mask.width, _IMAGE_WIDTH)
        self.assertEqual(actual_result.segmentation_mask.height, _IMAGE_HEIGHT)
    else
        self.assertIsNone(actual_result.segmentation_mask)
    end
end

local function test_create_from_file_succeeds_with_valid_model_path(self)
    -- Creates with default option and valid model file successfully.
    local landmarker = _HolisticLandmarker.create_from_model_path(self.model_path)
    self.assertIsInstance(landmarker, _HolisticLandmarker)
end

local function test_create_from_options_succeeds_with_valid_model_path(self)
    -- Creates with options containing model file successfully.
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    local options = _HolisticLandmarkerOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local landmarker = _HolisticLandmarker.create_from_options(options)
    self.assertIsInstance(landmarker, _HolisticLandmarker)
end

local function test_create_from_options_succeeds_with_valid_model_content(self)
    -- Creates with options containing model content successfully.
    local f = io.open(self.model_path, 'rb')
    local model_content = f:read('*all')
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_buffer = model_content }))
    local options = _HolisticLandmarkerOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local landmarker = _HolisticLandmarker.create_from_options(options)
    self.assertIsInstance(landmarker, _HolisticLandmarker)
end

local function test_detect(
    self,
    model_file_type,
    model_name,
    output_segmentation_mask,
    expected_holistic_landmarker_result
)
    local base_options

    -- Creates holistic landmarker.
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

    local options = _HolisticLandmarkerOptions(mediapipe_lua.kwargs({
        base_options = base_options,
        output_face_blendshapes = (not not expected_holistic_landmarker_result.face_blendshapes),
        output_segmentation_mask = output_segmentation_mask,
    }))

    local landmarker = _HolisticLandmarker.create_from_options(options)

    -- Performs holistic landmarks detection on the input.
    local detection_result = landmarker:detect(self.test_image)

    self:_expect_holistic_landmarker_results_correct(
        detection_result,
        expected_holistic_landmarker_result,
        output_segmentation_mask,
        _LANDMARKS_MARGIN,
        _BLENDSHAPES_MARGIN
    )
end

local function test_empty_detection_outputs(self)
    local options = _HolisticLandmarkerOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    }))

    local landmarker = _HolisticLandmarker.create_from_options(options)

    -- Load the cat image.
    local cat_test_image = _Image.create_from_file(
        test_utils.get_test_data_path(_CAT_IMAGE)
    )

    -- Performs holistic landmarks detection on the input.
    local detection_result = landmarker:detect(cat_test_image)

    self.assertEmpty(detection_result.face_landmarks)
    self.assertEmpty(detection_result.pose_landmarks)
    self.assertEmpty(detection_result.pose_world_landmarks)
    self.assertEmpty(detection_result.left_hand_landmarks)
    self.assertEmpty(detection_result.left_hand_world_landmarks)
    self.assertEmpty(detection_result.right_hand_landmarks)
    self.assertEmpty(detection_result.right_hand_world_landmarks)
    self.assertIsNone(detection_result.face_blendshapes)
    self.assertIsNone(detection_result.segmentation_mask)
end

local function test_detect_for_video(
    self,
    model_name,
    output_segmentation_mask,
    expected_holistic_landmarker_result
)
    -- Creates holistic landmarker.
    local model_path = test_utils.get_test_data_path(model_name)
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = model_path }))
    local options = _HolisticLandmarkerOptions(mediapipe_lua.kwargs({
        base_options = base_options,
        running_mode = _RUNNING_MODE.VIDEO,
        output_face_blendshapes = (not not expected_holistic_landmarker_result.face_blendshapes),
        output_segmentation_mask = output_segmentation_mask,
    }))

    local landmarker = _HolisticLandmarker.create_from_options(options)
    for timestamp = 0, 300 - 30, 30 do
        -- Performs holistic landmarks detection on the input.
        detection_result = landmarker:detect_for_video(
            self.test_image, timestamp
        )

        -- Comparing results.
        self:_expect_holistic_landmarker_results_correct(
            detection_result,
            expected_holistic_landmarker_result,
            output_segmentation_mask,
            _VIDEO_LANDMARKS_MARGIN,
            _VIDEO_BLENDSHAPES_MARGIN
        )
    end
end

local function test_detect_async_calls(
    self,
    image_path,
    model_name,
    output_segmentation_mask,
    expected_holistic_landmarker_result
)
    local test_image = _Image.create_from_file(
        test_utils.get_test_data_path(image_path)
    )

    local observed_timestamp_ms = -1

    local function check_result(result, output_image, timestamp_ms)
        -- Comparing results.
        self:_expect_holistic_landmarker_results_correct(
            result,
            expected_holistic_landmarker_result,
            output_segmentation_mask,
            _LIVE_STREAM_LANDMARKS_MARGIN,
            _LIVE_STREAM_BLENDSHAPES_MARGIN
        )
        self.assertMatEqual(output_image:mat_view(), test_image:mat_view())
        self.assertLess(observed_timestamp_ms, timestamp_ms)
        observed_timestamp_ms = timestamp_ms
    end

    local model_path = test_utils.get_test_data_path(model_name)

    local options = _HolisticLandmarkerOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = model_path })),
        running_mode = _RUNNING_MODE.LIVE_STREAM,
        output_face_blendshapes = (not not expected_holistic_landmarker_result.face_blendshapes),
        output_segmentation_mask = output_segmentation_mask,
        result_callback = check_result,
    }))

    local landmarker = _HolisticLandmarker.create_from_options(options)
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

describe("HolisticLandmarkerTest", function()
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
            _HOLISTIC_LANDMARKER_BUNDLE_ASSET_FILE,
            false,
            _get_expected_holistic_landmarker_result(_EXPECTED_HOLISTIC_RESULT),
        },
        {
            ModelFileType.FILE_CONTENT,
            _HOLISTIC_LANDMARKER_BUNDLE_ASSET_FILE,
            false,
            _get_expected_holistic_landmarker_result(_EXPECTED_HOLISTIC_RESULT),
        },
        {
            ModelFileType.FILE_NAME,
            _HOLISTIC_LANDMARKER_BUNDLE_ASSET_FILE,
            true,
            _get_expected_holistic_landmarker_result(_EXPECTED_HOLISTIC_RESULT),
        },
        {
            ModelFileType.FILE_CONTENT,
            _HOLISTIC_LANDMARKER_BUNDLE_ASSET_FILE,
            true,
            _get_expected_holistic_landmarker_result(_EXPECTED_HOLISTIC_RESULT),
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
            _HOLISTIC_LANDMARKER_BUNDLE_ASSET_FILE,
            false,
            _get_expected_holistic_landmarker_result(_EXPECTED_HOLISTIC_RESULT),
        },
        {
            _HOLISTIC_LANDMARKER_BUNDLE_ASSET_FILE,
            true,
            _get_expected_holistic_landmarker_result(_EXPECTED_HOLISTIC_RESULT),
        },
    }) do
        it("should test_detect_for_video " .. _, function()
            test_detect_for_video(_assert, unpack(args))
        end)
    end

    for _, args in ipairs({
        {
            _POSE_IMAGE,
            _HOLISTIC_LANDMARKER_BUNDLE_ASSET_FILE,
            false,
            _get_expected_holistic_landmarker_result(_EXPECTED_HOLISTIC_RESULT),
        },
        {
            _POSE_IMAGE,
            _HOLISTIC_LANDMARKER_BUNDLE_ASSET_FILE,
            true,
            _get_expected_holistic_landmarker_result(_EXPECTED_HOLISTIC_RESULT),
        },
    }) do
        it("should test_detect_async_calls " .. _, function()
            test_detect_async_calls(_assert, unpack(args))
        end)
    end
end)
