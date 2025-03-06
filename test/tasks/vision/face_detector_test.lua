#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/tasks/python/test/vision/face_detector_test.py
--]]

local unpack = table.unpack or unpack ---@diagnostic disable-line: deprecated

local _assert = require("_assert")
local test_utils = require("test_utils")

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe
local google = mediapipe_lua.google

local text_format = google.protobuf.text_format
local detection_pb2 = mediapipe.framework.formats.detection_pb2
local image_module = mediapipe.lua._framework_bindings.image
local detections_module = mediapipe.tasks.lua.components.containers.detections
local base_options_module = mediapipe.tasks.lua.core.base_options
local face_detector = mediapipe.tasks.lua.vision.face_detector
local image_processing_options_module = mediapipe.tasks.lua.vision.core.image_processing_options
local running_mode_module = mediapipe.tasks.lua.vision.core.vision_task_running_mode

local FaceDetectorResult = detections_module.DetectionResult
local _BaseOptions = base_options_module.BaseOptions
local _Image = image_module.Image
local _FaceDetector = face_detector.FaceDetector
local _FaceDetectorOptions = face_detector.FaceDetectorOptions
local _RUNNING_MODE = running_mode_module.VisionTaskRunningMode
local _ImageProcessingOptions = image_processing_options_module.ImageProcessingOptions

local _SHORT_RANGE_BLAZE_FACE_MODEL = 'face_detection_short_range.tflite'
local _PORTRAIT_IMAGE = 'portrait.jpg'
local _PORTRAIT_EXPECTED_DETECTION = 'portrait_expected_detection.pbtxt'
local _PORTRAIT_ROTATED_IMAGE = 'portrait_rotated.jpg'
local _PORTRAIT_ROTATED_EXPECTED_DETECTION = (
    'portrait_rotated_expected_detection.pbtxt'
)
local _CAT_IMAGE = 'cat.jpg'
local _KEYPOINT_ERROR_THRESHOLD = 1e-2

local _TEST_DATA_DIR = test_utils.get_resource_dir() .. '/mediapipe/tasks/testdata/vision'

---@param file_name string
---@return FaceDetectorResult
local function _get_expected_face_detector_result(file_name)
    local face_detection_result_file_path = test_utils.get_test_data_path(file_name)
    local f = io.open(face_detection_result_file_path, 'rb')
    local face_detection_proto = detection_pb2.Detection()
    text_format.Parse(f:read('*all'), face_detection_proto)
    local face_detection = detections_module.Detection.create_from_pb2(
        face_detection_proto
    )
    return FaceDetectorResult(mediapipe_lua.kwargs({ detections = { face_detection } }))
end

local ModelFileType = {
    FILE_CONTENT = 1,
    FILE_NAME = 2,
}

local function setUp(self)
    test_utils.download_test_files(_TEST_DATA_DIR, {
        {
            file = _SHORT_RANGE_BLAZE_FACE_MODEL,
            url = "https://storage.googleapis.com/mediapipe-models/face_detector/blaze_face_short_range/float16/1/blaze_face_short_range.tflite"
        },
        _PORTRAIT_IMAGE,
        _PORTRAIT_EXPECTED_DETECTION,
        _PORTRAIT_ROTATED_IMAGE,
        _PORTRAIT_ROTATED_EXPECTED_DETECTION,
        _CAT_IMAGE,
    })

    self.test_image = _Image.create_from_file(test_utils.get_test_data_path(_PORTRAIT_IMAGE))
    self.model_path = test_utils.get_test_data_path(_SHORT_RANGE_BLAZE_FACE_MODEL)
end

local function test_create_from_file_succeeds_with_valid_model_path(self)
    -- Creates with default option and valid model file successfully.
    local detector = _FaceDetector.create_from_model_path(self.model_path)
    self.assertIsInstance(detector, _FaceDetector)
end

local function test_create_from_options_succeeds_with_valid_model_path(self)
    -- Creates with options containing model file successfully.
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    local options = _FaceDetectorOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local detector = _FaceDetector.create_from_options(options)
    self.assertIsInstance(detector, _FaceDetector)
end

local function test_create_from_options_succeeds_with_valid_model_content(self)
    -- Creates with options containing model content successfully.
    local f = io.open(self.model_path, 'rb')
    local model_content = f:read('*all')
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_buffer = model_content }))
    local options = _FaceDetectorOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local detector = _FaceDetector.create_from_options(options)
    self.assertIsInstance(detector, _FaceDetector)
