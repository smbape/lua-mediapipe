#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/tasks/python/test/vision/interactive_segmenter_test.py
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
local keypoint_module = mediapipe.tasks.lua.components.containers.keypoint
local base_options_module = mediapipe.tasks.lua.core.base_options
local interactive_segmenter = mediapipe.tasks.lua.vision.interactive_segmenter
local image_processing_options_module = mediapipe.tasks.lua.vision.core.image_processing_options

local _BaseOptions = base_options_module.BaseOptions
local _Image = image_module.Image
local _ImageFormat = image_frame.ImageFormat
local _NormalizedKeypoint = keypoint_module.NormalizedKeypoint
local _InteractiveSegmenter = interactive_segmenter.InteractiveSegmenter
local _InteractiveSegmenterOptions = interactive_segmenter.InteractiveSegmenterOptions
local _RegionOfInterest = interactive_segmenter.RegionOfInterest
local _ImageProcessingOptions = image_processing_options_module.ImageProcessingOptions

local _MODEL_FILE = 'ptm_512_hdt_ptm_woid.tflite'
local _CATS_AND_DOGS = 'cats_and_dogs.jpg'
local _CATS_AND_DOGS_MASK_DOG_1 = 'cats_and_dogs_mask_dog1.png'
local _CATS_AND_DOGS_MASK_DOG_2 = 'cats_and_dogs_mask_dog2.png'
local _MASK_MAGNIFICATION_FACTOR = 255
local _MASK_SIMILARITY_THRESHOLD = 0.97
local _TEST_DATA_DIR = test_utils.get_resource_dir() .. '/mediapipe/tasks/testdata/vision'

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
    expected_mask = expected_mask:mat_view():convertTo(cv2.CV_32F, opencv_lua.kwargs({ alpha = 1 / 255.0 }))

    self.assertListEqual(actual_mask.shape, expected_mask.shape)
    self.assertGreater(_calculate_soft_iou(actual_mask, expected_mask), similarity_threshold)
end

local function _similar_to_uint8_mask(actual_mask, expected_mask, similarity_threshold)
    local actual_mask_pixels = actual_mask:mat_view():convertTo(-1,
        opencv_lua.kwargs({ alpha = _MASK_MAGNIFICATION_FACTOR }))
    local expected_mask_pixels = expected_mask:mat_view()

    local num_pixels = expected_mask_pixels:total()
    local consistent_pixels = num_pixels -
        cv2.countNonZero(cv2.absdiff(actual_mask_pixels, expected_mask_pixels):reshape(1))

    return consistent_pixels / num_pixels >= similarity_threshold
end

local ModelFileType = {
    FILE_CONTENT = 1,
    FILE_NAME = 2,
}

local function setUp(self)
    test_utils.download_test_files(_TEST_DATA_DIR, {
        _MODEL_FILE,
        _CATS_AND_DOGS,
        _CATS_AND_DOGS_MASK_DOG_1,
        _CATS_AND_DOGS_MASK_DOG_2,
    })

    -- Load the test input image.
    self.test_image = _Image.create_from_file(
        test_utils.get_test_data_path(_CATS_AND_DOGS)
    )
    -- Loads ground truth segmentation file.
    self.test_seg_image = self._load_segmentation_mask(
        _CATS_AND_DOGS_MASK_DOG_1
    )
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
    local segmenter = _InteractiveSegmenter.create_from_model_path(self.model_path)
    self.assertIsInstance(segmenter, _InteractiveSegmenter)
end

local function test_create_from_options_succeeds_with_valid_model_path(self)
    -- Creates with options containing model file successfully.
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    local options = _InteractiveSegmenterOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local segmenter = _InteractiveSegmenter.create_from_options(options)
    self.assertIsInstance(segmenter, _InteractiveSegmenter)
end

local function test_create_from_options_succeeds_with_valid_model_content(self)
    -- Creates with options containing model content successfully.
    local f = io.open(self.model_path, 'rb')
    local model_content = f:read('*all')
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_buffer = model_content }))
    local options = _InteractiveSegmenterOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local segmenter = _InteractiveSegmenter.create_from_options(options)
    self.assertIsInstance(segmenter, _InteractiveSegmenter)
end

local function test_segment_succeeds_with_category_mask(
    self,
    model_file_type,
    roi_format,
    keypoint,
    output_mask,
    similarity_threshold
)
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

    local options = _InteractiveSegmenterOptions(mediapipe_lua.kwargs({
        base_options = base_options,
        output_category_mask = true,
        output_confidence_masks = false,
    }))
    local segmenter = _InteractiveSegmenter.create_from_options(options)

    -- Performs image segmentation on the input.
    local roi = _RegionOfInterest(mediapipe_lua.kwargs({ format = roi_format, keypoint = keypoint }))
    local segmentation_result = segmenter:segment(self.test_image, roi)
    local category_mask = segmentation_result.category_mask
    local result_pixels = category_mask:mat_view():clone():reshape(1, 1) -- reshape needs a continuous matrix, clone to the make matrix continous

    -- Check if data type of `category_mask` is correct.
    self.assertEqual(result_pixels:depth(), cv2.CV_8U)

    -- Loads ground truth segmentation file.
    local test_seg_image = self._load_segmentation_mask(output_mask)

    self.assertTrue(
        _similar_to_uint8_mask(
            category_mask, test_seg_image, similarity_threshold
        ),
        (
            'Number of pixels in the candidate mask differing from that of the' ..
            ' ground truth mask exceeds ' .. similarity_threshold .. '.'
        )
    )
