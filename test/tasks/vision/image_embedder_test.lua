#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/tasks/python/test/vision/image_embedder_test.py
--]]

local unpack = table.unpack or unpack ---@diagnostic disable-line: deprecated
local INDEX_BASE = 1 -- lua is 1-based indexed

local _assert = require("_assert")
local _mat_utils = require("_mat_utils") ---@diagnostic disable-line: unused-local
local test_utils = require("test_utils")

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe
local std = mediapipe_lua.std

local opencv_lua = require("opencv_lua")
local cv2 = opencv_lua.cv

local image_module = mediapipe.lua._framework_bindings.image
local rect = mediapipe.tasks.lua.components.containers.rect
local base_options_module = mediapipe.tasks.lua.core.base_options
local image_embedder = mediapipe.tasks.lua.vision.image_embedder
local image_processing_options_module = mediapipe.tasks.lua.vision.core.image_processing_options
local running_mode_module = mediapipe.tasks.lua.vision.core.vision_task_running_mode

local _Rect = rect.Rect
local _BaseOptions = base_options_module.BaseOptions
local _Image = image_module.Image
local _ImageEmbedder = image_embedder.ImageEmbedder
local _ImageEmbedderOptions = image_embedder.ImageEmbedderOptions
local _RUNNING_MODE = running_mode_module.VisionTaskRunningMode
local _ImageProcessingOptions = image_processing_options_module.ImageProcessingOptions

local _MODEL_FILE = 'mobilenet_v3_small_100_224_embedder.tflite'
local _BURGER_IMAGE_FILE = 'burger.jpg'
local _BURGER_CROPPED_IMAGE_FILE = 'burger_crop.jpg'

local _TEST_DATA_DIR = test_utils.get_resource_dir() .. '/mediapipe/tasks/testdata/vision'

-- Tolerance for embedding vector coordinate values.
local _EPSILON = 1e-4

-- Tolerance for cosine similarity evaluation.
local _SIMILARITY_TOLERANCE = 1e-6

local ModelFileType = {
    FILE_CONTENT = 1,
    FILE_NAME = 2,
}

local function setUp(self)
    test_utils.download_test_files(_TEST_DATA_DIR, {
        _MODEL_FILE,
        _BURGER_IMAGE_FILE,
        _BURGER_CROPPED_IMAGE_FILE,
    })

    self.test_image = _Image.create_from_file(test_utils.get_test_data_path(_BURGER_IMAGE_FILE))
    self.test_cropped_image = _Image.create_from_file(test_utils.get_test_data_path(_BURGER_CROPPED_IMAGE_FILE))
    self.model_path = test_utils.get_test_data_path(_MODEL_FILE)
end

local function test_create_from_file_succeeds_with_valid_model_path(self)
    -- Creates with default option and valid model file successfully.
    local embedder = _ImageEmbedder.create_from_model_path(self.model_path)
    self.assertIsInstance(embedder, _ImageEmbedder)
end

local function test_create_from_options_succeeds_with_valid_model_path(self)
    -- Creates with options containing model file successfully.
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    local options = _ImageEmbedderOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local embedder = _ImageEmbedder.create_from_options(options)
    self.assertIsInstance(embedder, _ImageEmbedder)
end

local function test_create_from_options_succeeds_with_valid_model_content(self)
    -- Creates with options containing model content successfully.
    local f = io.open(self.model_path, 'rb')
    local model_content = f:read('*all')
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_buffer = model_content }))
    local options = _ImageEmbedderOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local embedder = _ImageEmbedder.create_from_options(options)
    self.assertIsInstance(embedder, _ImageEmbedder)
end

function _assert._check_embedding_value(self, result, expected_first_value)
    -- Check embedding first value.
    self.assertAlmostEqual(
        result.embeddings[0 + INDEX_BASE].embedding[0],
        expected_first_value,
        mediapipe_lua.kwargs({ delta = _EPSILON })
    )
end

function _assert._check_embedding_size(self, result, quantize, expected_embedding_size)
    -- Check embedding size.
    self.assertLen(result.embeddings, 1)
    local embedding_result = result.embeddings[0 + INDEX_BASE]
    self.assertEqual(embedding_result.embedding:total(), expected_embedding_size)
    if quantize then
        self.assertEqual(embedding_result.embedding:depth(), cv2.CV_8U)
    else
        self.assertEqual(embedding_result.embedding:depth(), cv2.CV_32F)
    end
end

