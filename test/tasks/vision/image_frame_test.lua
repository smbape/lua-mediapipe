#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.35/mediapipe/python/image_frame_test.py
--]]

local _assert = require("_assert")
local _mat_utils = require("_mat_utils")

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe

local opencv_lua = require("opencv_lua")
local cv2 = opencv_lua.cv

local image_frame = mediapipe.tasks.lua.vision.core.image_frame

local ImageFormat = image_frame.ImageFormat
local ImageFrame = image_frame.ImageFrame

local function test_create_image_frame_from_gray_cv_mat(self)
    local w, h = math.random(3, 100), math.random(3, 100)
    local cv_image = _mat_utils.randomImage(w, h, cv2.CV_8UC1, 0, 2 ^ 8)
    self.assertEqual(cv_image.rows, h)
    self.assertEqual(cv_image.cols, w)

    -- specify the image format
    local gray8_image_frame = ImageFrame(mediapipe_lua.kwargs({ image_format = ImageFormat.GRAY8, data = cv_image }))
    self.assertMatEqual(cv_image, gray8_image_frame:mat_view())

    -- The output of mat_view() is a copy of internal data
    local gray8_image_frame_mat = gray8_image_frame:mat_view()
    gray8_image_frame_mat[{ 2, 2 }] = 43
    cv_image[{ 2, 2 }] = 42
    self.assertEqual(43, gray8_image_frame_mat[{ 2, 2 }])
    self.assertEqual(42, cv_image[{ 2, 2 }])

    -- infer format from mat
    local gray8_image_frame = ImageFrame(mediapipe_lua.kwargs({ data = cv_image }))
    self.assertEqual(gray8_image_frame.image_format, ImageFormat.GRAY8)
    self.assertMatEqual(cv_image, gray8_image_frame:mat_view())

    -- The output of mat_view() is a copy of internal data
    local gray8_image_frame_mat = gray8_image_frame:mat_view()
    gray8_image_frame_mat[{ 2, 2 }] = 43
    cv_image[{ 2, 2 }] = 42
    self.assertEqual(43, gray8_image_frame_mat[{ 2, 2 }])
    self.assertEqual(42, cv_image[{ 2, 2 }])
end

local function test_create_image_frame_from_rgb_cv_mat(self)
    local w, h, channels = math.random(3, 100), math.random(3, 100), 3
    local cv_image = _mat_utils.randomImage(w, h, cv2.CV_MAKETYPE(cv2.CV_8U, channels), 0, 2 ^ 8)
    self.assertEqual(cv_image.rows, h)
    self.assertEqual(cv_image.cols, w)
    self.assertEqual(cv_image:channels(), channels)

    -- specify the image format
    local rgb_image_frame = ImageFrame(mediapipe_lua.kwargs({ image_format = ImageFormat.SRGB, data = cv_image }))
    self.assertMatEqual(cv_image, rgb_image_frame:mat_view())

    -- The output of mat_view() is a copy of internal data
    local rgb_image_frame_mat = rgb_image_frame:mat_view()
    rgb_image_frame_mat[{ 2, 2, 1 }] = 43
    cv_image[{ 2, 2, 1 }] = 42
    self.assertEqual(43, rgb_image_frame_mat[{ 2, 2, 1 }])
    self.assertEqual(42, cv_image[{ 2, 2, 1 }])

    -- infer format from mat
    local rgb_image_frame = ImageFrame(mediapipe_lua.kwargs({ data = cv_image }))
    self.assertEqual(rgb_image_frame.image_format, ImageFormat.SRGB)
    self.assertMatEqual(cv_image, rgb_image_frame:mat_view())

    -- The output of mat_view() is a copy of internal data
    local rgb_image_frame_mat = rgb_image_frame:mat_view()
    rgb_image_frame_mat[{ 2, 2, 1 }] = 43
    cv_image[{ 2, 2, 1 }] = 42
    self.assertEqual(43, rgb_image_frame_mat[{ 2, 2, 1 }])
    self.assertEqual(42, cv_image[{ 2, 2, 1 }])
end

local function test_create_image_frame_from_rgb48_cv_mat(self)
    local w, h, channels = math.random(3, 100), math.random(3, 100), 3
    local cv_image = _mat_utils.randomImage(w, h, cv2.CV_MAKETYPE(cv2.CV_16U, channels), 0, 2 ^ 16)
    self.assertEqual(cv_image.rows, h)
    self.assertEqual(cv_image.cols, w)
    self.assertEqual(cv_image:channels(), channels)

    -- specify the image format
    local rgb48_image_frame = ImageFrame(mediapipe_lua.kwargs({ image_format = ImageFormat.SRGB48, data = cv_image }))
    self.assertMatEqual(cv_image, rgb48_image_frame:mat_view())

    -- The output of mat_view() is a copy of internal data
    local rgb48_image_frame_mat = rgb48_image_frame:mat_view()
    rgb48_image_frame_mat[{ 2, 2, 1 }] = 43
    cv_image[{ 2, 2, 1 }] = 42
    self.assertEqual(43, rgb48_image_frame_mat[{ 2, 2, 1 }])
    self.assertEqual(42, cv_image[{ 2, 2, 1 }])

    -- infer format from mat
    local rgb48_image_frame = ImageFrame(mediapipe_lua.kwargs({ data = cv_image }))
    self.assertEqual(rgb48_image_frame.image_format, ImageFormat.SRGB48)
    self.assertMatEqual(cv_image, rgb48_image_frame:mat_view())

    -- The output of mat_view() is a copy of internal data
    local rgb48_image_frame_mat = rgb48_image_frame:mat_view()
    rgb48_image_frame_mat[{ 2, 2, 1 }] = 43
    cv_image[{ 2, 2, 1 }] = 42
    self.assertEqual(43, rgb48_image_frame_mat[{ 2, 2, 1 }])
    self.assertEqual(42, cv_image[{ 2, 2, 1 }])
