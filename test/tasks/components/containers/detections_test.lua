#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.35/mediapipe/tasks/python/test/components/containers/detections_test.py
--]]

local _assert = require("_assert")

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe
local category_lib = mediapipe.tasks.lua.components.containers.category
local detections_lib = mediapipe.tasks.lua.components.containers.detections
local keypoint_lib = mediapipe.tasks.lua.components.containers.keypoint
local rect_lib = mediapipe.tasks.lua.components.containers.rect

local INDEX_BASE = 1

local _CATEGORY_WITH_NAMES = category_lib.Category(mediapipe_lua.kwargs({
    index = 1,
    score = 0.9,
    category_name = 'test_category_WITH_NAMES',
    display_name = 'Test Category 1',
}))
local _CATEGORY_WITH_NAMES_DICT = {
    index = 1,
    score = 0.9,
    category_name = 'test_category_WITH_NAMES',
    display_name = 'Test Category 1',
}

local _CATEGORY_WITHOUT_NAMES = category_lib.Category(mediapipe_lua.kwargs({
    index = 2,
    score = 0.8,
    category_name = 'test_category_WITHOUT_NAMES',
    display_name = 'Test Category 2',
}))
local _CATEGORY_WITHOUT_NAMES_DICT = {
    index = 2,
    score = 0.8,
    category_name = 'test_category_WITHOUT_NAMES',
    display_name = 'Test Category 2',
}

local _KEYPOINT_1 = keypoint_lib.NormalizedKeypoint(mediapipe_lua.kwargs({
    x = 0.1, y = 0.2, label = 'keypoint1', score = 0.9
}))
local _KEYPOINT_1_DICT = {
    x = 0.1,
    y = 0.2,
    label = 'keypoint1',
    score = 0.9,
}

local _KEYPOINT_2 = keypoint_lib.NormalizedKeypoint(mediapipe_lua.kwargs({
    x = 0.3, y = 0.4, label = 'keypoint2', score = 0.8
}))
local _KEYPOINT_2_DICT = {
    x = 0.3,
    y = 0.4,
    label = 'keypoint2',
    score = 0.8,
}

local _RECT_1 = rect_lib.Rect(mediapipe_lua.kwargs({ left = 10, top = 20, right = 50, bottom = 70 }))
local _RECT_1_DICT = {
    origin_x = 10,
    origin_y = 20,
    width = 40,
    height = 50,
}

local _RECT_2 = rect_lib.Rect(mediapipe_lua.kwargs({ left = 15, top = 25, right = 55, bottom = 75 }))
_RECT_2_DICT = {
    origin_x = 15,
    origin_y = 25,
    width = 40,
    height = 50,
}



function _assert._assert_categories_equal(
    self,
    actual_categories,
    expected_categories
)
    self.assertEqual(#actual_categories, #expected_categories)
    for i, expected_category in ipairs(expected_categories) do
        self.assertDictAlmostEqual(actual_categories[i - INDEX_BASE], expected_category)
    end
end

function _assert._assert_keypoints_equal(
    self,
    actual_keypoints,
    expected_keypoints
)
    self.assertEqual(#actual_keypoints, #expected_keypoints)
    for i, expected_keypoint in ipairs(expected_keypoints) do
        self.assertDictAlmostEqual(actual_keypoints[i - INDEX_BASE], expected_keypoint)
    end
end

function _assert._assert_bounding_box_equal(
    self,
    actual_values,
    expected_values
)
    self.assertDictAlmostEqual(actual_values, expected_values)
end

function _assert._assert_detection_matches(
    self,
    actual,
    expected_bounding_box,
    expected_categories,
    expected_keypoints
)
    self:_assert_bounding_box_equal(actual.bounding_box, expected_bounding_box)
    self:_assert_categories_equal(actual.categories, expected_categories)

    if expected_keypoints then
        self:_assert_keypoints_equal(actual.keypoints, expected_keypoints)
    else
        self.assertIsNone(actual.keypoints)
    end
end

local function test_create_detection_from_ctypes(self)
    local categories = { _CATEGORY_WITH_NAMES, _CATEGORY_WITHOUT_NAMES }
    local keypoints = { _KEYPOINT_1, _KEYPOINT_2 }
    local actual_detection = detections_lib.Detection(mediapipe_lua.kwargs({
        categories = categories,
        bounding_box = _RECT_1,
        keypoints = keypoints,
    }))

    self:_assert_detection_matches(
        actual_detection,
        _RECT_1_DICT,
        { _CATEGORY_WITH_NAMES_DICT, _CATEGORY_WITHOUT_NAMES_DICT },
        { _KEYPOINT_1_DICT, _KEYPOINT_2_DICT }
    )
end

local function test_create_detection_from_ctypes_without_keypoints(self)
    local categories = { _CATEGORY_WITH_NAMES }
    local actual_detection = detections_lib.Detection(mediapipe_lua.kwargs({
        categories = categories,
        bounding_box = _RECT_2,
        keypoints = nil,
    }))

    self:_assert_detection_matches(
        actual_detection,
        _RECT_2_DICT,
        { _CATEGORY_WITH_NAMES_DICT },
        nil
    )
end

local function test_create_detection_result_from_ctypes(self)
    local categories_1 = { _CATEGORY_WITH_NAMES }
    local keypoints_1 = { _KEYPOINT_1 }
    local detection_1 = detections_lib.Detection(mediapipe_lua.kwargs({
        categories = categories_1,
        bounding_box = _RECT_1,
        keypoints = keypoints_1,
    }))

    local categories_2 = { _CATEGORY_WITHOUT_NAMES }
    local keypoints_2 = { _KEYPOINT_2 }
    local detection_2 = detections_lib.Detection(mediapipe_lua.kwargs({
        categories = categories_2,
        bounding_box = _RECT_2,
        keypoints = keypoints_2,
    }))

    local detections = { detection_1, detection_2 }
    local actual_detection_result = detections_lib.DetectionResult(mediapipe_lua.kwargs({
        detections = detections,
    }))

    it("", function()
        self.assertLen(actual_detection_result.detections, 2)
    end)

    it('FirstDetectionConvertedCorrectly', function()
        self:_assert_detection_matches(
            actual_detection_result.detections[0],
            _RECT_1_DICT,
            { _CATEGORY_WITH_NAMES_DICT },
            { _KEYPOINT_1_DICT }
        )
    end)

    it('SecondDetectionConvertedCorrectly', function()
        self:_assert_detection_matches(
            actual_detection_result.detections[1],
            _RECT_2_DICT,
            { _CATEGORY_WITHOUT_NAMES_DICT },
            { _KEYPOINT_2_DICT }
        )
    end)
end

describe("DetectionsTest", function()
    it("should test_create_detection_from_ctypes", function()
        test_create_detection_from_ctypes(_assert)
    end)
    it("should test_create_detection_from_ctypes_without_keypoints", function()
        test_create_detection_from_ctypes_without_keypoints(_assert)
    end)
    describe("should test_create_detection_result_from_ctypes", function()
        test_create_detection_result_from_ctypes(_assert)
    end)
end)
