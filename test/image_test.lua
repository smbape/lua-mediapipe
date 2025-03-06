#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/python/image_test.py
--]]

local _assert = require("_assert")
local _mat_utils = require("_mat_utils")

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe

local opencv_lua = require("opencv_lua")
local cv2 = opencv_lua.cv

local image = mediapipe.lua._framework_bindings.image
local image_frame = mediapipe.lua._framework_bindings.image_frame

local Image = image.Image
local ImageFormat = image_frame.ImageFormat

local download_utils = mediapipe.lua.solutions.download_utils
local __dirname__ = mediapipe_lua.fs_utils.absolute(tostring(arg[0]:gsub("[/\\][^/\\]+$", "")))

local function test_create_image_from_gray_cv_mat(self)
    local w, h = math.random(3, 100), math.random(3, 100)
    local mat = _mat_utils.randomImage(w, h, cv2.CV_8UC1, 0, 2 ^ 8)
    self.assertEqual(mat.rows, h)
    self.assertEqual(mat.cols, w)

    -- specify the image format
    local gray8_image = Image(mediapipe_lua.kwargs({ image_format = ImageFormat.GRAY8, data = mat }))
    self.assertMatEqual(mat, gray8_image:mat_view())

    -- The output of mat_view() is a copy of internal data
    local gray8_image_mat = gray8_image:mat_view()
    gray8_image_mat[{ 2, 2 }] = 43
    mat[{ 2, 2 }] = 42
    self.assertEqual(43, gray8_image_mat[{ 2, 2 }])
    self.assertEqual(42, mat[{ 2, 2 }])

    -- infer format from mat
    local gray8_image = Image(mediapipe_lua.kwargs({ data = mat }))
    self.assertEqual(gray8_image.image_format, ImageFormat.GRAY8)
    self.assertMatEqual(mat, gray8_image:mat_view())

    -- The output of mat_view() is a copy of internal data
    local gray8_image_mat = gray8_image:mat_view()
    gray8_image_mat[{ 2, 2 }] = 43
    mat[{ 2, 2 }] = 42
    self.assertEqual(43, gray8_image_mat[{ 2, 2 }])
    self.assertEqual(42, mat[{ 2, 2 }])
end

local function test_create_image_from_rgb_cv_mat(self)
    local w, h, channels = math.random(3, 100), math.random(3, 100), 3
    local mat = _mat_utils.randomImage(w, h, cv2.CV_MAKETYPE(cv2.CV_8U, channels), 0, 2 ^ 8)
    self.assertEqual(mat.rows, h)
    self.assertEqual(mat.cols, w)
    self.assertEqual(mat:channels(), channels)

    -- specify the image format
    local rgb_image = Image(mediapipe_lua.kwargs({ image_format = ImageFormat.SRGB, data = mat }))
    self.assertMatEqual(mat, rgb_image:mat_view())

    -- The output of mat_view() is a copy of internal data
    local rgb_image_mat = rgb_image:mat_view()
    rgb_image_mat[{ 2, 2, 1 }] = 43
    mat[{ 2, 2, 1 }] = 42
    self.assertEqual(43, rgb_image_mat[{ 2, 2, 1 }])
    self.assertEqual(42, mat[{ 2, 2, 1 }])

    -- infer format from mat
    local rgb_image = Image(mediapipe_lua.kwargs({ data = mat }))
    self.assertEqual(rgb_image.image_format, ImageFormat.SRGB)
    self.assertMatEqual(mat, rgb_image:mat_view())

    -- The output of mat_view() is a copy of internal data
    local rgb_image_mat = rgb_image:mat_view()
    rgb_image_mat[{ 2, 2, 1 }] = 43
    mat[{ 2, 2, 1 }] = 42
    self.assertEqual(43, rgb_image_mat[{ 2, 2, 1 }])
    self.assertEqual(42, mat[{ 2, 2, 1 }])
end

