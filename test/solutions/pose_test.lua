#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/python/solutions/pose_test.py
--]]

local inspect = require("inspect")
local unpack = table.unpack or unpack ---@diagnostic disable-line: deprecated

local _assert = require("_assert")
local _mat_utils = require("_mat_utils")

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe
local download_utils = mediapipe.lua.solutions.download_utils
local __dirname__ = mediapipe_lua.fs_utils.absolute(tostring(arg[0]:gsub("[/\\][^/\\]+$", "")))

local opencv_lua = require("opencv_lua")
local cv2 = opencv_lua.cv

-- resources dependency
-- undeclared dependency
local drawing_styles = mediapipe.lua.solutions.drawing_styles
local mp_drawing = mediapipe.lua.solutions.drawing_utils
local mp_pose = mediapipe.lua.solutions.pose

local DIFF_THRESHOLD = 15 -- pixels
local EXPECTED_POSE_LANDMARKS = { { 460, 283 }, { 467, 273 }, { 471, 273 },
    { 474, 273 }, { 465, 273 }, { 465, 273 },
    { 466, 273 }, { 491, 277 }, { 480, 277 },
    { 470, 294 }, { 465, 294 }, { 545, 319 },
    { 453, 329 }, { 622, 323 }, { 375, 316 },
    { 696, 316 }, { 299, 307 }, { 719, 316 },
    { 278, 306 }, { 721, 311 }, { 274, 304 },
    { 713, 313 }, { 283, 306 }, { 520, 476 },
    { 467, 471 }, { 612, 550 }, { 358, 490 },
    { 701, 613 }, { 349, 611 }, { 709, 624 },
    { 363, 630 }, { 730, 633 }, { 303, 628 } }
local WORLD_DIFF_THRESHOLD = 0.2 -- meters
local EXPECTED_POSE_WORLD_LANDMARKS = {
    { -0.11, -0.59, -0.15 }, { -0.09, -0.64, -0.16 }, { -0.09, -0.64, -0.16 },
    { -0.09, -0.64, -0.16 }, { -0.11, -0.64, -0.14 }, { -0.11, -0.64, -0.14 },
    { -0.11, -0.64, -0.14 }, { 0.01, -0.65, -0.15 }, { -0.06, -0.64, -0.05 },
    { -0.07, -0.57, -0.15 }, { -0.09, -0.57, -0.12 }, { 0.18, -0.49, -0.09 },
    { -0.14, -0.5,  -0.03 }, { 0.41, -0.48, -0.11 }, { -0.42, -0.5, -0.02 },
    { 0.64,  -0.49, -0.17 }, { -0.63, -0.51, -0.13 }, { 0.7, -0.5, -0.19 },
    { -0.71, -0.53, -0.15 }, { 0.72, -0.51, -0.23 }, { -0.69, -0.54, -0.19 },
    { 0.66,  -0.49, -0.19 }, { -0.64, -0.52, -0.15 }, { 0.09, 0., -0.04 },
    { -0.09, -0.,  0.03 }, { 0.41, 0.23, -0.09 }, { -0.43, 0.1, -0.11 },
    { 0.69,  0.49, -0.04 }, { -0.48, 0.47, -0.02 }, { 0.72, 0.52, -0.04 },
    { -0.48, 0.51, -0.02 }, { 0.8, 0.5, -0.14 }, { -0.59, 0.52, -0.11 },
}
local IOU_THRESHOLD = 0.85 -- percents

function _assert._landmarks_list_to_array(landmark_list, image_shape)
    local rows, cols, _ = unpack(image_shape)

    local landmarks = {}

    for i, lmk in ipairs(landmark_list.landmark:table()) do
        landmarks[i] = { lmk.x * cols, lmk.y * rows, lmk.z * cols }
    end

    return cv2.Mat.createFromArray(landmarks, cv2.CV_64F)
end

function _assert._world_landmarks_list_to_array(landmark_list)
    local landmarks = {}

    for i, lmk in ipairs(landmark_list.landmark:table()) do
        landmarks[i] = { lmk.x, lmk.y, lmk.z }
    end

    return cv2.Mat.createFromArray(landmarks, cv2.CV_64F)
end

function _assert._get_output_path(id, name)
    return __dirname__ .. "/testdata/" .. id .. name
end

function _assert._annotate(self, id, frame, results, idx)
    mp_drawing.draw_landmarks(
        frame,
        results.pose_landmarks,
        mp_pose.POSE_CONNECTIONS,
        mediapipe_lua.kwargs({ landmark_drawing_spec = drawing_styles.get_default_pose_landmarks_style() }))
    local path = self._get_output_path(id, ('_frame_%d.png'):format(idx))
    cv2.imwrite(path, frame)
end

function _assert._annotate_segmentation(self, id, segmentation, expected_segmentation, idx)
    local path = self._get_output_path(id, ('_segmentation_%d.png'):format(idx))
    cv2.imwrite(path, self._segmentation_to_bgr(segmentation))
    local path = self._get_output_path(id, ('_segmentation_diff_%d.png'):format(idx))
    cv2.imwrite(path, self._segmentation_diff_to_bgr(expected_segmentation, segmentation))
