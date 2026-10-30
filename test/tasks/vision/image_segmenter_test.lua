#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v1.0.0/mediapipe/tasks/python/test/vision/image_segmenter_test.py
--]]

local unpack = table.unpack or unpack ---@diagnostic disable-line: deprecated

local _assert = require("_assert")
local test_utils = require("test_utils")

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe
local std = mediapipe_lua.std

local opencv_lua = require("opencv_lua")
local cv2 = opencv_lua.cv

local base_options_module = mediapipe.tasks.lua.core.base_options
local image_segmenter = mediapipe.tasks.lua.vision.image_segmenter
local image_module = mediapipe.tasks.lua.vision.core.image
local vision_task_running_mode = mediapipe.tasks.lua.vision.core.vision_task_running_mode

local _BaseOptions = base_options_module.BaseOptions
local _Image = image_module.Image
local _ImageFormat = image_module.ImageFormat
local _ImageSegmenter = image_segmenter.ImageSegmenter
local _ImageSegmenterOptions = image_segmenter.ImageSegmenterOptions
local _RUNNING_MODE = vision_task_running_mode.VisionTaskRunningMode

local _MODEL_FILE = 'deeplabv3.tflite'
local _MODEL_FILE_HASH = 'sha256=5faed2c653905d3e22a8f6f29ee198da84e9b0e7936a207bf431f17f6b4d87ff'
local _MODEL_FILE_URL = 'https://storage.googleapis.com/mediapipe-assets/tasks/testdata/vision/deeplabv3.tflite?generation=1782184557689389'
local _IMAGE_FILE = 'segmentation_input_rotation0.jpg'
local _IMAGE_FILE_HASH = 'sha256=5bf58d8af1f1c33224f3f3bc0ce451c8daf0739cc15a86d59d8c3bf2879afb97'
local _IMAGE_FILE_URL = 'https://storage.googleapis.com/mediapipe-assets/tasks/testdata/vision/segmentation_input_rotation0.jpg?generation=1782185296406038'
local _SEGMENTATION_FILE = 'segmentation_golden_rotation0.png'
local _SEGMENTATION_FILE_HASH = 'sha256=9ee993919b753118928ba2d14f7c5c83a6cfc23355e6943dac4ad81eedd73069'
local _SEGMENTATION_FILE_URL = 'https://storage.googleapis.com/mediapipe-assets/tasks/testdata/vision/segmentation_golden_rotation0.png?generation=1782185289166865'
local _CAT_IMAGE = 'cat.jpg'
local _CAT_IMAGE_HASH = 'sha256=2533197401eebe9410ea4d063f86c43fbd2666f3e8165a38aca155c0d09c21be'
local _CAT_IMAGE_URL = 'https://storage.googleapis.com/mediapipe-assets/tasks/testdata/vision/cat.jpg?generation=1782184446508641'
local _CAT_MASK = 'cat_mask.jpg'
local _CAT_MASK_HASH = 'sha256=bae065a685f2d32f1856151b5181671aa4d09925b55766935a30bbc8dafadcd0'
local _CAT_MASK_URL = 'https://storage.googleapis.com/mediapipe-assets/tasks/testdata/vision/cat_mask.jpg?generation=1782184468570584'
local _CAT_EXIF_ROTATED = 'cat_exif_rotated.jpg'
local _CAT_EXIF_ROTATED_HASH = 'sha256=ef4db9449df5359edb22b48d3cd864280835a9d427dd461ec843b097b6551871'
local _CAT_EXIF_ROTATED_URL = 'https://storage.googleapis.com/mediapipe-assets/tasks/testdata/vision/cat_exif_rotated.jpg?generation=1783975275171154'
local _CAT_ROTATED_MASK = 'cat_rotated_mask.jpg'
local _CAT_ROTATED_MASK_HASH = 'sha256=f336973e7621d602f2ebc9a6ab1c62d8502272d391713f369d3b99541afda861'
local _CAT_ROTATED_MASK_URL = 'https://storage.googleapis.com/mediapipe-assets/tasks/testdata/vision/cat_rotated_mask.jpg?generation=1782184483853970'
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
    self.assertIsNotNone(actual_mask, 'Result mask used for comparison was None')
    actual_mask = actual_mask:mat_view()
    expected_mask = expected_mask:mat_view():convertTo(cv2.CV_32F, opencv_lua.kwargs({ alpha = 1 / 255.0 }))

    self.assertListEqual(actual_mask.shape, expected_mask.shape)
    self.assertGreater(_calculate_soft_iou(actual_mask, expected_mask), similarity_threshold)
