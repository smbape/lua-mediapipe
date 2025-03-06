#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
  https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/tasks/python/test/vision/image_classifier_test.py
--]]

local unpack = table.unpack or unpack ---@diagnostic disable-line: deprecated
local INDEX_BASE = 1 -- lua is 1-based indexed

local _assert = require("_assert")
local _mat_utils = require("_mat_utils") ---@diagnostic disable-line: unused-local
local _proto_utils = require("_proto_utils") ---@diagnostic disable-line: unused-local
local test_utils = require("test_utils")

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe

local image = mediapipe.lua._framework_bindings.image
local category_module = mediapipe.tasks.lua.components.containers.category
local classification_result_module = mediapipe.tasks.lua.components.containers.classification_result
local rect = mediapipe.tasks.lua.components.containers.rect
local base_options_module = mediapipe.tasks.lua.core.base_options
local image_classifier = mediapipe.tasks.lua.vision.image_classifier
local image_processing_options_module = mediapipe.tasks.lua.vision.core.image_processing_options
local vision_task_running_mode = mediapipe.tasks.lua.vision.core.vision_task_running_mode

local ImageClassifierResult = classification_result_module.ClassificationResult
local _Rect = rect.Rect
local _BaseOptions = base_options_module.BaseOptions
local _Category = category_module.Category
local _Classifications = classification_result_module.Classifications
local _Image = image.Image
local _ImageClassifier = image_classifier.ImageClassifier
local _ImageClassifierOptions = image_classifier.ImageClassifierOptions
local _RUNNING_MODE = vision_task_running_mode.VisionTaskRunningMode
local _ImageProcessingOptions = image_processing_options_module.ImageProcessingOptions

local _MODEL_FILE = 'mobilenet_v2_1.0_224.tflite'
local _IMAGE_FILE = 'burger.jpg'
local _IMAGE_ROTATED_FILE = 'burger_rotated.jpg'
local _IMAGE_ROI_FILE = 'multi_objects.jpg'
local _IMAGE_ROI_ROTATED_FILE = 'multi_objects_rotated.jpg'
local _ALLOW_LIST = { 'cheeseburger', 'guacamole' }
local _DENY_LIST = { 'cheeseburger' }
local _SCORE_THRESHOLD = 0.5
local _MAX_RESULTS = 3

local _TEST_DATA_DIR = test_utils.get_resource_dir() .. '/mediapipe/tasks/testdata/vision'

local function _generate_empty_results(timestamp_ms)
  if timestamp_ms == nil then
    timestamp_ms = 0
  end

  return ImageClassifierResult(mediapipe_lua.kwargs({
    classifications = {
      _Classifications(mediapipe_lua.kwargs({ categories = {}, head_index = 0, head_name = 'probability' }))
    },
    timestamp_ms = timestamp_ms
  }))
end

local function _generate_burger_results(timestamp_ms)
  if timestamp_ms == nil then
    timestamp_ms = 0
  end

  return ImageClassifierResult(mediapipe_lua.kwargs({
    classifications = {
      _Classifications(mediapipe_lua.kwargs({
        categories = {
          _Category(mediapipe_lua.kwargs({
            index = 934,
            score = 0.793959,
            display_name = '',
            category_name = 'cheeseburger'
          })),
          _Category(mediapipe_lua.kwargs({
            index = 932,
            score = 0.0273929,
            display_name = '',
            category_name = 'bagel'
          })),
          _Category(mediapipe_lua.kwargs({
            index = 925,
            score = 0.0193408,
            display_name = '',
            category_name = 'guacamole'
          })),
          _Category(mediapipe_lua.kwargs({
            index = 963,
            score = 0.00632786,
            display_name = '',
            category_name = 'meat loaf'
          })),
        },
        head_index = 0,
        head_name = 'probability'
      }))
    },
    timestamp_ms = timestamp_ms
  }))
end

local function _generate_soccer_ball_results(timestamp_ms)
  if timestamp_ms == nil then
    timestamp_ms = 0
  end

  return ImageClassifierResult(mediapipe_lua.kwargs({
    classifications = {
      _Classifications(mediapipe_lua.kwargs({
        categories = {
          _Category(mediapipe_lua.kwargs({
            index = 806,
            score = 0.996527,
            display_name = '',
            category_name = 'soccer ball',
          }))
        },
        head_index = 0,
        head_name = 'probability',
      }))
    },
    timestamp_ms = timestamp_ms,
  }))
end

local ModelFileType = {
  FILE_CONTENT = 1,
  FILE_NAME = 2,
}

local function setUp(self)
  test_utils.download_test_files(_TEST_DATA_DIR, {
    _MODEL_FILE,
    _IMAGE_FILE,
    _IMAGE_ROI_FILE,
    _IMAGE_ROTATED_FILE,
    _IMAGE_ROI_ROTATED_FILE,
  })

  self.test_image = _Image.create_from_file(test_utils.get_test_data_path(_IMAGE_FILE))
  self.model_path = test_utils.get_test_data_path(_MODEL_FILE)