-- node scripts/func_kwargs.js _assert _check_cosine_similarity result0 result1 expected_similarity | clip
function _assert._check_cosine_similarity(self, ...)
    local args = { n = select("#", ...), ... }
    local has_kwarg = mediapipe_lua.kwargs.isinstance(args[args.n])
    local kwargs = has_kwarg and args[args.n] or mediapipe_lua.kwargs()
    local usedkw = 0

    -- get argument result0
    local result0
    local has_result0 = false
    if (not has_kwarg) or args.n > 1 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("result0") then
            error("result0 was both specified as a Positional and NamedParameter")
        end
        has_result0 = args.n >= 1
        if has_result0 then
            result0 = args[1]
        end
    elseif kwargs:has("result0") then
        -- named parameter
        has_result0 = true
        result0 = kwargs:get("result0")
        usedkw = usedkw + 1
    else
        error("result0 is mandatory")
    end

    -- get argument result1
    local result1
    local has_result1 = false
    if (not has_kwarg) or args.n > 2 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("result1") then
            error("result1 was both specified as a Positional and NamedParameter")
        end
        has_result1 = args.n >= 2
        if has_result1 then
            result1 = args[2]
        end
    elseif kwargs:has("result1") then
        -- named parameter
        has_result1 = true
        result1 = kwargs:get("result1")
        usedkw = usedkw + 1
    else
        error("result1 is mandatory")
    end

    -- get argument expected_similarity
    local expected_similarity
    local has_expected_similarity = false
    if (not has_kwarg) or args.n > 3 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("expected_similarity") then
            error("expected_similarity was both specified as a Positional and NamedParameter")
        end
        has_expected_similarity = args.n >= 3
        if has_expected_similarity then
            expected_similarity = args[3]
        end
    elseif kwargs:has("expected_similarity") then
        -- named parameter
        has_expected_similarity = true
        expected_similarity = kwargs:get("expected_similarity")
        usedkw = usedkw + 1
    else
        error("expected_similarity is mandatory")
    end

    if usedkw ~= kwargs:size() then
        error("there are " .. (kwargs:size() - usedkw) .. " unknown named parameters")
    end

    --- ====================== ---
    --- CODE LOGIC STARTS HERE ---
    --- ====================== ---

    -- Checks cosine similarity.
    local similarity = _ImageEmbedder.cosine_similarity(result0.embeddings[0 + INDEX_BASE],
        result1.embeddings[0 + INDEX_BASE])
    self.assertAlmostEqual(
        similarity, expected_similarity, mediapipe_lua.kwargs({ delta = _SIMILARITY_TOLERANCE }))
end

local function test_embed(self, l2_normalize, quantize, with_roi, model_file_type,
                          expected_similarity, expected_size, expected_first_values)
    local base_options

    -- Creates embedder.
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

    local options = _ImageEmbedderOptions(mediapipe_lua.kwargs({
        base_options = base_options, l2_normalize = l2_normalize, quantize = quantize }))
    local embedder = _ImageEmbedder.create_from_options(options)

    local image_processing_options = nil
    if with_roi then
        -- Region-of-interest in "burger.jpg" corresponding to "burger_crop.jpg".
        local roi = _Rect(mediapipe_lua.kwargs({ left = 0, top = 0, right = 0.833333, bottom = 1 }))
        image_processing_options = _ImageProcessingOptions(roi)
    end

    -- Extracts both embeddings.
    local image_result = embedder:embed(self.test_image, image_processing_options)
    local crop_result = embedder:embed(self.test_cropped_image)

    -- Checks embeddings and cosine similarity.
    local expected_result0_value, expected_result1_value = unpack(expected_first_values)
    self:_check_embedding_size(image_result, quantize, expected_size)
    self:_check_embedding_size(crop_result, quantize, expected_size)
    self:_check_embedding_value(image_result, expected_result0_value)
    self:_check_embedding_value(crop_result, expected_result1_value)
    self:_check_cosine_similarity(image_result, crop_result,
        expected_similarity)
end

local function test_embed_for_video(self)
    local options = _ImageEmbedderOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
        running_mode = _RUNNING_MODE.VIDEO
    }))
    local embedder0 = _ImageEmbedder.create_from_options(options)
    local embedder1 = _ImageEmbedder.create_from_options(options)

    for timestamp = 0, 300 - 30, 30 do
        -- Extracts both embeddings.
        local image_result = embedder0:embed_for_video(self.test_image, timestamp)
        local crop_result = embedder1:embed_for_video(self.test_cropped_image,
            timestamp)
        -- Checks cosine similarity.
        self:_check_cosine_similarity(
            image_result, crop_result, mediapipe_lua.kwargs({ expected_similarity = 0.925519 }))
    end
end

local function test_embed_for_video_succeeds_with_region_of_interest(self)
    local options = _ImageEmbedderOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
        running_mode = _RUNNING_MODE.VIDEO
    }))
    local embedder0 = _ImageEmbedder.create_from_options(options)
    local embedder1 = _ImageEmbedder.create_from_options(options)

    -- Region-of-interest in "burger.jpg" corresponding to "burger_crop.jpg".
    local roi = _Rect(mediapipe_lua.kwargs({ left = 0, top = 0, right = 0.833333, bottom = 1 }))
    local image_processing_options = _ImageProcessingOptions(roi)

    for timestamp = 0, 300 - 30, 30 do
        -- Extracts both embeddings.
        local image_result = embedder0:embed_for_video(self.test_image, timestamp,
            image_processing_options)
        local crop_result = embedder1:embed_for_video(self.test_cropped_image,
            timestamp)

        -- Checks cosine similarity.
        self:_check_cosine_similarity(
            image_result, crop_result, mediapipe_lua.kwargs({ expected_similarity = 0.999931 }))
    end