end

function _assert._expect_keypoints_correct(self, actual_keypoints, expected_keypoints)
    self.assertLen(actual_keypoints, #expected_keypoints)
    for i = 1, #actual_keypoints do
        self.assertAlmostEqual(
            actual_keypoints[i].x,
            expected_keypoints[i].x,
            mediapipe_lua.kwargs({ delta = _KEYPOINT_ERROR_THRESHOLD })
        )
        self.assertAlmostEqual(
            actual_keypoints[i].y,
            expected_keypoints[i].y,
            mediapipe_lua.kwargs({ delta = _KEYPOINT_ERROR_THRESHOLD })
        )
    end
end

function _assert._expect_face_detector_results_correct(
    self, actual_results, expected_results
)
    self.assertLen(actual_results.detections, #expected_results.detections)
    for i = 1, #actual_results.detections do
        local actual_bbox = actual_results.detections[i].bounding_box
        local expected_bbox = expected_results.detections[i].bounding_box
        self.assertEqual(actual_bbox, expected_bbox)
        self.assertNotEmpty(actual_results.detections[i].keypoints)
        self:_expect_keypoints_correct(
            actual_results.detections[i].keypoints,
            expected_results.detections[i].keypoints
        )
    end
end

local function test_detect(self, model_file_type, expected_detection_result_file)
    local base_options

    -- Creates detector.
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

    local options = _FaceDetectorOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local detector = _FaceDetector.create_from_options(options)

    -- Performs face detection on the input.
    local detection_result = detector:detect(self.test_image)

    -- Comparing results.
    local expected_detection_result = _get_expected_face_detector_result(
        expected_detection_result_file
    )
    self:_expect_face_detector_results_correct(
        detection_result, expected_detection_result
    )
end

local function test_detect_succeeds_with_rotated_image(self)
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    local options = _FaceDetectorOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local detector = _FaceDetector.create_from_options(options)

    -- Load the test image.
    local test_image = _Image.create_from_file(
        test_utils.get_test_data_path(_PORTRAIT_ROTATED_IMAGE)
    )

    -- Rotated input image.
    local image_processing_options = _ImageProcessingOptions(mediapipe_lua.kwargs({ rotation_degrees = -90 }))

    -- Performs face detection on the input.
    local detection_result = detector:detect(test_image, image_processing_options)

    -- Comparing results.
    local expected_detection_result = _get_expected_face_detector_result(
        _PORTRAIT_ROTATED_EXPECTED_DETECTION
    )
    self:_expect_face_detector_results_correct(
        detection_result, expected_detection_result
    )
end

local function test_empty_detection_outputs(self)
    -- Load a test image with no faces.
    local test_image = _Image.create_from_file(
        test_utils.get_test_data_path(_CAT_IMAGE)
    )
    local options = _FaceDetectorOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    }))
    local detector = _FaceDetector.create_from_options(options)

    -- Performs face detection on the input.
    local detection_result = detector:detect(test_image)

    self.assertEmpty(detection_result.detections)
end

local function test_detect_for_video(
    self,
    model_file_type,
    test_image_file_name,
    rotation_degrees,
    expected_detection_result
)
    local base_options

    -- Creates detector.
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

    local options = _FaceDetectorOptions(mediapipe_lua.kwargs({
        base_options = base_options, running_mode = _RUNNING_MODE.VIDEO
    }))

    local detector = _FaceDetector.create_from_options(options)
    for timestamp = 0, 300 - 30, 30 do
        -- Load the test image.
        local test_image = _Image.create_from_file(
            test_utils.get_test_data_path(test_image_file_name)
        )

        -- Set the image processing options.
        local image_processing_options = _ImageProcessingOptions(mediapipe_lua.kwargs({
            rotation_degrees = rotation_degrees
        }))

        -- Performs face detection on the input.
        local detection_result = detector:detect_for_video(
            test_image, timestamp, image_processing_options
        )

        -- Comparing results.
        self:_expect_face_detector_results_correct(
            detection_result, expected_detection_result
        )
    end
end

