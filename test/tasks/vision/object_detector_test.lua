#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
        arg[0]:gsub("[^/\\]+%.lua", '../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/tasks/python/test/vision/object_detector_test.py
--]]

local unpack = table.unpack or unpack ---@diagnostic disable-line: deprecated
local INDEX_BASE = 1 -- lua is 1-based indexed

local _assert = require("_assert")
local _mat_utils = require("_mat_utils") ---@diagnostic disable-line: unused-local
local test_utils = require("test_utils")

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe

local image_module = mediapipe.lua._framework_bindings.image
local bounding_box_module = mediapipe.tasks.lua.components.containers.bounding_box
local category_module = mediapipe.tasks.lua.components.containers.category
local detections_module = mediapipe.tasks.lua.components.containers.detections
local base_options_module = mediapipe.tasks.lua.core.base_options
local object_detector = mediapipe.tasks.lua.vision.object_detector
local running_mode_module = mediapipe.tasks.lua.vision.core.vision_task_running_mode

local _BaseOptions = base_options_module.BaseOptions
local _Category = category_module.Category
local _BoundingBox = bounding_box_module.BoundingBox
local _Detection = detections_module.Detection
local _DetectionResult = detections_module.DetectionResult
local _Image = image_module.Image
local _ObjectDetector = object_detector.ObjectDetector
local _ObjectDetectorOptions = object_detector.ObjectDetectorOptions

local _RUNNING_MODE = running_mode_module.VisionTaskRunningMode

local _MODEL_FILE = 'coco_ssd_mobilenet_v1_1.0_quant_2018_06_29.tflite'
local _NO_NMS_MODEL_FILE = 'efficientdet_lite0_fp16_no_nms.tflite'
local _IMAGE_FILE = 'cats_and_dogs.jpg'
local _EXPECTED_DETECTION_RESULT = _DetectionResult(mediapipe_lua.kwargs({
    detections = {
        _Detection(mediapipe_lua.kwargs({
            bounding_box = _BoundingBox(mediapipe_lua.kwargs({
                origin_x = 608,
                origin_y = 164,
                width = 381,
                height = 432,
            })),
            categories = {
                _Category(mediapipe_lua.kwargs({
                    index = nil,
                    score = 0.69921875,
                    display_name = nil,
                    category_name = 'cat',
                }))
            },
        })),
        _Detection(mediapipe_lua.kwargs({
            bounding_box = _BoundingBox(mediapipe_lua.kwargs({
                origin_x = 57,
                origin_y = 398,
                width = 386,
                height = 196,
            })),
            categories = {
                _Category(mediapipe_lua.kwargs({
                    index = nil,
                    score = 0.65625,
                    display_name = nil,
                    category_name = 'cat',
                }))
            },
        })),
        _Detection(mediapipe_lua.kwargs({
            bounding_box = _BoundingBox(mediapipe_lua.kwargs({
                origin_x = 256,
                origin_y = 394,
                width = 173,
                height = 202,
            })),
            categories = {
                _Category(mediapipe_lua.kwargs({
                    index = nil,
                    score = 0.51171875,
                    display_name = nil,
                    category_name = 'cat',
                }))
            },
        })),
        _Detection(mediapipe_lua.kwargs({
            bounding_box = _BoundingBox(mediapipe_lua.kwargs({
                origin_x = 360,
                origin_y = 195,
                width = 330,
                height = 412,
            })),
            categories = {
                _Category(mediapipe_lua.kwargs({
                    index = nil,
                    score = 0.48828125,
                    display_name = nil,
                    category_name = 'cat',
                }))
            },
        })),
    }
}))
local _ALLOW_LIST = { 'cat', 'dog' }
local _DENY_LIST = { 'cat' }
local _SCORE_THRESHOLD = 0.3
local _MAX_RESULTS = 3
local _TEST_DATA_DIR = test_utils.get_resource_dir() .. '/mediapipe/tasks/testdata/vision'