end

function _assert._bgr_to_segmentation(self, img, back_color, front_color)
    if back_color == nil then
        back_color = { 255, 0, 0 }
    end

    if front_color == nil then
        front_color = { 0, 0, 255 }
    end

    local is_back = cv2.inRange(img, back_color, back_color)
    local is_front = cv2.inRange(img, front_color, front_color)

    -- Check that all pixels are either front or back.
    self.assertEqual(
        cv2.countNonZero(is_back) + cv2.countNonZero(is_front),
        img:total(),
        'image is not a valid segmentation image'
    )

    return is_front
end

function _assert._segmentation_to_bgr(segm, back_color, front_color)
    if back_color == nil then
        back_color = { 255, 0, 0 }
    end

    if front_color == nil then
        front_color = { 0, 0, 255 }
    end

    local height, width = unpack(segm.shape)
    local img = cv2.Mat.zeros(height, width, cv2.CV_8UC3)
    img:setTo(back_color)
    img:setTo(front_color, segm)
    return img
end

function _assert._segmentation_iou(segm_expected, segm_actual)
    local intersection = segm_expected * segm_actual
    local expected_dot = segm_expected * segm_expected
    local actual_dot = segm_actual * segm_actual
    local eps = 2 ^ (-52)
    local result = cv2.countNonZero(intersection) / (cv2.countNonZero(expected_dot) +
        cv2.countNonZero(actual_dot) -
        cv2.countNonZero(intersection) + eps)
    return result
end

function _assert._segmentation_diff_to_bgr(segm_expected, segm_actual, expected_color, actual_color)
    if expected_color == nil then
        expected_color = { 0, 255, 0 }
    end

    if actual_color == nil then
        actual_color = { 255, 0, 0 }
    end

    local height, width = unpack(segm_expected.shape)
    local img = cv2.Mat.zeros(height, width, cv2.CV_8UC3)
    img:setTo(expected_color, cv2.bitwise_and(segm_expected, cv2.bitwise_not(segm_actual)))
    img:setTo(actual_color, cv2.bitwise_and(cv2.bitwise_not(segm_expected), segm_actual))
    return img
end

local function test_blank_image(self)
    local pose = mp_pose.Pose(mediapipe_lua.kwargs({
        enable_segmentation = true
    }))
    local image = cv2.Mat.zeros(100, 100, cv2.CV_8UC3)
    image:setTo(255.0)
    local results = pose:process(image)
    self.assertIsNone(results.pose_landmarks)
    self.assertIsNone(results.segmentation_mask)
end

local function test_blank_image_with_extra_settings(self)
    local pose = mp_pose.Pose(mediapipe_lua.kwargs({
        enable_segmentation = true,
        extra_settings = mp_pose.ExtraSettings(mediapipe_lua.kwargs({
            disallow_service_default_initialization = true
        })),
    }))
    local image = cv2.Mat.zeros(100, 100, cv2.CV_8UC3)
    image:setTo(255.0)
    local results = pose:process(image)
    self.assertIsNone(results.pose_landmarks)
    self.assertIsNone(results.segmentation_mask)
end