end

local function test_create_from_file_succeeds_with_valid_model_path(self)
  -- Creates with default option and valid model file successfully.
  local classifier = _ImageClassifier.create_from_model_path(self.model_path)
  self.assertIsInstance(classifier, _ImageClassifier)
end

local function test_create_from_options_succeeds_with_valid_model_path(self)
  -- Creates with options containing model file successfully.
  local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
  local options = _ImageClassifierOptions(mediapipe_lua.kwargs({ base_options = base_options }))
  local classifier = _ImageClassifier.create_from_options(options)
  self.assertIsInstance(classifier, _ImageClassifier)
end

local function test_create_from_options_succeeds_with_valid_model_content(self)
  -- Creates with options containing model content successfully.
  local f = io.open(self.model_path, 'rb')
  local model_content = f:read('*all')
  local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_buffer = model_content }))
  local options = _ImageClassifierOptions(mediapipe_lua.kwargs({ base_options = base_options }))
  local classifier = _ImageClassifier.create_from_options(options)
  self.assertIsInstance(classifier, _ImageClassifier)
end

local function test_classify(
  self, model_file_type, max_results, expected_classification_result
)
  local base_options

  -- Creates classifier.
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

  local options = _ImageClassifierOptions(mediapipe_lua.kwargs({
    base_options = base_options, max_results = max_results
  }))

  local classifier = _ImageClassifier.create_from_options(options)

  -- Performs image classification on the input.
  local image_result = classifier:classify(self.test_image)

  -- Comparing results.
  self.assertProtoEquals(
    image_result:to_pb2(), expected_classification_result:to_pb2()
  )
end

local function test_classify_succeeds_with_region_of_interest(self)
  local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
  local options = _ImageClassifierOptions(mediapipe_lua.kwargs({ base_options = base_options, max_results = 1 }))
  local classifier = _ImageClassifier.create_from_options(options)

  -- Load the test image.
  local test_image = _Image.create_from_file(
    test_utils.get_test_data_path(_IMAGE_ROI_FILE)
  )

  -- Region-of-interest around the soccer ball.
  local roi = _Rect(mediapipe_lua.kwargs({ left = 0.45, top = 0.3075, right = 0.614, bottom = 0.7345 }))
  local image_processing_options = _ImageProcessingOptions(roi)

  -- Performs image classification on the input.
  local image_result = classifier:classify(test_image, image_processing_options)

  -- Comparing results.
  self.assertProtoEquals(
    image_result:to_pb2(), _generate_soccer_ball_results():to_pb2()
  )
end

local function test_classify_succeeds_with_rotation(self)
  local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
  local options = _ImageClassifierOptions(mediapipe_lua.kwargs({ base_options = base_options, max_results = 3 }))
  local classifier = _ImageClassifier.create_from_options(options)

  -- Load the test image.
  local test_image = _Image.create_from_file(
    test_utils.get_test_data_path(_IMAGE_ROTATED_FILE)
  )

  -- Specify a 90° anti-clockwise rotation.
  local image_processing_options = _ImageProcessingOptions(nil, -90)

  -- Performs image classification on the input.
  local image_result = classifier:classify(test_image, image_processing_options)

  -- Comparing results.
  local expected = ImageClassifierResult(mediapipe_lua.kwargs({
    classifications = {
      _Classifications(mediapipe_lua.kwargs({
        categories = {
          _Category(mediapipe_lua.kwargs({
            index = 934,
            score = 0.754467,
            display_name = '',
            category_name = 'cheeseburger',
          })),
          _Category(mediapipe_lua.kwargs({
            index = 925,
            score = 0.0288028,
            display_name = '',
            category_name = 'guacamole',
          })),
          _Category(mediapipe_lua.kwargs({
            index = 932,
            score = 0.0286119,
            display_name = '',
            category_name = 'bagel',
          })),
        },
        head_index = 0,
        head_name = 'probability',
      }))
    },
    timestamp_ms = 0,
  }))

  self.assertProtoEquals(
    image_result:to_pb2(), expected:to_pb2()
  )
end

