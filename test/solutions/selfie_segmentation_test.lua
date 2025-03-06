#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/python/solutions/selfie_segmentation_test.py
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
-- undeclared dependency
local mp_selfie_segmentation = mediapipe.lua.solutions.selfie_segmentation

function _assert._draw(id, frame, mask)
    -- frame and mask must have the same size and type to perform cv::min
    if frame:depth() ~= mask:depth() then
        mask = mask:convertTo(frame:depth())
    end

    frame = cv2.min(frame, cv2.merge({ mask, mask, mask }))

    local path = __dirname__ .. "/testdata/" .. id .. ".png"
    cv2.imwrite(path, frame)
end

local function test_blank_image(self)
    local selfie_segmentation = mp_selfie_segmentation.SelfieSegmentation()
    local image = cv2.Mat.zeros(100, 100, cv2.CV_8UC3)
    image:setTo(255.0)
    local results = selfie_segmentation:process(image)
    local normalized_segmentation_mask = (results.segmentation_mask * 255):convertTo(cv2.CV_32S)
    self.assertMatLess(normalized_segmentation_mask, 1)
end

local function test_segmentation(self, id, model_selection)
    download_utils.download(
        "https://github.com/tensorflow/tfjs-models/raw/master/face-detection/test_data/portrait.jpg",
        __dirname__ .. "/testdata/portrait.jpg",
        mediapipe_lua.kwargs({
            hash="sha256=a6f11efaa834706db23f275b6115058fa87fc7f14362681e6abe14e82749de3e"
        })
    )

    local image_path = __dirname__ .. "/testdata/portrait.jpg"
    local image = cv2.imread(image_path)
    local selfie_segmentation = mp_selfie_segmentation.SelfieSegmentation(mediapipe_lua.kwargs({
                    model_selection=model_selection}))
    local results = selfie_segmentation:process(
            cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
    local normalized_segmentation_mask = (results.segmentation_mask *
                                                                    255):convertTo(cv2.CV_32S)
    self._draw("test_segmentation_" .. id, image:copy(), normalized_segmentation_mask)
end

describe("SelfieSegmentationTest", function()
    it("should test_blank_image", function()
        test_blank_image(_assert)
    end)

    for _, args in ipairs({
        { 'general', 0 },
        { 'landscape', 1 },
    }) do
        it("should test_segmentation " .. args[1], function()
            test_segmentation(_assert, unpack(args))
        end)
    end
end)
