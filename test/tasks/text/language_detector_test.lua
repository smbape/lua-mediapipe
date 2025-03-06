#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
        arg[0]:gsub("[^/\\]+%.lua", '../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/tasks/python/test/text/language_detector_test.py
--]]

local unpack = table.unpack or unpack ---@diagnostic disable-line: deprecated

local _assert = require("_assert")
local test_utils = require("test_utils")

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe

local base_options_module = mediapipe.tasks.lua.core.base_options
local language_detector = mediapipe.tasks.lua.text.language_detector

local LanguageDetectorResult = language_detector.LanguageDetectorResult
local LanguageDetectorPrediction = language_detector.LanguageDetectorResult.Detection
local _BaseOptions = base_options_module.BaseOptions
local _LanguageDetector = language_detector.LanguageDetector
local _LanguageDetectorOptions = language_detector.LanguageDetectorOptions

local _LANGUAGE_DETECTOR_MODEL = "language_detector.tflite"
local _TEST_DATA_DIR = test_utils.get_resource_dir() .. "/mediapipe/tasks/testdata/text"

local _SCORE_THRESHOLD = 0.3
local _EN_TEXT = "To be, or not to be, that is the question"
local _EN_EXPECTED_RESULT = LanguageDetectorResult(
    { LanguageDetectorPrediction("en", 0.999856) }
)
local _FR_TEXT = (
    "Il y a beaucoup de bouches qui parlent et fort peu de têtes qui pensent."
)
local _FR_EXPECTED_RESULT = LanguageDetectorResult(
    { LanguageDetectorPrediction("fr", 0.999781) }
)
local _RU_TEXT = "это какой-то английский язык"
local _RU_EXPECTED_RESULT = LanguageDetectorResult(
    { LanguageDetectorPrediction("ru", 0.993362) }
)
local _MIXED_TEXT = "分久必合合久必分"
local _MIXED_EXPECTED_RESULT = LanguageDetectorResult({
    LanguageDetectorPrediction("zh", 0.505424),
    LanguageDetectorPrediction("ja", 0.481617),
})
local _TOLERANCE = 1e-6

local ModelFileType = {
    FILE_CONTENT = 1,
    FILE_NAME = 2,
}

local function setUp(self)
    test_utils.download_test_files(_TEST_DATA_DIR, {
        _LANGUAGE_DETECTOR_MODEL,
    })
    self.model_path = test_utils.get_test_data_path(_LANGUAGE_DETECTOR_MODEL)
end

function _assert._expect_language_detector_result_correct(
    self,
    actual_result,
    expect_result
)
    for i, prediction in ipairs(actual_result.detections) do
        local expected_prediction = expect_result.detections[i]
        self.assertEqual(
            prediction.language_code,
            expected_prediction.language_code
        )
        self.assertAlmostEqual(
            prediction.probability,
            expected_prediction.probability,
            mediapipe_lua.kwargs({ delta = _TOLERANCE })
        )
    end
end

local function test_create_from_file_succeeds_with_valid_model_path(self)
    -- Creates with default option and valid model file successfully.
    local detector = _LanguageDetector.create_from_model_path(self.model_path)
    self.assertIsInstance(detector, _LanguageDetector)
end

local function test_create_from_options_succeeds_with_valid_model_path(self)
    -- Creates with options containing model file successfully.
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    local options = _LanguageDetectorOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local detector = _LanguageDetector.create_from_options(options)
    self.assertIsInstance(detector, _LanguageDetector)
end

local function test_create_from_options_succeeds_with_valid_model_content(self)
    -- Creates with options containing model content successfully.
    local f = io.open(self.model_path, 'rb')
    local model_content = f:read('*all')
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_buffer = model_content }))
    local options = _LanguageDetectorOptions(mediapipe_lua.kwargs({ base_options = base_options }))
    local detector = _LanguageDetector.create_from_options(options)
    self.assertIsInstance(detector, _LanguageDetector)
end

local function test_detect(self, model_file_type, text, expected_result)
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
        error("model_file_type is invalid.")
    end

    local options = _LanguageDetectorOptions(mediapipe_lua.kwargs({
        base_options = base_options, score_threshold = _SCORE_THRESHOLD
    }))
    local detector = _LanguageDetector.create_from_options(options)

    -- Performs language detection on the input.
    local text_result = detector:detect(text)

    -- Comparing results.
    self:_expect_language_detector_result_correct(text_result, expected_result)
end

local function test_allowlist_option(self)
    -- Creates detector.
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    local options = _LanguageDetectorOptions(mediapipe_lua.kwargs({
        base_options = base_options,
        score_threshold = _SCORE_THRESHOLD,
        category_allowlist = { "ja" },
    }))
    local detector = _LanguageDetector.create_from_options(options)

    -- Performs language detection on the input.
    local text_result = detector:detect(_MIXED_TEXT)

    -- Comparing results.
    local expected_result = LanguageDetectorResult(
        { LanguageDetectorPrediction("ja", 0.481617) }
    )
    self:_expect_language_detector_result_correct(text_result, expected_result)
end

local function test_denylist_option(self)
    -- Creates detector.
    local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
    local options = _LanguageDetectorOptions(mediapipe_lua.kwargs({
        base_options = base_options,
        score_threshold = _SCORE_THRESHOLD,
        category_denylist = { "ja" },
    }))
    local detector = _LanguageDetector.create_from_options(options)

    -- Performs language detection on the input.
    local text_result = detector:detect(_MIXED_TEXT)

    -- Comparing results.
    local expected_result = LanguageDetectorResult(
        { LanguageDetectorPrediction("zh", 0.505424) }
    )
    self:_expect_language_detector_result_correct(text_result, expected_result)
end

describe("LanguageDetectorTest", function()
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
        { ModelFileType.FILE_NAME,    _EN_TEXT,    _EN_EXPECTED_RESULT },
        { ModelFileType.FILE_CONTENT, _EN_TEXT,    _EN_EXPECTED_RESULT },
        { ModelFileType.FILE_NAME,    _FR_TEXT,    _FR_EXPECTED_RESULT },
        { ModelFileType.FILE_CONTENT, _FR_TEXT,    _FR_EXPECTED_RESULT },
        { ModelFileType.FILE_NAME,    _RU_TEXT,    _RU_EXPECTED_RESULT },
        { ModelFileType.FILE_CONTENT, _RU_TEXT,    _RU_EXPECTED_RESULT },
        { ModelFileType.FILE_NAME,    _MIXED_TEXT, _MIXED_EXPECTED_RESULT },
        { ModelFileType.FILE_CONTENT, _MIXED_TEXT, _MIXED_EXPECTED_RESULT },
    }) do
        it("should test_detect " .. _, function()
            test_detect(_assert, unpack(args))
        end)
    end

    it("should test_allowlist_option", function()
        test_allowlist_option(_assert)
    end)

    it("should test_denylist_option", function()
        test_denylist_option(_assert)
    end)
end)
