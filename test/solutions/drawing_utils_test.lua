#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
arg[0]:gsub("[^/\\]+%.lua", '../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/python/solutions/drawing_utils_test.py
--]]

local unpack = table.unpack or unpack ---@diagnostic disable-line: deprecated

local _assert = require("_assert")
local _mat_utils = require("_mat_utils") ---@diagnostic disable-line: unused-local

local mediapipe_lua = require("mediapipe_lua")
local google = mediapipe_lua.google
local mediapipe = mediapipe_lua.mediapipe

local opencv_lua = require("opencv_lua")
local cv2 = opencv_lua.cv

local text_format = google.protobuf.text_format
local detection_pb2 = mediapipe.framework.formats.detection_pb2
local landmark_pb2 = mediapipe.framework.formats.landmark_pb2
local drawing_utils = mediapipe.lua.solutions.drawing_utils

local DEFAULT_BBOX_DRAWING_SPEC = drawing_utils.DrawingSpec()
local DEFAULT_CONNECTION_DRAWING_SPEC = drawing_utils.DrawingSpec()
local DEFAULT_CIRCLE_DRAWING_SPEC = drawing_utils.DrawingSpec(mediapipe_lua.kwargs({
    color = drawing_utils.RED_COLOR }))
local DEFAULT_AXIS_DRAWING_SPEC = drawing_utils.DrawingSpec()
local DEFAULT_CYCLE_BORDER_COLOR = { 224, 224, 224 }

local function test_draw_keypoints_only(self)
    local detection = text_format.Parse([[
        location_data {
            format: RELATIVE_BOUNDING_BOX
            relative_keypoints {x: 0 y: 1}
            relative_keypoints {x: 1 y: 0}
        }
    ]], detection_pb2.Detection())
    local image = cv2.Mat.zeros(100, 100, cv2.CV_8UC3)
    local expected_result = image:copy()
    cv2.circle(expected_result, { 0, 99 },
        DEFAULT_CIRCLE_DRAWING_SPEC.circle_radius,
        DEFAULT_CIRCLE_DRAWING_SPEC.color,
        DEFAULT_CIRCLE_DRAWING_SPEC.thickness)
    cv2.circle(expected_result, { 99, 0 },
        DEFAULT_CIRCLE_DRAWING_SPEC.circle_radius,
        DEFAULT_CIRCLE_DRAWING_SPEC.color,
        DEFAULT_CIRCLE_DRAWING_SPEC.thickness)
    drawing_utils.draw_detection(image, detection)
    self.assertMatEqual(image, expected_result)
end

local function test_draw_bboxs_only(self)
    local detection = text_format.Parse([[
        location_data {
            format: RELATIVE_BOUNDING_BOX
            relative_bounding_box {xmin: 0 ymin: 0 width: 1 height: 1}
        }
    ]], detection_pb2.Detection())
    local image = cv2.Mat.zeros(100, 100, cv2.CV_8UC3)
    local expected_result = image:copy()
    cv2.rectangle(expected_result, { 0, 0 }, { 99, 99 },
        DEFAULT_BBOX_DRAWING_SPEC.color,
        DEFAULT_BBOX_DRAWING_SPEC.thickness)
    drawing_utils.draw_detection(image, detection)
    self.assertMatEqual(image, expected_result)
end

local function test_draw_single_landmark_point(self, id, landmark_list_text)
    local landmark_list = text_format.Parse(landmark_list_text,
        landmark_pb2.NormalizedLandmarkList())
    local image = cv2.Mat.zeros(100, 100, cv2.CV_8UC3)
    local expected_result = image:copy()
    cv2.circle(expected_result, { 10, 10 },
        DEFAULT_CIRCLE_DRAWING_SPEC.circle_radius + 1,
        DEFAULT_CYCLE_BORDER_COLOR,
        DEFAULT_CIRCLE_DRAWING_SPEC.thickness)
    cv2.circle(expected_result, { 10, 10 },
        DEFAULT_CIRCLE_DRAWING_SPEC.circle_radius,
        DEFAULT_CIRCLE_DRAWING_SPEC.color,
        DEFAULT_CIRCLE_DRAWING_SPEC.thickness)
    drawing_utils.draw_landmarks(image, landmark_list)
    self.assertMatEqual(image, expected_result)
end

