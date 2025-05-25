#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
        arg[0]:gsub("[^/\\]+%.lua", '../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/tasks/python/test/text/text_classifier_test.py
--]]

local unpack = table.unpack or unpack ---@diagnostic disable-line: deprecated

local _assert = require("_assert")
local _proto_utils = require("_proto_utils") ---@diagnostic disable-line: unused-local
local test_utils = require("test_utils")

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe

local category = mediapipe.tasks.lua.components.containers.category
local classification_result_module = mediapipe.tasks.lua.components.containers.classification_result
local base_options_module = mediapipe.tasks.lua.core.base_options
local text_classifier = mediapipe.tasks.lua.text.text_classifier

local TextClassifierResult = classification_result_module.ClassificationResult
local _BaseOptions = base_options_module.BaseOptions
local _Category = category.Category
local _Classifications = classification_result_module.Classifications
local _TextClassifier = text_classifier.TextClassifier
local _TextClassifierOptions = text_classifier.TextClassifierOptions

local _BERT_MODEL_FILE = 'bert_text_classifier.tflite'
local _REGEX_MODEL_FILE = 'test_model_text_classifier_with_regex_tokenizer.tflite'
local _TEST_DATA_DIR = test_utils.get_resource_dir() .. '/mediapipe/tasks/testdata/text'

local _NEGATIVE_TEXT = 'What a waste of my time.'
local _POSITIVE_TEXT = ('This is the best movie I’ve seen in recent years.' ..
        'Strongly recommend it!')

local _BERT_NEGATIVE_RESULTS = TextClassifierResult(mediapipe_lua.kwargs({
    classifications = {
        _Classifications(mediapipe_lua.kwargs({
            categories = {
                _Category(mediapipe_lua.kwargs({
                    index = 0,
                    score = 0.9995,
                    display_name = '',
                    category_name = 'negative'
                })),
                _Category(mediapipe_lua.kwargs({
                    index = 1,
                    score = 0.0005,
                    display_name = '',
                    category_name = 'positive'
                }))
            },
            head_index = 0,
            head_name = 'probability'
        }))
    },
    timestamp_ms = 0
}))
local _BERT_POSITIVE_RESULTS = TextClassifierResult(mediapipe_lua.kwargs({
    classifications = {
        _Classifications(mediapipe_lua.kwargs({
            categories = {
                _Category(mediapipe_lua.kwargs({
                    index = 1,
                    score = 0.9995,
                    display_name = '',
                    category_name = 'positive'
                })),
                _Category(mediapipe_lua.kwargs({
                    index = 0,
                    score = 0.0005,
                    display_name = '',
                    category_name = 'negative'
                }))
            },
            head_index = 0,
            head_name = 'probability'
        }))
    },
    timestamp_ms = 0
}))
local _REGEX_NEGATIVE_RESULTS = TextClassifierResult(mediapipe_lua.kwargs({
    classifications = {
        _Classifications(mediapipe_lua.kwargs({
            categories = {
                _Category(mediapipe_lua.kwargs({
                    index = 0,
                    score = 0.81313,
                    display_name = '',
                    category_name = 'Negative'
                })),
                _Category(mediapipe_lua.kwargs({
                    index = 1,
                    score = 0.1868704,
                    display_name = '',
                    category_name = 'Positive'
                }))
            },
            head_index = 0,
            head_name = 'probability'
        }))
    },
    timestamp_ms = 0
}))
local _REGEX_POSITIVE_RESULTS = TextClassifierResult(mediapipe_lua.kwargs({
    classifications = {
        _Classifications(mediapipe_lua.kwargs({
            categories = {
                _Category(mediapipe_lua.kwargs({
                    index = 1,
                    score = 0.5134273,
                    display_name = '',
                    category_name = 'Positive'
                })),
                _Category(mediapipe_lua.kwargs({
                    index = 0,
                    score = 0.486573,
                    display_name = '',
                    category_name = 'Negative'
                }))
            },
            head_index = 0,
            head_name = 'probability'
        }))
    },
    timestamp_ms = 0
}))

local ModelFileType = {
    FILE_CONTENT = 1,
    FILE_NAME = 2,
}

local function setUp(self)
    test_utils.download_test_files(_TEST_DATA_DIR, {
        _BERT_MODEL_FILE,
        _REGEX_MODEL_FILE,
    })
    self.model_path = test_utils.get_test_data_path(_BERT_MODEL_FILE)
end

local function test_create_from_file_succeeds_with_valid_model_path(self)
    -- Creates with default option and valid model file successfully.
    local classifier = _TextClassifier.create_from_model_path(self.model_path)
    self.assertIsInstance(classifier, _TextClassifier)
end

local function test_create_from_options_succeeds_with_valid_model_path(self)
    -- Creates with options containing model file successfully.
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    local options = _TextClassifierOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local classifier = _TextClassifier.create_from_options(options)
    self.assertIsInstance(classifier, _TextClassifier)
end

local function test_create_from_options_succeeds_with_valid_model_content(self)
    -- Creates with options containing model content successfully.
    local f = io.open(self.model_path, 'rb')
    local model_content = f:read('*all')
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_buffer = model_content }))
    local options = _TextClassifierOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local classifier = _TextClassifier.create_from_options(options)
    self.assertIsInstance(classifier, _TextClassifier)
end

local function test_classify(self, model_file_type, model_name, text, expected_classification_result)
    local base_options

    -- Creates classifier.
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

    local options = _TextClassifierOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local classifier = _TextClassifier.create_from_options(options)

    -- Performs text classification on the input.
    local text_result = classifier:classify(text)

    -- Comparing results.
    self.assertProtoEquals(text_result:to_pb2(),
        expected_classification_result:to_pb2())
end

describe("TextClassifierTest", function()
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
        { ModelFileType.FILE_NAME,    _BERT_MODEL_FILE,  _NEGATIVE_TEXT, _BERT_NEGATIVE_RESULTS },
        { ModelFileType.FILE_CONTENT, _BERT_MODEL_FILE,  _NEGATIVE_TEXT, _BERT_NEGATIVE_RESULTS },
        { ModelFileType.FILE_NAME,    _BERT_MODEL_FILE,  _POSITIVE_TEXT, _BERT_POSITIVE_RESULTS },
        { ModelFileType.FILE_CONTENT, _BERT_MODEL_FILE,  _POSITIVE_TEXT, _BERT_POSITIVE_RESULTS },
        { ModelFileType.FILE_NAME,    _REGEX_MODEL_FILE, _NEGATIVE_TEXT, _REGEX_NEGATIVE_RESULTS },
        { ModelFileType.FILE_CONTENT, _REGEX_MODEL_FILE, _NEGATIVE_TEXT, _REGEX_NEGATIVE_RESULTS },
        { ModelFileType.FILE_NAME,    _REGEX_MODEL_FILE, _POSITIVE_TEXT, _REGEX_POSITIVE_RESULTS },
        { ModelFileType.FILE_CONTENT, _REGEX_MODEL_FILE, _POSITIVE_TEXT, _REGEX_POSITIVE_RESULTS },
    }) do
        it("should test_classify " .. _, function()
            test_classify(_assert, unpack(args))
        end)
    end
end)
