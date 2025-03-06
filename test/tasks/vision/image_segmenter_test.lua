#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/tasks/python/test/vision/image_segmenter_test.py
--]]

local unpack = table.unpack or unpack ---@diagnostic disable-line: deprecated
local INDEX_BASE = 1 -- lua is 1-based indexed

local _assert = require("_assert")
local test_utils = require("test_utils")

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe

local opencv_lua = require("opencv_lua")
local cv2 = opencv_lua.cv

local image_module = mediapipe.lua._framework_bindings.image
local image_frame = mediapipe.lua._framework_bindings.image_frame
local base_options_module = mediapipe.tasks.lua.core.base_options
local image_segmenter = mediapipe.tasks.lua.vision.image_segmenter
local vision_task_running_mode = mediapipe.tasks.lua.vision.core.vision_task_running_mode

local _BaseOptions = base_options_module.BaseOptions
local _Image = image_module.Image
local _ImageFormat = image_frame.ImageFormat
local _ImageSegmenter = image_segmenter.ImageSegmenter
local _ImageSegmenterOptions = image_segmenter.ImageSegmenterOptions
local _RUNNING_MODE = vision_task_running_mode.VisionTaskRunningMode

local _MODEL_FILE = 'deeplabv3.tflite'
local _IMAGE_FILE = 'segmentation_input_rotation0.jpg'
local _SEGMENTATION_FILE = 'segmentation_golden_rotation0.png'
local _CAT_IMAGE = 'cat.jpg'
local _CAT_MASK = 'cat_mask.jpg'
local _MASK_MAGNIFICATION_FACTOR = 10
local _MASK_SIMILARITY_THRESHOLD = 0.98
local _TEST_DATA_DIR = test_utils.get_resource_dir() .. '/mediapipe/tasks/testdata/vision'
local _EXPECTED_LABELS = {
    'background',
    'aeroplane',
    'bicycle',
    'bird',
    'boat',
    'bottle',
    'bus',
    'car',
    'cat',
    'chair',
    'cow',
    'dining table',
    'dog',
    'horse',
    'motorbike',
    'person',
    'potted plant',
    'sheep',
    'sofa',
    'train',
    'tv',
}

local function _calculate_sum(m)
    local sum = 0.0
    local s = cv2.sumElems(m)
    for _, value in ipairs(s) do
        sum = sum + value
    end
    return sum
end

local function _calculate_soft_iou(m1, m2)
    local intersection_sum = _calculate_sum(m1 * m2)
    local union_sum = _calculate_sum(m1 * m1) + _calculate_sum(m2 * m2) - intersection_sum

    if union_sum > 0 then
        return intersection_sum / union_sum
    else
        return 0
    end
end

function _assert._similar_to_float_mask(self, actual_mask, expected_mask, similarity_threshold)
    actual_mask = actual_mask:mat_view()
    expected_mask = expected_mask:mat_view():convertTo(cv2.CV_32F, opencv_lua.kwargs({alpha = 1 / 255.0}))

    self.assertListEqual(actual_mask.shape, expected_mask.shape)
    self.assertGreater(_calculate_soft_iou(actual_mask, expected_mask), similarity_threshold)
end

local function _similar_to_uint8_mask(actual_mask, expected_mask, similarity_threshold)
    local actual_mask_pixels = actual_mask:mat_view():convertTo(-1,
        opencv_lua.kwargs({ alpha = _MASK_MAGNIFICATION_FACTOR }))
    local expected_mask_pixels = expected_mask:mat_view()

    local num_pixels = expected_mask_pixels:total()
    local consistent_pixels = num_pixels - cv2.countNonZero(cv2.absdiff(actual_mask_pixels, expected_mask_pixels):reshape(1))

    return consistent_pixels / num_pixels >= similarity_threshold
end

local ModelFileType = {
    FILE_CONTENT = 1,
    FILE_NAME = 2,
}

local function setUp(self)
    test_utils.download_test_files(_TEST_DATA_DIR, {
        {
            file = _MODEL_FILE,
            url = "https://storage.googleapis.com/mediapipe-models/image_segmenter/deeplab_v3/float32/1/deeplab_v3.tflite",
        },
        _IMAGE_FILE,
        _SEGMENTATION_FILE,
        _CAT_IMAGE,
        _CAT_MASK,
    })

    -- Load the test input image.
    self.test_image = _Image.create_from_file(
        test_utils.get_test_data_path(_IMAGE_FILE)
    )
    -- Loads ground truth segmentation file.
    local gt_segmentation_data = cv2.imread(
        test_utils.get_test_data_path(_SEGMENTATION_FILE),
        cv2.IMREAD_GRAYSCALE
    )
    self.test_seg_image = _Image(_ImageFormat.GRAY8, gt_segmentation_data)
    self.model_path = test_utils.get_test_data_path(_MODEL_FILE)
end

function _assert._load_segmentation_mask(file_path)
    -- Loads ground truth segmentation file.
    local gt_segmentation_data = cv2.imread(
        test_utils.get_test_data_path(file_path),
        cv2.IMREAD_GRAYSCALE
    )
    return _Image(_ImageFormat.GRAY8, gt_segmentation_data)