local function test_classify_succeeds_with_region_of_interest_and_rotation(self)
  local base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path }))
  local options = _ImageClassifierOptions(mediapipe_lua.kwargs({ base_options = base_options, max_results = 1 }))
  local classifier = _ImageClassifier.create_from_options(options)

  -- Load the test image.
  local test_image = _Image.create_from_file(
    test_utils.get_test_data_path(_IMAGE_ROI_ROTATED_FILE)
  )

  -- Region-of-interest around the soccer ball, with 90° anti-clockwise
  -- rotation.
  local roi = _Rect(mediapipe_lua.kwargs({ left = 0.2655, top = 0.45, right = 0.6925, bottom = 0.614 }))
  local image_processing_options = _ImageProcessingOptions(roi, -90)

  -- Performs image classification on the input.
  local image_result = classifier:classify(test_image, image_processing_options)

  -- Comparing results.
  local expected = ImageClassifierResult(mediapipe_lua.kwargs({
    classifications = {
      _Classifications(mediapipe_lua.kwargs({
        categories = {
          _Category(mediapipe_lua.kwargs({
            index = 806,
            score = 0.997684,
            display_name = '',
            category_name = 'soccer ball',
          })),
        },
        head_index = 0,
        head_name = 'probability',
      }))
    },
    timestamp_ms = 0,
  }))

  self.assertProtoEquals(
    image_result:to_pb2(), expected:to_pb2()
  )
end

local function test_score_threshold_option(self)
  local options = _ImageClassifierOptions(mediapipe_lua.kwargs({
    base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
    score_threshold = _SCORE_THRESHOLD,
  }))
  local classifier = _ImageClassifier.create_from_options(options)

  -- Performs image classification on the input.
  local image_result = classifier:classify(self.test_image)
  local classifications = image_result.classifications

  for _, classification in ipairs(classifications) do
    for _, category in ipairs(classification.categories) do
      local score = category.score
      self.assertGreaterEqual(
        score,
        _SCORE_THRESHOLD,
        (
          'Classification with score lower than threshold found. ' ..
          tostring(classification)
        )
      )
    end
  end
end

local function test_max_results_option(self)
  local options = _ImageClassifierOptions(mediapipe_lua.kwargs({
    base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
    score_threshold = _SCORE_THRESHOLD,
  }))
  local classifier = _ImageClassifier.create_from_options(options)

  -- Performs image classification on the input.
  local image_result = classifier:classify(self.test_image)
  local categories = image_result.classifications[0 + INDEX_BASE].categories

  self.assertLessEqual(
    #categories, _MAX_RESULTS, 'Too many results returned.'
  )
end

local function test_allow_list_option(self)
  local options = _ImageClassifierOptions(mediapipe_lua.kwargs({
    base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
    category_allowlist = _ALLOW_LIST,
  }))
  local classifier = _ImageClassifier.create_from_options(options)

  -- Performs image classification on the input.
  local image_result = classifier:classify(self.test_image)
  local classifications = image_result.classifications

  for _, classification in ipairs(classifications) do
    for _, category in ipairs(classification.categories) do
      local label = category.category_name
      self.assertIn(
        label,
        _ALLOW_LIST,
        'Label ' .. label .. ' found but not in label allow list'
      )
    end
  end
end

local function test_deny_list_option(self)
  local options = _ImageClassifierOptions(mediapipe_lua.kwargs({
    base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
    category_denylist = _DENY_LIST,
  }))
  local classifier = _ImageClassifier.create_from_options(options)

  -- Performs image classification on the input.
  local image_result = classifier:classify(self.test_image)
  local classifications = image_result.classifications

  for _, classification in ipairs(classifications) do
    for _, category in ipairs(classification.categories) do
      local label = category.category_name
      self.assertNotIn(
        label, _DENY_LIST, 'Label ' .. label .. ' found but in deny list.'
      )
    end
  end
end

local function test_empty_classification_outputs(self)
  local options = _ImageClassifierOptions(mediapipe_lua.kwargs({
    base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
    score_threshold = 1,
  }))
  local classifier = _ImageClassifier.create_from_options(options)

  -- Performs image classification on the input.
  local image_result = classifier:classify(self.test_image)
  self.assertEmpty(image_result.classifications[0 + INDEX_BASE].categories)
end

local function test_classify_for_video(self)
  local options = _ImageClassifierOptions(mediapipe_lua.kwargs({
    base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
    running_mode = _RUNNING_MODE.VIDEO,
    max_results = 4,
  }))
  local classifier = _ImageClassifier.create_from_options(options)

  for timestamp = 0, 300 - 30, 30 do
    local classification_result = classifier:classify_for_video(
      self.test_image, timestamp
    )
    self.assertProtoEquals(
      classification_result:to_pb2(),
      _generate_burger_results(timestamp):to_pb2()
    )
  end
end

local function test_classify_for_video_succeeds_with_region_of_interest(self)
  local options = _ImageClassifierOptions(mediapipe_lua.kwargs({
    base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
    running_mode = _RUNNING_MODE.VIDEO,
    max_results = 1,
  }))
  local classifier = _ImageClassifier.create_from_options(options)

  -- Load the test image.
  local test_image = _Image.create_from_file(
    test_utils.get_test_data_path(_IMAGE_ROI_FILE)
  )

  -- Region-of-interest around the soccer ball.
  local roi = _Rect(mediapipe_lua.kwargs({ left = 0.45, top = 0.3075, right = 0.614, bottom = 0.7345 }))
  local image_processing_options = _ImageProcessingOptions(roi)

  for timestamp = 0, 300 - 30, 30 do
    local classification_result = classifier:classify_for_video(
      test_image, timestamp, image_processing_options
    )
    self.assertProtoEquals(
      classification_result:to_pb2(),
      _generate_soccer_ball_results(timestamp):to_pb2()
    )
  end