local ModelFileType = {
    FILE_CONTENT = 1,
    FILE_NAME = 2,
}

local function setUp(self)
    test_utils.download_test_files(_TEST_DATA_DIR, {
        _MODEL_FILE,
        _NO_NMS_MODEL_FILE,
        _IMAGE_FILE,
    })

    self.test_image = _Image.create_from_file(
        test_utils.get_test_data_path(_IMAGE_FILE)
    )
    self.model_path = test_utils.get_test_data_path(_MODEL_FILE)
end

local function test_create_from_file_succeeds_with_valid_model_path(self)
    -- Creates with default option and valid model file successfully.
    local detector = _ObjectDetector.create_from_model_path(self.model_path)
    self.assertIsInstance(detector, _ObjectDetector)
end

local function test_create_from_options_succeeds_with_valid_model_path(self)
    -- Creates with options containing model file successfully.
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    local options = _ObjectDetectorOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local detector = _ObjectDetector.create_from_options(options)
    self.assertIsInstance(detector, _ObjectDetector)
end

local function test_create_from_options_succeeds_with_valid_model_content(self)
    -- Creates with options containing model content successfully.
    local f = io.open(self.model_path, 'rb')
    local model_content = f:read('*all')
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_buffer = model_content }))
    local options = _ObjectDetectorOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local detector = _ObjectDetector.create_from_options(options)
    self.assertIsInstance(detector, _ObjectDetector)
end

local function test_detect(
    self, model_file_type, max_results, expected_detection_result
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

    local options = _ObjectDetectorOptions(mediapipe_lua.kwargs({
        base_options = base_options, max_results = max_results
    }))
    local detector = _ObjectDetector.create_from_options(options)

    -- Performs object detection on the input.
    local detection_result = detector:detect(self.test_image)

    -- Comparing results.
    self.assertEqual(detection_result, expected_detection_result)
end

local function test_score_threshold_option(self)
    local options = _ObjectDetectorOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
        score_threshold = _SCORE_THRESHOLD,
    }))
    local detector = _ObjectDetector.create_from_options(options)

    -- Performs object detection on the input.
    local detection_result = detector:detect(self.test_image)
    local detections = detection_result.detections

    for _, detection in ipairs(detections) do
        local score = detection.categories[0 + INDEX_BASE].score
        self.assertGreaterEqual(
            score,
            _SCORE_THRESHOLD,
            'Detection with score lower than threshold found. ' .. tostring(detection)
        )
    end
end

local function test_max_results_option(self)
    local options = _ObjectDetectorOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
        max_results = _MAX_RESULTS,
    }))
    local detector = _ObjectDetector.create_from_options(options)

    -- Performs object detection on the input.
    local detection_result = detector:detect(self.test_image)
    local detections = detection_result.detections

    self.assertLessEqual(
        #detections, _MAX_RESULTS, 'Too many results returned.'
    )
end

local function test_allow_list_option(self)
    local options = _ObjectDetectorOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
        category_allowlist = _ALLOW_LIST,
    }))
    local detector = _ObjectDetector.create_from_options(options)

    -- Performs object detection on the input.
    local detection_result = detector:detect(self.test_image)
    local detections = detection_result.detections

    for _, detection in ipairs(detections) do
        local label = detection.categories[0 + INDEX_BASE].category_name
        self.assertIn(
            label,
            _ALLOW_LIST,
            'Label ' .. label .. ' found but not in label allow list'
        )
    end
end

local function test_deny_list_option(self)
    local options = _ObjectDetectorOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
        category_denylist = _DENY_LIST,
    }))
    local detector = _ObjectDetector.create_from_options(options)

    -- Performs object detection on the input.
    local detection_result = detector:detect(self.test_image)
    local detections = detection_result.detections

    for _, detection in ipairs(detections) do
        local label = detection.categories[0 + INDEX_BASE].category_name
        self.assertNotIn(
            label, _DENY_LIST, 'Label ' .. label .. ' found but in deny list.'
        )
    end