local function test_draw_landmarks_and_connections(self, id, landmark_list_text)
    local landmark_list = text_format.Parse(landmark_list_text,
        landmark_pb2.NormalizedLandmarkList())
    local image = cv2.Mat.zeros(100, 100, cv2.CV_8UC3)
    local expected_result = image:copy()
    local start_point = { 10, 50 }
    local end_point = { 50, 10 }
    cv2.line(expected_result, start_point, end_point,
        DEFAULT_CONNECTION_DRAWING_SPEC.color,
        DEFAULT_CONNECTION_DRAWING_SPEC.thickness)
    cv2.circle(expected_result, start_point,
        DEFAULT_CIRCLE_DRAWING_SPEC.circle_radius + 1,
        DEFAULT_CYCLE_BORDER_COLOR,
        DEFAULT_CIRCLE_DRAWING_SPEC.thickness)
    cv2.circle(expected_result, end_point,
        DEFAULT_CIRCLE_DRAWING_SPEC.circle_radius + 1,
        DEFAULT_CYCLE_BORDER_COLOR,
        DEFAULT_CIRCLE_DRAWING_SPEC.thickness)
    cv2.circle(expected_result, start_point,
        DEFAULT_CIRCLE_DRAWING_SPEC.circle_radius,
        DEFAULT_CIRCLE_DRAWING_SPEC.color,
        DEFAULT_CIRCLE_DRAWING_SPEC.thickness)
    cv2.circle(expected_result, end_point,
        DEFAULT_CIRCLE_DRAWING_SPEC.circle_radius,
        DEFAULT_CIRCLE_DRAWING_SPEC.color,
        DEFAULT_CIRCLE_DRAWING_SPEC.thickness)
    drawing_utils.draw_landmarks(mediapipe_lua.kwargs({
        image = image, landmark_list = landmark_list, connections = { { 0, 1 } } }))
    self.assertMatEqual(image, expected_result)
end

local function test_draw_axis(self)
    local image = cv2.Mat.zeros(100, 100, cv2.CV_8UC3)
    local expected_result = image:copy()
    local origin = { 50, 50 }
    local x_axis = { 75, 50 }
    local y_axis = { 50, 23 }
    local z_axis = { 50, 77 }
    cv2.arrowedLine(expected_result, origin, x_axis, drawing_utils.RED_COLOR,
        DEFAULT_AXIS_DRAWING_SPEC.thickness)
    cv2.arrowedLine(expected_result, origin, y_axis, drawing_utils.GREEN_COLOR,
        DEFAULT_AXIS_DRAWING_SPEC.thickness)
    cv2.arrowedLine(expected_result, origin, z_axis, drawing_utils.BLUE_COLOR,
        DEFAULT_AXIS_DRAWING_SPEC.thickness)
    local r = math.sqrt(2.) / 2.
    local rotation = cv2.Mat.createFromVectorOfVec3f({ { 1., 0., 0. }, { 0., r, -r }, { 0., r, r } })
    local translation = cv2.Mat.createFromVec3f({ 0, 0, -0.2 })
    drawing_utils.draw_axis(image, rotation, translation)
    self.assertMatEqual(image, expected_result)
end

local function test_draw_axis_zero_translation(self)
    local image = cv2.Mat.zeros(100, 100, cv2.CV_8UC3)
    local expected_result = image:copy()
    local origin = { 50, 50 }
    local x_axis = { 0, 50 }
    local y_axis = { 50, 100 }
    local z_axis = { 50, 50 }
    cv2.arrowedLine(expected_result, origin, x_axis, drawing_utils.RED_COLOR,
        DEFAULT_AXIS_DRAWING_SPEC.thickness)
    cv2.arrowedLine(expected_result, origin, y_axis, drawing_utils.GREEN_COLOR,
        DEFAULT_AXIS_DRAWING_SPEC.thickness)
    cv2.arrowedLine(expected_result, origin, z_axis, drawing_utils.BLUE_COLOR,
        DEFAULT_AXIS_DRAWING_SPEC.thickness)
    local rotation = cv2.Mat.eye(3, cv2.CV_32F)
    local translation = cv2.Mat.zeros(3, cv2.CV_32F)
    drawing_utils.draw_axis(image, rotation, translation)
    self.assertMatEqual(image, expected_result)
end