end

local function test_segment_succeeds_with_confidence_mask(
    self, roi_format, keypoint, output_mask, similarity_threshold
)
    -- Creates segmenter.
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    local roi = _RegionOfInterest(mediapipe_lua.kwargs({ format = roi_format, keypoint = keypoint }))

    -- Run segmentation on the model in CONFIDENCE_MASK mode.
    local options = _InteractiveSegmenterOptions(mediapipe_lua.kwargs({
        base_options = base_options,
        output_category_mask = false,
        output_confidence_masks = true,
    }))

    local segmenter = _InteractiveSegmenter.create_from_options(options)

    -- Perform segmentation
    local segmentation_result = segmenter:segment(self.test_image, roi)
    local confidence_masks = segmentation_result.confidence_masks

    -- Check if confidence mask shape is correct.
    self.assertLen(
        confidence_masks,
        2,
        'Number of confidence masks must match with number of categories.'
    )

    -- Loads ground truth segmentation file.
    local expected_mask = self._load_segmentation_mask(output_mask)

    self:_similar_to_float_mask(
        confidence_masks[1 + INDEX_BASE], expected_mask, similarity_threshold
    )
end

local function test_segment_succeeds_with_rotation(self)
    -- Creates segmenter.
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    local roi = _RegionOfInterest(mediapipe_lua.kwargs({
        format = _RegionOfInterest.Format.KEYPOINT,
        keypoint = _NormalizedKeypoint(0.66, 0.66),
    }))

    -- Run segmentation on the model in CONFIDENCE_MASK mode.
    local options = _InteractiveSegmenterOptions(mediapipe_lua.kwargs({
        base_options = base_options,
        output_category_mask = false,
        output_confidence_masks = true,
    }))

    local segmenter = _InteractiveSegmenter.create_from_options(options)

    -- Perform segmentation
    local image_processing_options = _ImageProcessingOptions(mediapipe_lua.kwargs({ rotation_degrees = -90 }))
    local segmentation_result = segmenter:segment(
        self.test_image, roi, image_processing_options
    )
    local confidence_masks = segmentation_result.confidence_masks

    -- Check if confidence mask shape is correct.
    self.assertLen(
        confidence_masks,
        2,
        'Number of confidence masks must match with number of categories.'
    )
end

describe("InteractiveSegmenterTest", function()
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
            _RegionOfInterest.Format.KEYPOINT,
            _NormalizedKeypoint(0.44, 0.7),
            _CATS_AND_DOGS_MASK_DOG_1,
            0.84,
        },
        {
            ModelFileType.FILE_CONTENT,
            _RegionOfInterest.Format.KEYPOINT,
            _NormalizedKeypoint(0.44, 0.7),
            _CATS_AND_DOGS_MASK_DOG_1,
            0.84,
        },
        {
            ModelFileType.FILE_NAME,
            _RegionOfInterest.Format.KEYPOINT,
            _NormalizedKeypoint(0.66, 0.66),
            _CATS_AND_DOGS_MASK_DOG_2,
            _MASK_SIMILARITY_THRESHOLD,
        },
        {
            ModelFileType.FILE_CONTENT,
            _RegionOfInterest.Format.KEYPOINT,
            _NormalizedKeypoint(0.66, 0.66),
            _CATS_AND_DOGS_MASK_DOG_2,
            _MASK_SIMILARITY_THRESHOLD,
        },
    }) do
        it("should test_segment_succeeds_with_category_mask " .. _, function()
            test_segment_succeeds_with_category_mask(_assert, unpack(args))
        end)
    end

    for _, args in ipairs({
        {
            _RegionOfInterest.Format.KEYPOINT,
            _NormalizedKeypoint(0.44, 0.7),
            _CATS_AND_DOGS_MASK_DOG_1,
            0.84,
        },
        {
            _RegionOfInterest.Format.KEYPOINT,
            _NormalizedKeypoint(0.66, 0.66),
            _CATS_AND_DOGS_MASK_DOG_2,
            _MASK_SIMILARITY_THRESHOLD,
        },
    }) do
        it("should test_segment_succeeds_with_confidence_mask " .. _, function()
            test_segment_succeeds_with_confidence_mask(_assert, unpack(args))
        end)
    end

    it("should test_segment_succeeds_with_rotation", function()
        test_segment_succeeds_with_rotation(_assert)
    end)
end)