end

function _assert._similar_to_uint8_mask(self, actual_mask, expected_mask, similarity_threshold)
    self.assertIsNotNone(actual_mask, 'Result mask used for comparison was None')
    local actual_mask_pixels = actual_mask:mat_view():convertTo(-1, opencv_lua.kwargs({ alpha = _MASK_MAGNIFICATION_FACTOR }))
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
            output = _MODEL_FILE,
            hash = _MODEL_FILE_HASH,
            url = _MODEL_FILE_URL,
        },
        {
            output = _IMAGE_FILE,
            hash = _IMAGE_FILE_HASH,
            url = _IMAGE_FILE_URL,
        },
        {
            output = _SEGMENTATION_FILE,
            hash = _SEGMENTATION_FILE_HASH,
            url = _SEGMENTATION_FILE_URL,
        },
        {
            output = _CAT_IMAGE,
            hash = _CAT_IMAGE_HASH,
            url = _CAT_IMAGE_URL,
        },
        {
            output = _CAT_MASK,
            hash = _CAT_MASK_HASH,
            url = _CAT_MASK_URL,
        },
        {
            output = _CAT_EXIF_ROTATED,
            hash = _CAT_EXIF_ROTATED_HASH,
            url = _CAT_EXIF_ROTATED_URL,
        },
        {
            output = _CAT_ROTATED_MASK,
            hash = _CAT_ROTATED_MASK_HASH,
            url = _CAT_ROTATED_MASK_URL,
        },
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
    segmenter:close()
end

local function test_create_from_options_succeeds_with_valid_model_path(self)
    -- Creates with options containing model file successfully.
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    local options = _ImageSegmenterOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local segmenter = _ImageSegmenter.create_from_options(options)
    self.assertIsInstance(segmenter, _ImageSegmenter)
    segmenter:close()
end

local function test_create_from_options_succeeds_with_valid_model_content(self)
    -- Creates with options containing model content successfully.
    local f = io.open(self.model_path, 'rb')
    local model_content = f:read('*all')
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_buffer = model_content }))
    local options = _ImageSegmenterOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local segmenter = _ImageSegmenter.create_from_options(options)
    self.assertIsInstance(segmenter, _ImageSegmenter)
    segmenter:close()
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
    self.assertIsNotNone(category_mask, 'Result category mask was None')
    local result_pixels = category_mask:mat_view():clone():reshape(1, 1) -- reshape needs a continuous matrix, clone to the make matrix continous

    -- Check if data type of `category_mask` is correct.
    self.assertEqual(result_pixels:depth(), cv2.CV_8U)

    self.assertTrue(
        self:_similar_to_uint8_mask(category_mask, self.test_seg_image, _MASK_SIMILARITY_THRESHOLD),
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
        confidence_masks[8], expected_mask, _MASK_SIMILARITY_THRESHOLD
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
            self:_similar_to_uint8_mask(category_mask, self.test_seg_image, _MASK_SIMILARITY_THRESHOLD),
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
            confidence_masks[8], expected_mask, _MASK_SIMILARITY_THRESHOLD
        )
    end
end