end

local function test_empty_detection_outputs_with_in_model_nms(self)
    local options = _ObjectDetectorOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
        score_threshold = 1,
    }))
    local detector = _ObjectDetector.create_from_options(options)

    -- Performs object detection on the input.
    local detection_result = detector:detect(self.test_image)

    self.assertEmpty(detection_result.detections)
end

local function test_empty_detection_outputs_without_in_model_nms(self)
    local options = _ObjectDetectorOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({
            model_asset_path = test_utils.get_test_data_path(_NO_NMS_MODEL_FILE) })),
        score_threshold = 1,
    }))
    local detector = _ObjectDetector.create_from_options(options)

    -- Performs object detection on the input.
    local detection_result = detector:detect(self.test_image)

    self.assertEmpty(detection_result.detections)
end

-- TODO: Tests how `detect_for_video` handles the temporal data
-- with a real video.
local function test_detect_for_video(self)
    local options = _ObjectDetectorOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
        running_mode = _RUNNING_MODE.VIDEO,
        max_results = 4,
    }))
    local detector = _ObjectDetector.create_from_options(options)
    for timestamp = 0, 300 - 30, 30 do
        local detection_result = detector:detect_for_video(self.test_image, timestamp)
        self.assertEqual(detection_result, _EXPECTED_DETECTION_RESULT)
    end
end

local function test_detect_async_calls(self, threshold, expected_result)
    local observed_timestamp_ms = -1

    local function check_result(result, output_image, timestamp_ms)
        self.assertEqual(result, expected_result)
        self.assertMatEqual(output_image:mat_view(), self.test_image:mat_view())
        self.assertLess(observed_timestamp_ms, timestamp_ms)
        observed_timestamp_ms = timestamp_ms
    end

    local options = _ObjectDetectorOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
        running_mode = _RUNNING_MODE.LIVE_STREAM,
        max_results = 4,
        score_threshold = threshold,
        result_callback = check_result,
    }))
    local detector = _ObjectDetector.create_from_options(options)

    for timestamp = 0, 300 - 30, 30 do
        detector:detect_async(self.test_image, timestamp)
        mediapipe_lua.notifyCallbacks()
    end

    -- wait for detection end
    detector:close()
    mediapipe_lua.notifyCallbacks()

    self.assertEqual(observed_timestamp_ms, 300 - 30)
end

describe("ObjectDetectorTest", function()
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
        { ModelFileType.FILE_NAME,    4, _EXPECTED_DETECTION_RESULT },
        { ModelFileType.FILE_CONTENT, 4, _EXPECTED_DETECTION_RESULT },
    }) do
        it("should test_detect " .. _, function()
            test_detect(_assert, unpack(args))
        end)
    end

    it("should test_score_threshold_option", function()
        test_score_threshold_option(_assert)
    end)

    it("should test_max_results_option", function()
        test_max_results_option(_assert)
    end)

    it("should test_allow_list_option", function()
        test_allow_list_option(_assert)
    end)

    it("should test_deny_list_option", function()
        test_deny_list_option(_assert)
    end)

    it("should test_empty_detection_outputs_with_in_model_nms", function()
        test_empty_detection_outputs_with_in_model_nms(_assert)
    end)

    it("should test_empty_detection_outputs_without_in_model_nms", function()
        test_empty_detection_outputs_without_in_model_nms(_assert)
    end)

    it("should test_detect_for_video", function()
        test_detect_for_video(_assert)
    end)

    for _, args in ipairs({
        { 0, _EXPECTED_DETECTION_RESULT },
        { 1, _DetectionResult(mediapipe_lua.kwargs({ detections = {} })) }
    }) do
        it("should test_detect_async_calls " .. _, function()
            test_detect_async_calls(_assert, unpack(args))
        end)
    end
end)