local function test_create_image_from_rgb48_cv_mat(self)
    local w, h, channels = math.random(3, 100), math.random(3, 100), 3
    local mat = _mat_utils.randomImage(w, h, cv2.CV_MAKETYPE(cv2.CV_16U, channels), 0, 2 ^ 16)
    self.assertEqual(mat.rows, h)
    self.assertEqual(mat.cols, w)
    self.assertEqual(mat:channels(), channels)

    -- specify the image format
    local rgb48_image = Image(mediapipe_lua.kwargs({ image_format = ImageFormat.SRGB48, data = mat }))
    self.assertMatEqual(mat, rgb48_image:mat_view())

    -- The output of mat_view() is a copy of internal data
    local rgb48_image_mat = rgb48_image:mat_view()
    rgb48_image_mat[{ 2, 2, 1 }] = 43
    mat[{ 2, 2, 1 }] = 42
    self.assertEqual(43, rgb48_image_mat[{ 2, 2, 1 }])
    self.assertEqual(42, mat[{ 2, 2, 1 }])

    -- infer format from mat
    local rgb48_image = Image(mediapipe_lua.kwargs({ data = mat }))
    -- self.assertEqual(rgb48_image.image_format, ImageFormat.SRGB48) -- may be a bug in mediapipe
    self.assertMatEqual(mat, rgb48_image:mat_view())

    -- The output of mat_view() is a copy of internal data
    local rgb48_image_mat = rgb48_image:mat_view()
    rgb48_image_mat[{ 2, 2, 1 }] = 43
    mat[{ 2, 2, 1 }] = 42
    self.assertEqual(43, rgb48_image_mat[{ 2, 2, 1 }])
    self.assertEqual(42, mat[{ 2, 2, 1 }])
end

local function test_image_mat_view(self)
    local w, h, channels = math.random(3, 100), math.random(3, 100), 3
    local mat = _mat_utils.randomImage(w, h, cv2.CV_MAKETYPE(cv2.CV_8U, channels), 0, 2 ^ 8)
    self.assertEqual(mat.rows, h)
    self.assertEqual(mat.cols, w)
    self.assertEqual(mat:channels(), channels)

    -- specify the image format
    local rgb_image = Image(mediapipe_lua.kwargs({ image_format = ImageFormat.SRGB, data = mat, copy = false }))
    self.assertMatEqual(mat, rgb_image:mat_view())

    -- The output of mat_view() is a reference to the internal data
    local rgb_image_mat = rgb_image:mat_view()
    mat[{ 2, 2, 1 }] = 42
    self.assertEqual(42, mat[{ 2, 2, 1 }])
    self.assertEqual(rgb_image_mat[{ 2, 2, 1 }], mat[{ 2, 2, 1 }])
    rgb_image_mat[{ 2, 2, 1 }] = 43
    self.assertEqual(43, rgb_image_mat[{ 2, 2, 1 }])
    self.assertEqual(rgb_image_mat[{ 2, 2, 1 }], mat[{ 2, 2, 1 }])

    -- infer format from mat
    local rgb_image = Image(mediapipe_lua.kwargs({ data = mat, copy = false }))
    self.assertEqual(rgb_image.image_format, ImageFormat.SRGB)
    self.assertMatEqual(mat, rgb_image:mat_view())

    -- The output of mat_view() is a reference to the internal data
    local rgb_image_mat = rgb_image:mat_view()
    mat[{ 2, 2, 1 }] = 42
    self.assertEqual(42, mat[{ 2, 2, 1 }])
    self.assertEqual(rgb_image_mat[{ 2, 2, 1 }], mat[{ 2, 2, 1 }])
    rgb_image_mat[{ 2, 2, 1 }] = 43
    self.assertEqual(43, rgb_image_mat[{ 2, 2, 1 }])
    self.assertEqual(rgb_image_mat[{ 2, 2, 1 }], mat[{ 2, 2, 1 }])
end

-- For image frames that store contiguous data, the output of mat_view()
-- points to the pixel data of the original image frame object.
local function test_image_mat_view_with_contiguous_data(self)
    local w, h = 640, 480
    local mat = _mat_utils.randomImage(w, h, cv2.CV_8UC3, 0, 2 ^ 8)
    self.assertEqual(mat.rows, h)
    self.assertEqual(mat.cols, w)
    self.assertEqual(mat:channels(), 3)

    -- specify the image format
    local rgb_image = Image(mediapipe_lua.kwargs({ image_format = ImageFormat.SRGB, data = mat }))
    self.assertTrue(rgb_image:is_contiguous(), "image frame data should be contiguous")
    self.assertMatEqual(mat, rgb_image:mat_view())

    -- Get 2 data array objects and verify that the image frame's data is the same
    local np_view = rgb_image:mat_view()
    self.assertEqual(rgb_image.data, np_view.data)

    local np_view2 = rgb_image:mat_view()
    self.assertEqual(rgb_image.data, np_view2.data)
