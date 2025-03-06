#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/tasks/python/test/vision/face_aligner_test.py
--]]

local unpack = table.unpack or unpack ---@diagnostic disable-line: deprecated

local _assert = require("_assert")
local test_utils = require("test_utils")

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe

local image_module = mediapipe.lua._framework_bindings.image
local rect = mediapipe.tasks.lua.components.containers.rect
local base_options_module = mediapipe.tasks.lua.core.base_options
local face_aligner = mediapipe.tasks.lua.vision.face_aligner
local image_processing_options_module = mediapipe.tasks.lua.vision.core.image_processing_options

local _BaseOptions = base_options_module.BaseOptions
local _Rect = rect.Rect
local _Image = image_module.Image
local _FaceAligner = face_aligner.FaceAligner
local _FaceAlignerOptions = face_aligner.FaceAlignerOptions
local _ImageProcessingOptions = image_processing_options_module.ImageProcessingOptions

local _MODEL = 'face_landmarker_v2.task'
local _LARGE_FACE_IMAGE = 'portrait.jpg'
local _MODEL_IMAGE_SIZE = 256

local _TEST_DATA_DIR = test_utils.get_resource_dir() .. '/mediapipe/tasks/testdata/vision'

local ModelFileType = {
    FILE_CONTENT = 1,
    FILE_NAME = 2,
}

local function setUp(self)
    test_utils.download_test_files(_TEST_DATA_DIR, {
        _MODEL,
        _LARGE_FACE_IMAGE,
    })
    self.model_path = test_utils.get_test_data_path(_MODEL)
end

local function test_create_from_file_succeeds_with_valid_model_path(self)
    -- Creates with default option and valid model file successfully.
    local aligner = _FaceAligner.create_from_model_path(self.model_path)
    self.assertIsInstance(aligner, _FaceAligner)
end

local function test_create_from_options_succeeds_with_valid_model_path(self)
    -- Creates with options containing model file successfully.
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    local options = _FaceAlignerOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local aligner = _FaceAligner.create_from_options(options)
    self.assertIsInstance(aligner, _FaceAligner)
end

local function test_create_from_options_succeeds_with_valid_model_content(self)
    -- Creates with options containing model content successfully.
    local f = io.open(self.model_path, 'rb')
    local model_content = f:read('*all')
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_buffer = model_content }))
    local options = _FaceAlignerOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local aligner = _FaceAligner.create_from_options(options)
    self.assertIsInstance(aligner, _FaceAligner)
end

local function test_align(self, model_file_type, image_file_name)
    local base_options

    -- Load the test image.
    local test_image = _Image.create_from_file(
        test_utils.get_test_data_path(image_file_name)
    )

    -- Creates aligner.
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

    local options = _FaceAlignerOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local aligner = _FaceAligner.create_from_options(options)

    -- Performs face alignment on the input.
    local aligned_image = aligner:align(test_image)
    self.assertIsInstance(aligned_image, _Image)
end

local function test_align_succeeds_with_region_of_interest(self)
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    local options = _FaceAlignerOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local aligner = _FaceAligner.create_from_options(options)

    -- Load the test image.
    local test_image = _Image.create_from_file(
        test_utils.get_test_data_path(_LARGE_FACE_IMAGE)
    )

    -- Region-of-interest around the face.
    local roi = _Rect(mediapipe_lua.kwargs({ left = 0.32, top = 0.02, right = 0.67, bottom = 0.32 }))
    local image_processing_options = _ImageProcessingOptions(roi)

    -- Performs face alignment on the input.
    local aligned_image = aligner:align(test_image, image_processing_options)

    self.assertIsInstance(aligned_image, _Image)
    self.assertEqual(aligned_image.width, _MODEL_IMAGE_SIZE)
    self.assertEqual(aligned_image.height, _MODEL_IMAGE_SIZE)
end

local function test_align_succeeds_with_no_face_detected(self)
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    local options = _FaceAlignerOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local aligner = _FaceAligner.create_from_options(options)

    -- Load the test image.
    local test_image = _Image.create_from_file(
        test_utils.get_test_data_path(_LARGE_FACE_IMAGE)
    )

    -- Region-of-interest that doesn't contain a human face.
    local roi = _Rect(mediapipe_lua.kwargs({ left = 0.1, top = 0.1, right = 0.2, bottom = 0.2 }))
    local image_processing_options = _ImageProcessingOptions(roi)

    -- Performs face alignment on the input.
    local aligned_image = aligner:align(test_image, image_processing_options)

    self.assertIsNone(aligned_image)
end

describe("FaceAlignerTest", function()
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
        { ModelFileType.FILE_NAME,    _LARGE_FACE_IMAGE },
        { ModelFileType.FILE_CONTENT, _LARGE_FACE_IMAGE },
    }) do
        it("should test_align " .. _, function()
            test_align(_assert, unpack(args))
        end)
    end

    it("should test_align_succeeds_with_region_of_interest", function()
        test_align_succeeds_with_region_of_interest(_assert)
    end)

    it("should test_align_succeeds_with_no_face_detected", function()
        test_align_succeeds_with_no_face_detected(_assert)
    end)
end)