end

local function test_create_from_file_succeeds_with_valid_model_path(self)
    -- Creates with default option and valid model file successfully.
    local segmenter = _ImageSegmenter.create_from_model_path(self.model_path)
    self.assertIsInstance(segmenter, _ImageSegmenter)
end

local function test_create_from_options_succeeds_with_valid_model_path(self)
    -- Creates with options containing model file successfully.
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    local options = _ImageSegmenterOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local segmenter = _ImageSegmenter.create_from_options(options)
    self.assertIsInstance(segmenter, _ImageSegmenter)
end

local function test_create_from_options_succeeds_with_valid_model_content(self)
    -- Creates with options containing model content successfully.
    local f = io.open(self.model_path, 'rb')
    local model_content = f:read('*all')
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_buffer = model_content }))
    local options = _ImageSegmenterOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local segmenter = _ImageSegmenter.create_from_options(options)
    self.assertIsInstance(segmenter, _ImageSegmenter)
end

local function test_segment_succeeds_with_category_mask(self, model_file_type)
    local base_options

    -- Creates segmenter.
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

    local options = _ImageSegmenterOptions(mediapipe_lua.kwargs({
        base_options = base_options,
        output_category_mask = true,
        output_confidence_masks = false
    }))
    local segmenter = _ImageSegmenter.create_from_options(options)

    -- Performs image segmentation on the input.
    local segmentation_result = segmenter:segment(self.test_image)
    local category_mask = segmentation_result.category_mask
    local result_pixels = category_mask:mat_view():clone():reshape(1, 1) -- reshape needs a continuous matrix, clone to the make matrix continous

    -- Check if data type of `category_mask` is correct.
    self.assertEqual(result_pixels:depth(), cv2.CV_8U)

    self.assertTrue(
        _similar_to_uint8_mask(category_mask, self.test_seg_image, _MASK_SIMILARITY_THRESHOLD),
        (
            'Number of pixels in the candidate mask differing from that of the' ..
            ' ground truth mask exceeds ' .. _MASK_SIMILARITY_THRESHOLD .. '.'
        )
    )
end

local function test_segment_succeeds_with_confidence_mask(self)
    -- Creates segmenter.
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))

    -- Load the cat image.
    local test_image = _Image.create_from_file(
        test_utils.get_test_data_path(_CAT_IMAGE)
    )

    -- Run segmentation on the model in CONFIDENCE_MASK mode.
    local options = _ImageSegmenterOptions(mediapipe_lua.kwargs({
        base_options = base_options,
        output_category_mask = false,
        output_confidence_masks = true,
    }))

    local segmenter = _ImageSegmenter.create_from_options(options)
    local segmentation_result = segmenter:segment(test_image)
    local confidence_masks = segmentation_result.confidence_masks

    -- Check if confidence mask shape is correct.
    self.assertLen(
        confidence_masks,
        21,
        'Number of confidence masks must match with number of categories.'
    )

    -- Loads ground truth segmentation file.
    local expected_mask = self._load_segmentation_mask(_CAT_MASK)

    self:_similar_to_float_mask(
        confidence_masks[8 + INDEX_BASE], expected_mask, _MASK_SIMILARITY_THRESHOLD
    )
end

local function test_labels_succeeds(self, output_category_mask, output_confidence_masks)
    local expected_labels = _EXPECTED_LABELS
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    local options = _ImageSegmenterOptions(mediapipe_lua.kwargs({
        base_options = base_options,
        output_category_mask = output_category_mask,
        output_confidence_masks = output_confidence_masks,
    }))
    local segmenter = _ImageSegmenter.create_from_options(options)

    -- Performs image segmentation on the input.
    local actual_labels = segmenter.labels
    self.assertListEqual(actual_labels, expected_labels)
end

local function test_segment_for_video_in_category_mask_mode(self)
    local options = _ImageSegmenterOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
        output_category_mask = true,
        output_confidence_masks = false,
        running_mode = _RUNNING_MODE.VIDEO,
    }))
    local segmenter = _ImageSegmenter.create_from_options(options)

    for timestamp = 0, 300 - 30, 30 do
        local segmentation_result = segmenter:segment_for_video(
            self.test_image, timestamp
        )
        local category_mask = segmentation_result.category_mask
        self.assertTrue(
            _similar_to_uint8_mask(category_mask, self.test_seg_image, _MASK_SIMILARITY_THRESHOLD),
            (
                'Number of pixels in the candidate mask differing from that of' ..
                ' the ground truth mask exceeds ' .. _MASK_SIMILARITY_THRESHOLD .. '.'
            )
        )
    end
end