local function test_on_image(self, id, static_image_mode, model_complexity, num_frames)
    download_utils.download(
        "https://github.com/tensorflow/tfjs-models/raw/master/pose-detection/test_data/pose.jpg",
        __dirname__ .. "/testdata/pose.jpg",
        mediapipe_lua.kwargs({
            hash = "sha256=c8a830ed683c0276d713dd5aeda28f415f10cd6291972084a40d0d8b934ed62b"
        })
    )

    download_utils.download(
        "https://github.com/tensorflow/tfjs-models/raw/master/pose-detection/test_data/pose_segmentation.png",
        __dirname__ .. "/testdata/pose_segmentation.png",
        mediapipe_lua.kwargs({
            hash = "sha256=4c227e40deb9522752e0c9397ca092fd38252a83f7929d8910ca43f14cf82482"
        })
    )

    local image_path = __dirname__ .. "/testdata/pose.jpg"
    local expected_segmentation_path = __dirname__ .. "/testdata/pose_segmentation.png"
    local image = cv2.imread(image_path)
    local expected_segmentation = self:_bgr_to_segmentation(cv2.cvtColor(cv2.imread(expected_segmentation_path),
        cv2.COLOR_BGR2RGB))

    local pose = mp_pose.Pose(mediapipe_lua.kwargs({
        static_image_mode = static_image_mode,
        model_complexity = model_complexity,
        enable_segmentation = true
    }))
    for idx = 0, num_frames - 1 do
        local results = pose:process(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
        local segmentation = results.segmentation_mask:convertTo(cv2.CV_8U) * 255

        -- TODO: Add rendering of world 3D when supported.
        self:_annotate("test_on_image_" .. id, image:copy(), results, idx)
        self:_annotate_segmentation("test_on_image_" .. id, segmentation, expected_segmentation, idx)

        self.assertMatDiffLess(
            self._landmarks_list_to_array(results.pose_landmarks, image.shape):colRange(0, 2),
            EXPECTED_POSE_LANDMARKS, DIFF_THRESHOLD)
        self.assertMatDiffLess(
            self._world_landmarks_list_to_array(results.pose_world_landmarks),
            EXPECTED_POSE_WORLD_LANDMARKS, WORLD_DIFF_THRESHOLD)
        self.assertGreaterEqual(
            self._segmentation_iou(expected_segmentation, segmentation),
            IOU_THRESHOLD)
    end
end

local function test_on_video(self, id, model_complexity, expected_name)
    download_utils.download(
        "https://github.com/tensorflow/tfjs-models/raw/master/pose-detection/test_data/pose_squats.mp4",
        __dirname__ .. "/testdata/pose_squats.mp4",
        mediapipe_lua.kwargs({
            hash = "sha256=ea9151e447b301985d5d65666551ef863b369a2e0f3a71ddd58abef2e722f96a"
        })
    )

    -- Set threshold for comparing actual and expected predictions in pixels.
    local diff_threshold = 15
    local world_diff_threshold = 0.1

    local video_path = __dirname__ .. "/testdata/pose_squats.mp4"

    -- Predict pose landmarks for each frame.
    local video_cap = cv2.VideoCapture(video_path)
    local actual_per_frame = {}
    local actual_world_per_frame = {}
    local frame_idx = 0
    local pose = mp_pose.Pose(mediapipe_lua.kwargs({
        static_image_mode = false,
        model_complexity = model_complexity
    }))
    while true do
        -- Without this, memory grows indefinitely
        collectgarbage()

        -- Get next frame of the video.
        local success, input_frame = video_cap:read()
        if not success then
            break
        end

        -- Run pose tracker.
        local input_frame = cv2.cvtColor(input_frame, cv2.COLOR_BGR2RGB)
        local result = pose:process(mediapipe_lua.kwargs({ image = input_frame }))
        local pose_landmarks = self._landmarks_list_to_array(result.pose_landmarks,
            input_frame.shape)
        local pose_world_landmarks = self._world_landmarks_list_to_array(
            result.pose_world_landmarks)

        actual_per_frame[#actual_per_frame + 1] = pose_landmarks:table()
        actual_world_per_frame[#actual_world_per_frame + 1] = pose_world_landmarks:table()

        input_frame = cv2.cvtColor(input_frame, cv2.COLOR_RGB2BGR)
        self:_annotate("test_on_video_" .. id, input_frame, result, frame_idx)
        frame_idx = frame_idx + 1
    end

    local actual = cv2.Mat.createFromArray(actual_per_frame, cv2.CV_64F):reshape(3,
        { #actual_per_frame, #actual_per_frame[1] })
    local actual_world = cv2.Mat.createFromArray(actual_world_per_frame, cv2.CV_64F):reshape(3,
        { #actual_per_frame, #actual_per_frame[1] })

    local expected_path = __dirname__ .. "/testdata/test_on_video_" .. id .. "_" .. expected_name
    local expected_storage = cv2.FileStorage(expected_path, cv2.FileStorage.READ)

    -- Dump actual .yml.
    local actual_path = __dirname__ .. "/testdata/_test_on_video_" .. id .. "_" .. expected_name
    local actual_storage = cv2.FileStorage(actual_path, cv2.FileStorage.WRITE)
    actual_storage:write("predictions", actual)
    actual_storage:write("predictions_world", actual_world)
    actual_storage:release()

    -- Validate actual vs. expected landmarks.
    local expected = expected_storage:getNode("predictions"):mat()
    self.assertListEqual(actual.shape, expected.shape, ('Unexpected shape of predictions: %s instead of %s'):format(
        inspect(actual.shape), inspect(expected.shape)))
    self.assertMatDiffLess(_mat_utils.sliceLastDim(actual, 0, 2), _mat_utils.sliceLastDim(expected, 0, 2), diff_threshold)

    -- Validate actual vs. expected world landmarks.
    local expected_world = expected_storage:getNode("predictions_world"):mat()
    self.assertListEqual(actual_world.shape, expected_world.shape,
        ('Unexpected shape of world predictions: %s instead of %s'):format(
            inspect(actual_world.shape), inspect(expected_world.shape)))
    self.assertMatDiffLess(actual_world, expected_world, world_diff_threshold)
end

describe("PoseTest", function()
    it("should test_blank_image", function()
        test_blank_image(_assert)
    end)

    it("should test_blank_image_with_extra_settings", function()
        test_blank_image_with_extra_settings(_assert)
    end)

    for _, args in ipairs({
        { 'static_lite',  true,  0, 3 },
        { 'static_full',  true,  1, 3 },
        { 'static_heavy', true,  2, 3 },
        { 'video_lite',   false, 0, 3 },
        { 'video_full',   false, 1, 3 },
        { 'video_heavy',  false, 2, 3 },
    }) do
        it("should test_on_image " .. args[1], function()
            test_on_image(_assert, unpack(args))
        end)
    end

    for _, args in ipairs({
        { 'full', 1, 'pose_squats.full.yml' },
    }) do
        it("should test_on_video " .. args[1], function()
            test_on_video(_assert, unpack(args))
        end)
    end
end)
