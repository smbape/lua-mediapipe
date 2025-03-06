#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/python/solutions/hands_test.py
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
local mp_hands = mediapipe.lua.solutions.hands


local LITE_MODEL_DIFF_THRESHOLD = 25 -- pixels
local FULL_MODEL_DIFF_THRESHOLD = 20 -- pixels
local EXPECTED_HAND_COORDINATES_PREDICTION = { { { 580, 34 }, { 504, 50 }, { 459, 94 },
    { 429, 146 }, { 397, 182 }, { 507, 167 },
    { 479, 245 }, { 469, 292 }, { 464, 330 },
    { 545, 180 }, { 534, 265 }, { 533, 319 },
    { 536, 360 }, { 581, 172 }, { 587, 252 },
    { 593, 304 }, { 599, 346 }, { 615, 168 },
    { 628, 223 }, { 638, 258 }, { 648, 288 } },
    { { 138, 343 }, { 211, 330 }, { 257, 286 },
        { 289, 237 }, { 322, 203 }, { 219, 216 },
        { 238, 138 }, { 249, 90 }, { 253, 51 },
        { 177, 204 }, { 184, 115 }, { 187, 60 },
        { 185, 19 }, { 138, 208 }, { 131, 127 },
        { 124, 77 }, { 117, 36 }, { 106, 222 },
        { 92, 159 }, { 79, 124 }, { 68, 93 } } }

function _assert._landmarks_list_to_array(landmark_list, image_shape)
    local rows, cols, _ = unpack(image_shape)

    local landmarks = {}

    for i, lmk in ipairs(landmark_list.landmark:table()) do
        landmarks[i] = { lmk.x * cols, lmk.y * rows, lmk.z * cols }
    end

    return landmarks
end

function _assert._world_landmarks_list_to_array(landmark_list)
    local landmarks = {}

    for i, lmk in ipairs(landmark_list.landmark:table()) do
        landmarks[i] = { lmk.x, lmk.y, lmk.z }
    end

    return landmarks
end

function _assert._annotate(id, frame, results, idx)
    for _, hand_landmarks in ipairs(results.multi_hand_landmarks) do
        mp_drawing.draw_landmarks(
            frame, hand_landmarks, mp_hands.HAND_CONNECTIONS,
            drawing_styles.get_default_hand_landmarks_style(),
            drawing_styles.get_default_hand_connections_style())
    end

    local path = __dirname__ .. "/testdata/" .. id .. "_frame_" .. idx .. ".png"
    cv2.imwrite(path, frame)
end