local function test_segment_async_calls_in_category_mask_mode(self)
    local observed_timestamp_ms = -1

    local callback_event = test_utils.threading.Event()

    local function check_result(result, output_image, timestamp_ms)
        -- Get the output category mask.
        local category_mask = result.category_mask
        self.assertEqual(output_image.width, self.test_image.width)
        self.assertEqual(output_image.height, self.test_image.height)
        self.assertEqual(output_image.width, self.test_seg_image.width)
        self.assertEqual(output_image.height, self.test_seg_image.height)
        self.assertTrue(
            self:_similar_to_uint8_mask(category_mask, self.test_seg_image, _MASK_SIMILARITY_THRESHOLD),
            (
                'Number of pixels in the candidate mask differing from that of' ..
                ' the ground truth mask exceeds ' .. _MASK_SIMILARITY_THRESHOLD .. '.'
            )
        )

        if timestamp_ms ~= mediapipe.Timestamp.DONE then
            self.assertLessEqual(observed_timestamp_ms, timestamp_ms)
            observed_timestamp_ms = timestamp_ms
        end

        callback_event:set()
    end

    local options = _ImageSegmenterOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
        output_category_mask = true,
        output_confidence_masks = false,
        running_mode = _RUNNING_MODE.LIVE_STREAM,
        result_callback = check_result,
    }))
    local segmenter = _ImageSegmenter.create_from_options(options)

    local now = std.chrono.steady_clock.now()
    for timestamp = 0, 300 - 30, 30 do
        if timestamp > 0 then
            std.this_thread.sleep_until(now + std.chrono.milliseconds(timestamp))
        end

        segmenter:segment_async(self.test_image, timestamp)

        callback_event:wait(3000)
    end

    -- wait for segmentation end
    segmenter:close()

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

    local callback_event = test_utils.threading.Event()

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
            confidence_masks[8], expected_mask, _MASK_SIMILARITY_THRESHOLD
        )

        if timestamp_ms ~= mediapipe.Timestamp.DONE then
            self.assertLessEqual(observed_timestamp_ms, timestamp_ms)
            observed_timestamp_ms = timestamp_ms
        end

        callback_event:set()
    end

    local options = _ImageSegmenterOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
        running_mode = _RUNNING_MODE.LIVE_STREAM,
        output_category_mask = false,
        output_confidence_masks = true,
        result_callback = check_result,
    }))

    local segmenter = _ImageSegmenter.create_from_options(options)

    local now = std.chrono.steady_clock.now()
    for timestamp = 0, 300 - 30, 30 do
        if timestamp > 0 then
            std.this_thread.sleep_until(now + std.chrono.milliseconds(timestamp))
        end

        segmenter:segment_async(test_image, timestamp)

        callback_event:wait(3000)
    end

    -- wait for segmentation end
    segmenter:close()

    self.assertEqual(observed_timestamp_ms, 300 - 30)
end

local function test_segmentation_with_exif_rotated_image(self)
    -- Load the EXIF rotated cat image.
    local test_image = _Image.create_from_file(
        test_utils.get_test_data_path(_CAT_EXIF_ROTATED)
    )
    -- Check that dimensions are correctly swapped
    self.assertEqual(test_image.width, 400)
    self.assertEqual(test_image.height, 600)

    -- Loads EXIF rotated ground truth segmentation file.
    local expected_mask = self._load_segmentation_mask(_CAT_ROTATED_MASK)

    local options = _ImageSegmenterOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
        running_mode = _RUNNING_MODE.IMAGE,
        output_category_mask = false,
        output_confidence_masks = true,
    }))

    local segmenter = _ImageSegmenter.create_from_options(options)

    local result = segmenter:segment(test_image)
    local confidence_masks = result.confidence_masks
    self.assertLen(confidence_masks, 21)
    self:_similar_to_float_mask(
        confidence_masks[8], expected_mask, _MASK_SIMILARITY_THRESHOLD
    )
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
        { true, false },
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

    it("should test_segmentation_with_exif_rotated_image", function()
        test_segmentation_with_exif_rotated_image(_assert)
    end)
end)