end

local function test_image_frame_mat_view(self)
    local w, h, channels = math.random(3, 100), math.random(3, 100), 3
    local cv_image = _mat_utils.randomImage(w, h, cv2.CV_MAKETYPE(cv2.CV_8U, channels), 0, 2 ^ 8)
    self.assertEqual(cv_image.rows, h)
    self.assertEqual(cv_image.cols, w)
    self.assertEqual(cv_image:channels(), channels)

    -- specify the image format
    local rgb_image_frame = ImageFrame(mediapipe_lua.kwargs({ image_format = ImageFormat.SRGB, data = cv_image, copy = false }))
    self.assertMatEqual(cv_image, rgb_image_frame:mat_view())

    -- The output of mat_view() is a reference to the internal data
    local rgb_image_frame_mat = rgb_image_frame:mat_view()
    cv_image[{ 2, 2, 1 }] = 42
    self.assertEqual(42, cv_image[{ 2, 2, 1 }])
    self.assertEqual(rgb_image_frame_mat[{ 2, 2, 1 }], cv_image[{ 2, 2, 1 }])
    rgb_image_frame_mat[{ 2, 2, 1 }] = 43
    self.assertEqual(43, rgb_image_frame_mat[{ 2, 2, 1 }])
    self.assertEqual(rgb_image_frame_mat[{ 2, 2, 1 }], cv_image[{ 2, 2, 1 }])

    -- infer format from mat
    local rgb_image_frame = ImageFrame(mediapipe_lua.kwargs({ data = cv_image, copy = false }))
    self.assertEqual(rgb_image_frame.image_format, ImageFormat.SRGB)
    self.assertMatEqual(cv_image, rgb_image_frame:mat_view())

    -- The output of mat_view() is a reference to the internal data
    local rgb_image_frame_mat = rgb_image_frame:mat_view()
    cv_image[{ 2, 2, 1 }] = 42
    self.assertEqual(42, cv_image[{ 2, 2, 1 }])
    self.assertEqual(rgb_image_frame_mat[{ 2, 2, 1 }], cv_image[{ 2, 2, 1 }])
    rgb_image_frame_mat[{ 2, 2, 1 }] = 43
    self.assertEqual(43, rgb_image_frame_mat[{ 2, 2, 1 }])
    self.assertEqual(rgb_image_frame_mat[{ 2, 2, 1 }], cv_image[{ 2, 2, 1 }])
end

-- For image frames that store contiguous data, the output of mat_view()
-- points to the pixel data of the original image frame object.
local function test_image_frame_mat_view_with_contiguous_data(self)
    local w, h = 640, 480
    local cv_image = _mat_utils.randomImage(w, h, cv2.CV_8UC3, 0, 2 ^ 8)
    self.assertEqual(cv_image.rows, h)
    self.assertEqual(cv_image.cols, w)
    self.assertEqual(cv_image:channels(), 3)

    -- specify the image format
    local rgb_image_frame = ImageFrame(mediapipe_lua.kwargs({ image_format = ImageFormat.SRGB, data = cv_image }))
    self.assertTrue(rgb_image_frame:is_contiguous(), "image frame data should be contiguous")
    self.assertMatEqual(cv_image, rgb_image_frame:mat_view())

    -- Get 2 data array objects and verify that the image frame's data is the same
    local np_view = rgb_image_frame:mat_view()
    self.assertEqual(rgb_image_frame.data, np_view.data)

    local np_view2 = rgb_image_frame:mat_view()
    self.assertEqual(rgb_image_frame.data, np_view2.data)
end

-- For image frames that store non contiguous data, the output of mat_view()
-- points to the pixel data of the original image frame object.
local function test_image_frame_numpy_view_with_non_contiguous_data(self)
    local w, h = 641, 481
    local cv_image = _mat_utils.randomImage(w, h, cv2.CV_8UC3, 0, 2 ^ 8)
    self.assertEqual(cv_image.rows, h)
    self.assertEqual(cv_image.cols, w)
    self.assertEqual(cv_image:channels(), 3)

    -- specify the image format
    local rgb_image_frame = ImageFrame(mediapipe_lua.kwargs({ image_format = ImageFormat.SRGB, data = cv_image }))
    self.assertFalse(rgb_image_frame:is_contiguous(), "image frame data should not be contiguous")
    self.assertMatEqual(cv_image, rgb_image_frame:mat_view())

    -- Get 2 data array objects and verify that the image frame's data is the same
    local np_view = rgb_image_frame:mat_view()
    self.assertEqual(rgb_image_frame.data, np_view.data)

    local np_view2 = rgb_image_frame:mat_view()
    self.assertEqual(rgb_image_frame.data, np_view2.data)
end

describe("ImageFrameTest", function()
    it("should test_create_image_frame_from_gray_cv_mat", function()
        test_create_image_frame_from_gray_cv_mat(_assert)
    end)
    it("should test_create_image_frame_from_rgb_cv_mat", function()
        test_create_image_frame_from_rgb_cv_mat(_assert)
    end)
    it("should test_create_image_frame_from_rgb48_cv_mat", function()
        test_create_image_frame_from_rgb48_cv_mat(_assert)
    end)
    it("should test_image_frame_mat_view", function()
        test_image_frame_mat_view(_assert)
    end)
    it("should test_image_frame_mat_view_with_contiguous_data", function()
        test_image_frame_mat_view_with_contiguous_data(_assert)
    end)
    it("should test_image_frame_numpy_view_with_non_contiguous_data", function()
        test_image_frame_numpy_view_with_non_contiguous_data(_assert)
    end)
end)