function _assert._process_video(self, model_complexity, video_path,
                                max_num_hands,
                                num_landmarks,
                                num_dimensions)
    if max_num_hands == nil then
        max_num_hands = 1
    end

    if num_landmarks == nil then
        num_landmarks = 21
    end

    if num_dimensions == nil then
        num_dimensions = 3
    end

    -- Predict pose landmarks for each frame.
    local video_cap = cv2.VideoCapture(video_path)
    local landmarks_per_frame = {}
    local w_landmarks_per_frame = {}
    local hands = mp_hands.Hands(mediapipe_lua.kwargs({
        static_image_mode = false,
        max_num_hands = max_num_hands,
        model_complexity = model_complexity,
        min_detection_confidence = 0.5
    }))

    while true do
        -- Get next frame of the video.
        local success, input_frame = video_cap:read()
        if not success then
            break
        end

        -- Run pose tracker.
        local input_frame = cv2.cvtColor(input_frame, cv2.COLOR_BGR2RGB)
        local frame_shape = input_frame.shape
        local result = hands:process(mediapipe_lua.kwargs({ image = input_frame }))

        local frame_landmarks = {}
        if result.multi_hand_landmarks then
            for idx, landmarks in ipairs(result.multi_hand_landmarks) do
                landmarks = self._landmarks_list_to_array(landmarks, frame_shape)
                frame_landmarks[idx] = landmarks
            end
        end
        landmarks_per_frame[#landmarks_per_frame + 1] = frame_landmarks

        local frame_w_landmarks = {}
        if result.multi_hand_world_landmarks then
            for idx, w_landmarks in ipairs(result.multi_hand_world_landmarks) do
                w_landmarks = self._world_landmarks_list_to_array(w_landmarks)
                frame_w_landmarks[idx] = w_landmarks
            end
        end
        w_landmarks_per_frame[#w_landmarks_per_frame + 1] = frame_w_landmarks
    end

    return cv2.Mat.createFromArray(landmarks_per_frame, cv2.CV_64F),
        cv2.Mat.createFromArray(w_landmarks_per_frame, cv2.CV_64F)
end

local function test_blank_image(self)
    local hands = mp_hands.Hands()
    local image = cv2.Mat.zeros(100, 100, cv2.CV_8UC3)
    image:setTo(255.0)
    local results = hands:process(image)
    self.assertIsNone(results.multi_hand_landmarks)
    self.assertIsNone(results.multi_handedness)
end

local function test_multi_hands(self, id, static_image_mode, model_complexity, num_frames)
    download_utils.download(
        "https://github.com/tensorflow/tfjs-models/raw/master/hand-pose-detection/test_data/hands.jpg",
        __dirname__ .. "/testdata/hands.jpg",
        mediapipe_lua.kwargs({
            hash="sha256=240c082e80128ff1ca8a83ce645e2ba4d8bc30f0967b7991cf5fa375bab489e1"
        })
    )

    local image_path = __dirname__ .. "/testdata/hands.jpg"
    local image = cv2.imread(image_path)
    local rows, cols, _ = unpack(image.shape)

    local hands = mp_hands.Hands(mediapipe_lua.kwargs({
        static_image_mode = static_image_mode,
        max_num_hands = 2,
        model_complexity = model_complexity,
        min_detection_confidence = 0.5
    }))

    for idx = 0, num_frames - 1 do
        local results = hands:process(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
        self._annotate("test_multi_hands_" .. id, image:copy(), results, idx)

        local multi_handedness = {}
        for i, handedness in ipairs(results.multi_handedness) do
            multi_handedness[i] = handedness.classification[0].label
        end
        self.assertLen(multi_handedness, 2)

        local multi_hand_coordinates = {}
        for i, landmarks in ipairs(results.multi_hand_landmarks) do
            self.assertLen(landmarks.landmark, 21)

            local hand_coordinates = {}

            for j, landmark in ipairs(landmarks.landmark:table()) do
                hand_coordinates[j] = {
                    landmark.x * cols,
                    landmark.y * rows,
                }
            end

            multi_hand_coordinates[i] = hand_coordinates
        end
        self.assertLen(multi_hand_coordinates, 2)

        local prediction_error = cv2.absdiff(
            cv2.Mat.createFromArray(multi_hand_coordinates, cv2.CV_64F),
            cv2.Mat.createFromArray(EXPECTED_HAND_COORDINATES_PREDICTION, cv2.CV_64F))

        local diff_threshold = (function()
            if model_complexity == 0 then
                return LITE_MODEL_DIFF_THRESHOLD
            end
            return FULL_MODEL_DIFF_THRESHOLD
        end)()

        self.assertMatLess(prediction_error, diff_threshold)
    end
end

local function test_on_video(self, id, model_complexity, expected_name)
    --[[ Tests hand models on a video. ]]

    download_utils.download(
        "https://github.com/tensorflow/tfjs-models/raw/master/hand-pose-detection/test_data/asl_hand.25fps.mp4",
        __dirname__ .. "/testdata/asl_hand.25fps.mp4",
        mediapipe_lua.kwargs({
            hash="sha256=57c10fb1eb76639edf43e9675213dcc495c51851e32a3592cacaa9437be4f37e"
        })
    )

    -- Set threshold for comparing actual and expected predictions in pixels.
    local diff_threshold = 18
    local world_diff_threshold = 0.05

    local video_path = __dirname__ .. "/testdata/asl_hand.25fps.mp4"
    local actual, actual_world = self:_process_video(model_complexity, video_path)

    local expected_path = __dirname__ .. "/testdata/test_on_video_" .. id .. "_" .. expected_name
    local expected_storage = cv2.FileStorage(expected_path, cv2.FileStorage.READ)

    -- Dump actual .yml.
    local actual_path = __dirname__ .. "/testdata/_test_on_video_" .. id .. "_" .. expected_name
    local actual_storage = cv2.FileStorage(actual_path, cv2.FileStorage.WRITE)
    actual_storage:write("predictions", actual)
    actual_storage:write("w_predictions", actual_world)
    actual_storage:release()

    -- Validate actual vs. expected landmarks.
    local expected = expected_storage:getNode("predictions"):mat()
    self.assertListEqual(actual.shape, expected.shape, ('Unexpected shape of predictions: %s instead of %s'):format(
        inspect(actual.shape), inspect(expected.shape)))
    self.assertMatDiffLess(_mat_utils.sliceLastDim(actual, 0, 2), _mat_utils.sliceLastDim(expected, 0, 2), diff_threshold)

    -- Validate actual vs. expected world landmarks.
    local expected_world = expected_storage:getNode("w_predictions"):mat()
    self.assertListEqual(actual_world.shape, expected_world.shape,
        ('Unexpected shape of world predictions: %s instead of %s'):format(
            inspect(actual_world.shape), inspect(expected_world.shape)))
    self.assertMatDiffLess(actual_world, expected_world, world_diff_threshold)
end

describe("HandsTest", function()
    it("should test_blank_image", function()
        test_blank_image(_assert)
    end)

    for _, args in ipairs({
        { 'static_image_mode_with_lite_model', true,  0, 5 },
        { 'video_mode_with_lite_model',        false, 0, 10 },
        { 'static_image_mode_with_full_model', true,  1, 5 },
        { 'video_mode_with_full_model',        false, 1, 10 },
    }) do
        it("should test_multi_hands " .. args[1], function()
            test_multi_hands(_assert, unpack(args))
        end)
    end

    for _, args in ipairs({
        { 'full', 1, 'asl_hand.full.yml' },
    }) do
        it("should test_on_video " .. args[1], function()
            test_on_video(_assert, unpack(args))
        end)
    end
end)