end

local function test_classify_async_calls(self, threshold, generate_expected_result)
  local observed_timestamp_ms = -1

  local function check_result(result, output_image, timestamp_ms)
    self.assertProtoEquals(
      result:to_pb2(), generate_expected_result(timestamp_ms):to_pb2()
    )
    self.assertMatEqual(output_image:mat_view(), self.test_image:mat_view())
    self.assertLess(observed_timestamp_ms, timestamp_ms)
    observed_timestamp_ms = timestamp_ms
  end

  local options = _ImageClassifierOptions(mediapipe_lua.kwargs({
    base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
    running_mode = _RUNNING_MODE.LIVE_STREAM,
    max_results = 4,
    score_threshold = threshold,
    result_callback = check_result,
  }))

  local classifier = _ImageClassifier.create_from_options(options)

  for timestamp = 0, 300 - 30, 30 do
    classifier:classify_async(self.test_image, timestamp)
    mediapipe_lua.notifyCallbacks()
  end

  -- wait for detection end
  classifier:close()
  mediapipe_lua.notifyCallbacks()

  self.assertEqual(observed_timestamp_ms, 300 - 30)
end

local function test_classify_async_succeeds_with_region_of_interest(self)
  -- Load the test image.
  local test_image = _Image.create_from_file(
    test_utils.get_test_data_path(_IMAGE_ROI_FILE)
  )

  -- Region-of-interest around the soccer ball.
  local roi = _Rect(mediapipe_lua.kwargs({ left = 0.45, top = 0.3075, right = 0.614, bottom = 0.7345 }))
  local image_processing_options = _ImageProcessingOptions(roi)

  local observed_timestamp_ms = -1

  local function check_result(result, output_image, timestamp_ms)
    self.assertProtoEquals(
      result:to_pb2(), _generate_soccer_ball_results(timestamp_ms):to_pb2()
    )
    self.assertEqual(output_image.width, test_image.width)
    self.assertEqual(output_image.height, test_image.height)
    self.assertLess(observed_timestamp_ms, timestamp_ms)
    observed_timestamp_ms = timestamp_ms
  end

  local options = _ImageClassifierOptions(mediapipe_lua.kwargs({
    base_options = _BaseOptions(mediapipe_lua.kwargs({ model_asset_path = self.model_path })),
    running_mode = _RUNNING_MODE.LIVE_STREAM,
    max_results = 1,
    result_callback = check_result,
  }))

  local classifier = _ImageClassifier.create_from_options(options)
  for timestamp = 0, 300 - 30, 30 do
    classifier:classify_async(test_image, timestamp, image_processing_options)
    mediapipe_lua.notifyCallbacks()
  end

  -- wait for detection end
  classifier:close()
  mediapipe_lua.notifyCallbacks()

  self.assertEqual(observed_timestamp_ms, 300 - 30)
end

describe("ImageClassifierTest", function()
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
    { ModelFileType.FILE_NAME,    4, _generate_burger_results() },
    { ModelFileType.FILE_CONTENT, 4, _generate_burger_results() },
  }) do
    it("should test_classify " .. _, function()
      test_classify(_assert, unpack(args))
    end)
  end

  it("should test_classify_succeeds_with_region_of_interest", function()
    test_classify_succeeds_with_region_of_interest(_assert)
  end)

  it("should test_classify_succeeds_with_rotation", function()
    test_classify_succeeds_with_rotation(_assert)
  end)

  it("should test_classify_succeeds_with_region_of_interest_and_rotation", function()
    test_classify_succeeds_with_region_of_interest_and_rotation(_assert)
  end)

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

  it("should test_empty_classification_outputs", function()
    test_empty_classification_outputs(_assert)
  end)

  it("should test_classify_for_video", function()
    test_classify_for_video(_assert)
  end)

  it("should test_classify_for_video_succeeds_with_region_of_interest", function()
    test_classify_for_video_succeeds_with_region_of_interest(_assert)
  end)

  for _, args in ipairs({
    { 0, _generate_burger_results },
    { 1, _generate_empty_results },
  }) do
    it("should test_classify_async_calls " .. _, function()
      test_classify_async_calls(_assert, unpack(args))
    end)
  end

  it("should test_classify_async_succeeds_with_region_of_interest", function()
    test_classify_async_succeeds_with_region_of_interest(_assert)
  end)
end)