end

-- For image frames that store non contiguous data, the output of mat_view()
-- points to the pixel data of the original image frame object.
local function test_image_numpy_view_with_non_contiguous_data(self)
    local w, h = 641, 481
    local mat = _mat_utils.randomImage(w, h, cv2.CV_8UC3, 0, 2 ^ 8)
    self.assertEqual(mat.rows, h)
    self.assertEqual(mat.cols, w)
    self.assertEqual(mat:channels(), 3)

    -- specify the image format
    local rgb_image = Image(mediapipe_lua.kwargs({ image_format = ImageFormat.SRGB, data = mat }))
    self.assertFalse(rgb_image:is_contiguous(), "image frame data should not be contiguous")
    self.assertMatEqual(mat, rgb_image:mat_view())

    -- Get 2 data array objects and verify that the image frame's data is the same
    local np_view = rgb_image:mat_view()
    self.assertEqual(rgb_image.data, np_view.data)

    local np_view2 = rgb_image:mat_view()
    self.assertEqual(rgb_image.data, np_view2.data)
end

local function test_image_create_from_cvmat(self)
    download_utils.download(
        "https://github.com/tensorflow/tfjs-models/raw/master/hand-pose-detection/test_data/hands.jpg",
        __dirname__ .. "/solutions/testdata/hands.jpg",
        mediapipe_lua.kwargs({
            hash = "sha256=240c082e80128ff1ca8a83ce645e2ba4d8bc30f0967b7991cf5fa375bab489e1"
        })
    )
    local image_path = __dirname__ .. "/solutions/testdata/hands.jpg"
    local mat = cv2.cvtColor(cv2.imread(image_path), cv2.COLOR_BGR2RGB) -- mediapipe expect RGB image format, while opencv returns BGR image format
    local rgb_image = Image(mediapipe_lua.kwargs({ image_format = ImageFormat.SRGB, data = mat }))
    self.assertEqual(rgb_image.width, 720)
    self.assertEqual(rgb_image.height, 382)
    self.assertEqual(rgb_image.channels, 3)
    self.assertEqual(rgb_image.image_format, ImageFormat.SRGB)
    self.assertMatEqual(mat, rgb_image:mat_view())
end

local function test_image_create_from_file(self)
    download_utils.download(
        "https://github.com/tensorflow/tfjs-models/raw/master/hand-pose-detection/test_data/hands.jpg",
        __dirname__ .. "/solutions/testdata/hands.jpg",
        mediapipe_lua.kwargs({
            hash = "sha256=240c082e80128ff1ca8a83ce645e2ba4d8bc30f0967b7991cf5fa375bab489e1"
        })
    )
    local image_path = __dirname__ .. "/solutions/testdata/hands.jpg"
    local loaded_image = Image.create_from_file(image_path)
    self.assertEqual(loaded_image.width, 720)
    self.assertEqual(loaded_image.height, 382)
    -- On Mac w/ GPU support, images use 4 channels (SRGBA). Otherwise, all
    -- images use 3 channels (SRGB).
    self.assertIn(loaded_image.channels, { 3, 4 })
    self.assertIn(
        loaded_image.image_format, { ImageFormat.SRGB, ImageFormat.SRGBA }
    )
end

describe("ImageTest", function()
    it("should test_create_image_from_gray_cv_mat", function()
        test_create_image_from_gray_cv_mat(_assert)
    end)
    it("should test_create_image_from_rgb_cv_mat", function()
        test_create_image_from_rgb_cv_mat(_assert)
    end)
    it("should test_create_image_from_rgb48_cv_mat", function()
        test_create_image_from_rgb48_cv_mat(_assert)
    end)
    it("should test_image_mat_view", function()
        test_image_mat_view(_assert)
    end)
    it("should test_image_mat_view_with_contiguous_data", function()
        test_image_mat_view_with_contiguous_data(_assert)
    end)
    it("should test_image_numpy_view_with_non_contiguous_data", function()
        test_image_numpy_view_with_non_contiguous_data(_assert)
    end)
    it("should test_image_create_from_cvmat", function()
        test_image_create_from_cvmat(_assert)
    end)
    it("should test_image_create_from_file", function()
        test_image_create_from_file(_assert)
    end)
end)