local function test_min_and_max_coordinate_values(self)
    local landmark_list = text_format.Parse([[
        landmark {x: 0.0 y: 1.0}
        landmark {x: 1.0 y: 0.0}
    ]], landmark_pb2.NormalizedLandmarkList())
    local image = cv2.Mat.zeros(100, 100, cv2.CV_8UC3)
    local expected_result = image:copy()
    local start_point = { 0, 99 }
    local end_point = { 99, 0 }
    cv2.line(expected_result, start_point, end_point,
        DEFAULT_CONNECTION_DRAWING_SPEC.color,
        DEFAULT_CONNECTION_DRAWING_SPEC.thickness)
    cv2.circle(expected_result, start_point,
        DEFAULT_CIRCLE_DRAWING_SPEC.circle_radius + 1,
        DEFAULT_CYCLE_BORDER_COLOR,
        DEFAULT_CIRCLE_DRAWING_SPEC.thickness)
    cv2.circle(expected_result, end_point,
        DEFAULT_CIRCLE_DRAWING_SPEC.circle_radius + 1,
        DEFAULT_CYCLE_BORDER_COLOR,
        DEFAULT_CIRCLE_DRAWING_SPEC.thickness)
    cv2.circle(expected_result, start_point,
        DEFAULT_CIRCLE_DRAWING_SPEC.circle_radius,
        DEFAULT_CIRCLE_DRAWING_SPEC.color,
        DEFAULT_CIRCLE_DRAWING_SPEC.thickness)
    cv2.circle(expected_result, end_point,
        DEFAULT_CIRCLE_DRAWING_SPEC.circle_radius,
        DEFAULT_CIRCLE_DRAWING_SPEC.color,
        DEFAULT_CIRCLE_DRAWING_SPEC.thickness)
    drawing_utils.draw_landmarks(mediapipe_lua.kwargs({
        image = image, landmark_list = landmark_list, connections = { { 0, 1 } } }))
    self.assertMatEqual(image, expected_result)
end

local function test_drawing_spec(self)
    local landmark_list = text_format.Parse([[
        landmark {x: 0.1 y: 0.1}
        landmark {x: 0.8 y: 0.8}
    ]], landmark_pb2.NormalizedLandmarkList())
    local image = cv2.Mat.zeros(100, 100, cv2.CV_8UC3)
    local landmark_drawing_spec = drawing_utils.DrawingSpec(mediapipe_lua.kwargs({
        color = { 0, 0, 255 }, thickness = 5 }))
    local connection_drawing_spec = drawing_utils.DrawingSpec(mediapipe_lua.kwargs({
        color = { 255, 0, 0 }, thickness = 3 }))
    local expected_result = image:copy()
    local start_point = { 10, 10 }
    local end_point = { 80, 80 }
    cv2.line(expected_result, start_point, end_point,
        connection_drawing_spec.color, connection_drawing_spec.thickness)
    cv2.circle(expected_result, start_point,
        landmark_drawing_spec.circle_radius + 1,
        DEFAULT_CYCLE_BORDER_COLOR, landmark_drawing_spec.thickness)
    cv2.circle(expected_result, end_point,
        landmark_drawing_spec.circle_radius + 1,
        DEFAULT_CYCLE_BORDER_COLOR, landmark_drawing_spec.thickness)
    cv2.circle(expected_result, start_point,
        landmark_drawing_spec.circle_radius, landmark_drawing_spec.color,
        landmark_drawing_spec.thickness)
    cv2.circle(expected_result, end_point, landmark_drawing_spec.circle_radius,
        landmark_drawing_spec.color, landmark_drawing_spec.thickness)
    drawing_utils.draw_landmarks(mediapipe_lua.kwargs({
        image = image,
        landmark_list = landmark_list,
        connections = { { 0, 1 } },
        landmark_drawing_spec = landmark_drawing_spec,
        connection_drawing_spec = connection_drawing_spec
    }))
    self.assertMatEqual(image, expected_result)
end

describe("DrawingUtilTest", function()
    it("should test_draw_keypoints_only", function()
        test_draw_keypoints_only(_assert)
    end)
    it("should test_draw_bboxs_only", function()
        test_draw_bboxs_only(_assert)
    end)

    for _, args in ipairs({
        { 'landmark_list_has_only_one_element', 'landmark {x: 0.1 y: 0.1}' },
        { 'second_landmark_is_invisible', 'landmark {x: 0.1 y: 0.1} landmark {x: 0.5 y: 0.5 visibility: 0.0}' },
    }) do
        it("should test_draw_single_landmark_point " .. args[1], function()
            test_draw_single_landmark_point(_assert, unpack(args))
        end)
    end

    for _, args in ipairs({
        { 'landmarks_have_x_and_y_only', 'landmark {x: 0.1 y: 0.5} landmark {x: 0.5 y: 0.1}' },
        { 'landmark_zero_visibility_and_presence', [[
            landmark {x: 0.1 y: 0.5 presence: 0.5}
            landmark {x: 0.5 y: 0.1 visibility: 0.5}
        ]] },
    }) do
        it("should test_face " .. args[1], function()
            test_draw_landmarks_and_connections(_assert, unpack(args))
        end)
    end

    it("should test_draw_axis", function()
        test_draw_axis(_assert)
    end)
    it("should test_draw_axis_zero_translation", function()
        test_draw_axis_zero_translation(_assert)
    end)
    it("should test_min_and_max_coordinate_values", function()
        test_min_and_max_coordinate_values(_assert)
    end)
    it("should test_drawing_spec", function()
        test_drawing_spec(_assert)
    end)
end)