local function test_segment_for_video_in_confidence_mask_mode(self)
    -- Load the cat image.
    local test_image = _Image.create_from_file(
        test_utils.get_test_data_path(_CAT_IMAGE)
    )

    local options = _ImageSegmenterOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
        running_mode = _RUNNING_MODE.VIDEO,
        output_category_mask = false,
        output_confidence_masks = true,
    }))
    local segmenter = _ImageSegmenter.create_from_options(options)

    for timestamp = 0, 300 - 30, 30 do
        local segmentation_result = segmenter:segment_for_video(test_image, timestamp)
        local confidence_masks = segmentation_result.confidence_masks

        -- Check if confidence mask shape is correct.
        self.assertLen(
            confidence_masks,
            21,
            'Number of confidence masks must match with number of categories.'
        )

        -- Loads ground truth segmentation file.
        local expected_mask = self._load_segmentation_mask(_CAT_MASK)
        self:_similar_to_float_mask(
            confidence_masks[8 + INDEX_BASE], expected_mask, _MASK_SIMILARITY_THRESHOLD
        )
    end
end

local function test_segment_async_calls_in_category_mask_mode(self)
    local observed_timestamp_ms = -1

    local function check_result(result, output_image, timestamp_ms)
        -- Get the output category mask.
        local category_mask = result.category_mask
        self.assertEqual(output_image.width, self.test_image.width)
        self.assertEqual(output_image.height, self.test_image.height)
        self.assertEqual(output_image.width, self.test_seg_image.width)
        self.assertEqual(output_image.height, self.test_seg_image.height)
        self.assertTrue(
            _similar_to_uint8_mask(category_mask, self.test_seg_image, _MASK_SIMILARITY_THRESHOLD),
            (
                'Number of pixels in the candidate mask differing from that of' ..
                ' the ground truth mask exceeds ' .. _MASK_SIMILARITY_THRESHOLD .. '.'
            )
        )
        self.assertLess(observed_timestamp_ms, timestamp_ms)
        observed_timestamp_ms = timestamp_ms
    end

    local options = _ImageSegmenterOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
        output_category_mask = true,
        output_confidence_masks = false,
        running_mode = _RUNNING_MODE.LIVE_STREAM,
        result_callback = check_result,
    }))
    local segmenter = _ImageSegmenter.create_from_options(options)

    for timestamp = 0, 300 - 30, 30 do
        segmenter:segment_async(self.test_image, timestamp)
        mediapipe_lua.notifyCallbacks()
    end

    -- wait for detection end
    segmenter:close()
    mediapipe_lua.notifyCallbacks()

    self.assertEqual(observed_timestamp_ms, 300 - 30)
end

local function test_segment_async_calls_in_confidence_mask_mode(self)
    -- Load the cat image.
    local test_image = _Image.create_from_file(
        test_utils.get_test_data_path(_CAT_IMAGE)
    )

    -- Loads ground truth segmentation file.
    local expected_mask = self._load_segmentation_mask(_CAT_MASK)
    local observed_timestamp_ms = -1

    local function check_result(result, output_image, timestamp_ms)
        -- Get the output category mask.
        local confidence_masks = result.confidence_masks

        -- Check if confidence mask shape is correct.
        self.assertLen(
            confidence_masks,
            21,
            'Number of confidence masks must match with number of categories.'
        )
        self.assertEqual(output_image.width, test_image.width)
        self.assertEqual(output_image.height, test_image.height)
        self:_similar_to_float_mask(
            confidence_masks[8 + INDEX_BASE], expected_mask, _MASK_SIMILARITY_THRESHOLD
        )
        self.assertLess(observed_timestamp_ms, timestamp_ms)
        observed_timestamp_ms = timestamp_ms
    end

    local options = _ImageSegmenterOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
        running_mode = _RUNNING_MODE.LIVE_STREAM,
        output_category_mask = false,
        output_confidence_masks = true,
        result_callback = check_result,
    }))

    local segmenter = _ImageSegmenter.create_from_options(options)

    for timestamp = 0, 300 - 30, 30 do
        segmenter:segment_async(test_image, timestamp)
        mediapipe_lua.notifyCallbacks()
    end

    -- wait for detection end
    segmenter:close()
    mediapipe_lua.notifyCallbacks()

    self.assertEqual(observed_timestamp_ms, 300 - 30)
end

describe("ImageSegmenterTest", function()
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
        { ModelFileType.FILE_NAME },
        { ModelFileType.FILE_CONTENT },
    }) do
        it("should test_segment_succeeds_with_category_mask " .. _, function()
            test_segment_succeeds_with_category_mask(_assert, unpack(args))
        end)
    end

    it("should test_segment_succeeds_with_confidence_mask", function()
        test_segment_succeeds_with_confidence_mask(_assert)
    end)

    for _, args in ipairs({
        { true,  false },
        -- { false, true },
    }) do
        it("should test_labels_succeeds " .. _, function()
            test_labels_succeeds(_assert, unpack(args))
        end)
    end

    it("should test_segment_for_video_in_category_mask_mode", function()
        test_segment_for_video_in_category_mask_mode(_assert)
    end)

    it("should test_segment_for_video_in_confidence_mask_mode", function()
        test_segment_for_video_in_confidence_mask_mode(_assert)
    end)

    it("should test_segment_async_calls_in_category_mask_mode", function()
        test_segment_async_calls_in_category_mask_mode(_assert)
    end)

    it("should test_segment_async_calls_in_confidence_mask_mode", function()
        test_segment_async_calls_in_confidence_mask_mode(_assert)
    end)
end)
