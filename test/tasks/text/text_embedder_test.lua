#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/tasks/python/test/text/text_embedder_test.py
--]]

local unpack = table.unpack or unpack ---@diagnostic disable-line: deprecated
local INDEX_BASE = 1 -- lua is 1-based indexed

local _assert = require("_assert")
local test_utils = require("test_utils")

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe

local opencv_lua = require("opencv_lua")
local cv2 = opencv_lua.cv

local embedding_result_module = mediapipe.tasks.lua.components.containers.embedding_result
local base_options_module = mediapipe.tasks.lua.core.base_options
local text_embedder = mediapipe.tasks.lua.text.text_embedder

_BaseOptions = base_options_module.BaseOptions
_Embedding = embedding_result_module.Embedding
_TextEmbedder = text_embedder.TextEmbedder
_TextEmbedderOptions = text_embedder.TextEmbedderOptions

local _BERT_MODEL_FILE = 'mobilebert_embedding_with_metadata.tflite'
local _REGEX_MODEL_FILE = 'regex_one_embedding_with_metadata.tflite'
local _USE_MODEL_FILE = 'universal_sentence_encoder_qa_with_metadata.tflite'
local _TEST_DATA_DIR = test_utils.get_resource_dir() .. '/mediapipe/tasks/testdata/text'
-- Tolerance for embedding vector coordinate values.
local _EPSILON = 1e-4
-- Tolerance for cosine similarity evaluation.
local _SIMILARITY_TOLERANCE = 1e-3

local ModelFileType = {
    FILE_CONTENT = 1,
    FILE_NAME = 2,
}

local function setUp(self)
    test_utils.download_test_files(_TEST_DATA_DIR, {
        _BERT_MODEL_FILE,
        _REGEX_MODEL_FILE,
        _USE_MODEL_FILE,
    })
    self.model_path = test_utils.get_test_data_path(_BERT_MODEL_FILE)
end

local function test_create_from_file_succeeds_with_valid_model_path(self)
    -- Creates with default option and valid model file successfully.
    local embedder = _TextEmbedder.create_from_model_path(self.model_path)
    self.assertIsInstance(embedder, _TextEmbedder)
end

local function test_create_from_options_succeeds_with_valid_model_path(self)
    -- Creates with options containing model file successfully.
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    local options = _TextEmbedderOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local embedder = _TextEmbedder.create_from_options(options)
    self.assertIsInstance(embedder, _TextEmbedder)
end

local function test_create_from_options_succeeds_with_valid_model_content(self)
    -- Creates with options containing model content successfully.
    local f = io.open(self.model_path, 'rb')
    local model_content = f:read('*all')
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_buffer = model_content }))
    local options = _TextEmbedderOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local embedder = _TextEmbedder.create_from_options(options)
    self.assertIsInstance(embedder, _TextEmbedder)
end

function _assert._check_embedding_value(self, result, expected_first_value)
    -- Check embedding first value.
    self.assertAlmostEqual(
        result.embeddings[0 + INDEX_BASE].embedding[0], expected_first_value,
        mediapipe_lua.kwargs({ delta = _EPSILON }))
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

function _assert._check_cosine_similarity(self, result0, result1, expected_similarity)
    -- Checks cosine similarity.
    local similarity = _TextEmbedder.cosine_similarity(result0.embeddings[0 + INDEX_BASE],
        result1.embeddings[0 + INDEX_BASE])
    self.assertAlmostEqual(
        similarity, expected_similarity, mediapipe_lua.kwargs({ delta = _SIMILARITY_TOLERANCE }))
end

local function test_embed(self, l2_normalize, quantize, model_name, model_file_type,
                          expected_similarity, expected_size, expected_first_values)
    local base_options

    -- Creates embedder.
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

    local options = _TextEmbedderOptions(mediapipe_lua.kwargs({
        base_options = base_options, l2_normalize = l2_normalize, quantize = quantize }))
    local embedder = _TextEmbedder.create_from_options(options)

    -- Extracts both embeddings.
    local positive_text0 = "it's a charming and often affecting journey"
    local positive_text1 = 'what a great and fantastic trip'

    local result0 = embedder:embed(positive_text0)
    local result1 = embedder:embed(positive_text1)

    -- Checks embeddings and cosine similarity.
    local expected_result0_value, expected_result1_value = unpack(expected_first_values)
    self:_check_embedding_size(result0, quantize, expected_size)
    self:_check_embedding_size(result1, quantize, expected_size)
    self:_check_embedding_value(result0, expected_result0_value)
    self:_check_embedding_value(result1, expected_result1_value)
    self:_check_cosine_similarity(result0, result1, expected_similarity)
end

local function test_embed_with_different_themes(self, model_file, expected_similarity)
    -- Creates embedder.
    local model_path = test_utils.get_test_data_path(model_file)
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = model_path }))
    local options = _TextEmbedderOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local embedder = _TextEmbedder.create_from_options(options)

    -- Extracts both embeddings.
    local text0 = (
        'When you go to this restaurant, they hold the pancake upside-down ' ..
        "before they hand it to you. It's a great gimmick."
    )
    local result0 = embedder:embed(text0)

    local text1 = "Let's make a plan to steal the declaration of independence."
    local result1 = embedder:embed(text1)

    local similarity = _TextEmbedder.cosine_similarity(
        result0.embeddings[0 + INDEX_BASE], result1.embeddings[0 + INDEX_BASE]
    )

    self.assertAlmostEqual(
        similarity, expected_similarity, mediapipe_lua.kwargs({ delta = _SIMILARITY_TOLERANCE })
    )
end

describe("TextEmbedderTest", function()
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
            _BERT_MODEL_FILE,
            ModelFileType.FILE_NAME,
            0.962427,
            512,
            { 21.2054, 19.684337 },
        },
        {
            true,
            false,
            _BERT_MODEL_FILE,
            ModelFileType.FILE_NAME,
            0.962427,
            512,
            { 0.0625787, 0.0673937 },
        },
        {
            false,
            false,
            _REGEX_MODEL_FILE,
            ModelFileType.FILE_NAME,
            0.999937,
            16,
            { 0.0309356, 0.0312863 },
        },
        {
            true,
            false,
            _REGEX_MODEL_FILE,
            ModelFileType.FILE_CONTENT,
            0.999937,
            16,
            { 0.549632, 0.552879 },
        },
        {
            false,
            false,
            _USE_MODEL_FILE,
            ModelFileType.FILE_NAME,
            0.851961,
            100,
            { 1.422951, 1.404664 },
        },
        {
            true,
            false,
            _USE_MODEL_FILE,
            ModelFileType.FILE_CONTENT,
            0.851961,
            100,
            { 0.127049, 0.125416 },
        },
    }) do
        it("should test_embed " .. _, function()
            test_embed(_assert, unpack(args))
        end)
    end

    for _, args in ipairs({
        -- TODO: The similarity should likely be lower
        { _BERT_MODEL_FILE, 0.98077 },
        { _USE_MODEL_FILE,  0.780334 },
    }) do
        it("should test_embed_with_different_themes " .. _, function()
            test_embed_with_different_themes(_assert, unpack(args))
        end)
    end
end)