local function test_detect_async_calls(
    self,
    model_file_type,
    test_image_file_name,
    rotation_degrees,
    expected_detection_result
)
    local base_options

    -- Creates detector.
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

    local observed_timestamp_ms = -1

    local function check_result(
        result,
        unused_output_image, ---@diagnostic disable-line: unused-local
        timestamp_ms
    )
        self:_expect_face_detector_results_correct(
            result, expected_detection_result
        )
        self.assertLess(observed_timestamp_ms, timestamp_ms)
        observed_timestamp_ms = timestamp_ms
    end

    local options = _FaceDetectorOptions(mediapipe_lua.kwargs({
        base_options = base_options,
        running_mode = _RUNNING_MODE.LIVE_STREAM,
        result_callback = check_result,
    }))

    -- Load the test image.
    local test_image = _Image.create_from_file(
        test_utils.get_test_data_path(test_image_file_name)
    )

    local detector = _FaceDetector.create_from_options(options)
    for timestamp = 0, 300 - 30, 30 do
        -- Set the image processing options.
        local image_processing_options = _ImageProcessingOptions(mediapipe_lua.kwargs({
            rotation_degrees = rotation_degrees
        }))
        detector:detect_async(test_image, timestamp, image_processing_options)
        mediapipe_lua.notifyCallbacks()
    end

    -- wait for detection end
    detector:close()
    mediapipe_lua.notifyCallbacks()

    self.assertEqual(observed_timestamp_ms, 300 - 30)
end

describe("FaceDetectorTest", function()
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
        { ModelFileType.FILE_NAME,    _PORTRAIT_EXPECTED_DETECTION },
        { ModelFileType.FILE_CONTENT, _PORTRAIT_EXPECTED_DETECTION },
    }) do
        it("should test_detect " .. _, function()
            test_detect(_assert, unpack(args))
        end)
    end

    it("should test_detect_succeeds_with_rotated_image", function()
        test_detect_succeeds_with_rotated_image(_assert)
    end)

    it("should test_empty_detection_outputs", function()
        test_empty_detection_outputs(_assert)
    end)

    for _, args in ipairs({
        {
            ModelFileType.FILE_NAME,
            _PORTRAIT_IMAGE,
            0,
            _get_expected_face_detector_result(_PORTRAIT_EXPECTED_DETECTION),
        },
        {
            ModelFileType.FILE_CONTENT,
            _PORTRAIT_IMAGE,
            0,
            _get_expected_face_detector_result(_PORTRAIT_EXPECTED_DETECTION),
        },
        {
            ModelFileType.FILE_NAME,
            _PORTRAIT_ROTATED_IMAGE,
            -90,
            _get_expected_face_detector_result(
                _PORTRAIT_ROTATED_EXPECTED_DETECTION
            ),
        },
        {
            ModelFileType.FILE_CONTENT,
            _PORTRAIT_ROTATED_IMAGE,
            -90,
            _get_expected_face_detector_result(
                _PORTRAIT_ROTATED_EXPECTED_DETECTION
            ),
        },
        { ModelFileType.FILE_NAME,    _CAT_IMAGE, 0, FaceDetectorResult({}) },
        { ModelFileType.FILE_CONTENT, _CAT_IMAGE, 0, FaceDetectorResult({}) },
    }) do
        it("should test_detect_for_video " .. _, function()
            test_detect_for_video(_assert, unpack(args))
        end)
    end

    for _, args in ipairs({
        {
            ModelFileType.FILE_NAME,
            _PORTRAIT_IMAGE,
            0,
            _get_expected_face_detector_result(_PORTRAIT_EXPECTED_DETECTION),
        },
        {
            ModelFileType.FILE_CONTENT,
            _PORTRAIT_IMAGE,
            0,
            _get_expected_face_detector_result(_PORTRAIT_EXPECTED_DETECTION),
        },
        {
            ModelFileType.FILE_NAME,
            _PORTRAIT_ROTATED_IMAGE,
            -90,
            _get_expected_face_detector_result(
                _PORTRAIT_ROTATED_EXPECTED_DETECTION
            ),
        },
        {
            ModelFileType.FILE_CONTENT,
            _PORTRAIT_ROTATED_IMAGE,
            -90,
            _get_expected_face_detector_result(
                _PORTRAIT_ROTATED_EXPECTED_DETECTION
            ),
        },
        { ModelFileType.FILE_NAME,    _CAT_IMAGE, 0, FaceDetectorResult({}) },
        { ModelFileType.FILE_CONTENT, _CAT_IMAGE, 0, FaceDetectorResult({}) },
    }) do
        it("should test_detect_async_calls " .. _, function()
            test_detect_async_calls(_assert, unpack(args))
        end)
    end
end)
