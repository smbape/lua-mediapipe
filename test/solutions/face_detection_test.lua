#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/python/solutions/face_detection_test.py
--]]

local unpack = table.unpack or unpack ---@diagnostic disable-line: deprecated
local INDEX_BASE = 1 -- lua is 1-based indexed

local _assert = require("_assert")
local _mat_utils = require("_mat_utils") ---@diagnostic disable-line: unused-local

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe
local download_utils = mediapipe.lua.solutions.download_utils
local __dirname__ = mediapipe_lua.fs_utils.absolute(tostring(arg[0]:gsub("[/\\][^/\\]+$", "")))

local opencv_lua = require("opencv_lua")
local cv2 = opencv_lua.cv

-- resources dependency
-- undeclared dependency
local mp_drawing = mediapipe.lua.solutions.drawing_utils
local mp_faces = mediapipe.lua.solutions.face_detection

local SHORT_RANGE_EXPECTED_FACE_KEY_POINTS = { { 363, 182 }, { 460, 186 }, { 420, 241 },
    { 417, 284 }, { 295, 199 }, { 502, 198 } }
local FULL_RANGE_EXPECTED_FACE_KEY_POINTS = { { 363, 181 }, { 455, 181 }, { 413, 233 },
    { 411, 278 }, { 306, 204 }, { 499, 207 } }
local DIFF_THRESHOLD = 5 -- pixels

function _assert._annotate(id, frame, results, idx)
    for _, detection in ipairs(results.detections) do
        mp_drawing.draw_detection(frame, detection)
    end
    local path = __dirname__ .. "/testdata/" .. id .. "_frame_" .. idx .. ".png"
    cv2.imwrite(path, frame)
end

local function test_blank_image(self)
    local image = cv2.Mat.zeros(100, 100, cv2.CV_8UC3)
    image:setTo(255.0)
    local faces = mp_faces.FaceDetection(mediapipe_lua.kwargs({ min_detection_confidence = 0.5 }))
    local results = faces:process(image)
    self.assertIsNone(results.detections)
end

local function test_face(self, id, model_selection)
    download_utils.download(
        "https://github.com/tensorflow/tfjs-models/raw/master/face-detection/test_data/portrait.jpg",
        __dirname__ .. "/testdata/portrait.jpg",
        mediapipe_lua.kwargs({
            hash="sha256=a6f11efaa834706db23f275b6115058fa87fc7f14362681e6abe14e82749de3e"
        })
    )

    local image_path = __dirname__ .. "/testdata/portrait.jpg"
    local image = cv2.imread(image_path)
    local rows, cols = image.rows, image.cols
    local faces = mp_faces.FaceDetection(mediapipe_lua.kwargs({
        min_detection_confidence = 0.5, model_selection = model_selection }))

    for idx = 0, 4 do
        local results = faces:process(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
        self._annotate("test_face_" .. id, image:copy(), results, idx)

        local location_data = results.detections[0 + INDEX_BASE].location_data

        local face_keypoints = {}
        for i, keypoint in ipairs(location_data.relative_keypoints:table()) do
            face_keypoints[i] = {
                keypoint.x * cols,
                keypoint.y * rows,
            }
        end

        local prediction_error

        if model_selection == 0 then
            prediction_error = cv2.absdiff(
                cv2.Mat.createFromArray(face_keypoints, cv2.CV_32S),
                cv2.Mat.createFromArray(SHORT_RANGE_EXPECTED_FACE_KEY_POINTS, cv2.CV_32S))
        else
            prediction_error = cv2.absdiff(
                cv2.Mat.createFromArray(face_keypoints, cv2.CV_32S),
                cv2.Mat.createFromArray(FULL_RANGE_EXPECTED_FACE_KEY_POINTS, cv2.CV_32S))
        end

        self.assertLen(results.detections, 1)
        self.assertLen(location_data.relative_keypoints, 6)
        self.assertMatLess(prediction_error, DIFF_THRESHOLD)
    end
end

describe("FaceDetectionTest", function()
    it("should test_blank_image", function()
        test_blank_image(_assert)
    end)

    for _, args in ipairs({
        { 'short_range_model', 0 },
        { 'full_range_model', 1 },
    }) do
        it("should test_face " .. args[1], function()
            test_face(_assert, unpack(args))
        end)
    end
end)
