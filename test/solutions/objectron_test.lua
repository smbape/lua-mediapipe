#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
        arg[0]:gsub("[^/\\]+%.lua", '../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/python/solutions/objectron_test.py
--]]

local unpack = table.unpack or unpack ---@diagnostic disable-line: deprecated

local _assert = require("_assert")
local _mat_utils = require("_mat_utils") ---@diagnostic disable-line: unused-local

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe
local download_utils = mediapipe.lua.solutions.download_utils
local __dirname__ = mediapipe_lua.fs_utils.absolute(tostring(arg[0]:gsub("[/\\][^/\\]+$", "")))

local opencv_lua = require("opencv_lua")
local cv2 = opencv_lua.cv

-- resources dependency
local mp_objectron = mediapipe.lua.solutions.objectron

local DIFF_THRESHOLD = 30 -- pixels
EXPECTED_BOX_COORDINATES_PREDICTION = { { { 322, 142 }, { 366, 109 }, { 222, 209 },
    { 365, 55 }, { 206, 154 }, { 422, 135 },
    { 273, 254 }, { 426, 74 }, { 259, 195 } },
    { { 176, 113 }, { 226, 94 }, { 88, 164 },
        { 220, 47 }, { 68, 113 }, { 265, 115 },
        { 127, 195 }, { 262, 65 }, { 110, 140 } } }

local function test_blank_image(self)
    local objectron = mp_objectron.Objectron()
    local image = cv2.Mat.zeros(100, 100, cv2.CV_8UC3)
    image:setTo(255.0)
    local results = objectron:process(image)
    self.assertIsNone(results.detected_objects)
end

local function test_multi_objects(self, id, static_image_mode, num_frames)
    download_utils.download(
        "https://github.com/rkuo2000/cv2/raw/master/shoes.jpg",
        __dirname__ .. "/testdata/shoes.jpg",
        mediapipe_lua.kwargs({
            hash="sha256=396f5e792f9a2afe43159d6f19fc9bbd19dc97373d3d8a34ccb439b722d188ce"
        })
    )

    local image_path = __dirname__ .. "/testdata/shoes.jpg"
    local image = cv2.imread(image_path)
    local rows, cols, _ = unpack(image.shape)

    local objectron = mp_objectron.Objectron(mediapipe_lua.kwargs({
        static_image_mode = static_image_mode,
        max_num_objects = 2,
        min_detection_confidence = 0.5
    }))

    for idx = 0, num_frames - 1 do
        local results = objectron:process(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))

        local multi_box_coordinates = {}

        for i, detected_object in ipairs(results.detected_objects) do
            local landmarks = detected_object.landmarks_2d
            self.assertLen(landmarks.landmark, 9)

            local box_coordinates = {}
            for j, landmark in ipairs(landmarks.landmark:table()) do
                box_coordinates[j] = { landmark.x * cols, landmark.y * rows }
            end
            multi_box_coordinates[i] = box_coordinates
        end

        self.assertLen(multi_box_coordinates, 2)

        local prediction_error = cv2.absdiff(
            cv2.Mat.createFromArray(multi_box_coordinates, cv2.CV_32F),
            cv2.Mat.createFromArray(EXPECTED_BOX_COORDINATES_PREDICTION, cv2.CV_32F))
        self.assertMatLess(prediction_error, DIFF_THRESHOLD)
    end
end

describe("ObjectronTest", function()
    it("should test_blank_image", function()
        test_blank_image(_assert)
    end)

    for _, args in ipairs({
        { 'static_image_mode', true,  1 },
        { 'video_mode',        false, 5 },
    }) do
        it("should test_multi_objects " .. args[1], function()
            test_multi_objects(_assert, unpack(args))
        end)
    end
end)