end

local function test_embed_async_calls(self)
    -- Get the embedding result for the cropped image.
    local options = _ImageEmbedderOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
        running_mode = _RUNNING_MODE.IMAGE
    }))
    local embedder = _ImageEmbedder.create_from_options(options)
    local crop_result = embedder:embed(self.test_cropped_image)

    local observed_timestamp_ms = -1

    local function check_result(result, output_image, timestamp_ms)
        -- Checks cosine similarity.
        self:_check_cosine_similarity(
            result, crop_result, mediapipe_lua.kwargs({ expected_similarity = 0.925519 }))
        self.assertMatEqual(output_image:mat_view(),
            self.test_image:mat_view())
        self.assertLess(observed_timestamp_ms, timestamp_ms)
        observed_timestamp_ms = timestamp_ms
    end

    local options = _ImageEmbedderOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
        running_mode = _RUNNING_MODE.LIVE_STREAM,
        result_callback = check_result
    }))

    local embedder = _ImageEmbedder.create_from_options(options)

    local now = std.chrono.steady_clock.now()
    for timestamp = 0, 300 - 30, 30 do
        if timestamp > 0 then
            mediapipe_lua.notifyCallbacks()
            std.this_thread.sleep_until(now + std.chrono.milliseconds(timestamp))
        end

        embedder:embed_async(self.test_image, timestamp)
    end

    -- wait for detection end
    embedder:close()
    mediapipe_lua.notifyCallbacks()

    self.assertEqual(observed_timestamp_ms, 300 - 30)
end

local function test_embed_async_succeeds_with_region_of_interest(self)
    -- Get the embedding result for the cropped image.
    local options = _ImageEmbedderOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
        running_mode = _RUNNING_MODE.IMAGE
    }))
    local embedder = _ImageEmbedder.create_from_options(options)
    local crop_result = embedder:embed(self.test_cropped_image)

    -- Region-of-interest in "burger.jpg" corresponding to "burger_crop.jpg".
    local roi = _Rect(mediapipe_lua.kwargs({ left = 0, top = 0, right = 0.833333, bottom = 1 }))
    local image_processing_options = _ImageProcessingOptions(roi)
    local observed_timestamp_ms = -1

    local function check_result(result, output_image, timestamp_ms)
        -- Checks cosine similarity.
        self:_check_cosine_similarity(
            result, crop_result, mediapipe_lua.kwargs({ expected_similarity = 0.999931 }))
        self.assertMatEqual(output_image:mat_view(),
            self.test_image:mat_view())
        self.assertLess(observed_timestamp_ms, timestamp_ms)
        observed_timestamp_ms = timestamp_ms
    end

    local options = _ImageEmbedderOptions(mediapipe_lua.kwargs({
        base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
        running_mode = _RUNNING_MODE.LIVE_STREAM,
        result_callback = check_result
    }))
    local embedder = _ImageEmbedder.create_from_options(options)

    local now = std.chrono.steady_clock.now()
    for timestamp = 0, 300 - 30, 30 do
        if timestamp > 0 then
            mediapipe_lua.notifyCallbacks()
            std.this_thread.sleep_until(now + std.chrono.milliseconds(timestamp))
        end

        embedder:embed_async(self.test_image, timestamp, image_processing_options)
    end

    -- wait for detection end
    embedder:close()
    mediapipe_lua.notifyCallbacks()

    self.assertEqual(observed_timestamp_ms, 300 - 30)
end

describe("ImageEmbedderTest", function()
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
            false,
            false,
            false,
            ModelFileType.FILE_NAME,
            0.925519,
            1024,
            { -0.2101883, -0.193027 },
        },
        {
            true,
            false,
            false,
            ModelFileType.FILE_NAME,
            0.925519,
            1024,
            { -0.0142344, -0.0131606 },
        },
        {
            false,
            true,
            false,
            ModelFileType.FILE_NAME,
            0.926791,
            1024,
            { 229, 231 },
        },
        {
            false,
            false,
            true,
            ModelFileType.FILE_CONTENT,
            0.999931,
            1024,
            { -0.195062, -0.193027 },
        },
    }) do
        it("should test_embed " .. _, function()
            test_embed(_assert, unpack(args))
        end)
    end

    it("should test_embed_for_video", function()
        test_embed_for_video(_assert)
    end)

    it("should test_embed_for_video_succeeds_with_region_of_interest", function()
        test_embed_for_video_succeeds_with_region_of_interest(_assert)
    end)

    it("should test_embed_async_calls", function()
        test_embed_async_calls(_assert)
    end)

    it("should test_embed_async_succeeds_with_region_of_interest", function()
        test_embed_async_succeeds_with_region_of_interest(_assert)
    end)
end)
