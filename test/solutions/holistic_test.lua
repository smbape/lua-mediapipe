#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/python/solutions/holistic_test.py
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
local drawing_styles = mediapipe.lua.solutions.drawing_styles
local mp_drawing = mediapipe.lua.solutions.drawing_utils
local mp_holistic = mediapipe.lua.solutions.holistic

local POSE_DIFF_THRESHOLD = 30 -- pixels
local HAND_DIFF_THRESHOLD = 30 -- pixels
local EXPECTED_POSE_LANDMARKS = { { 350, 136 }, { 357, 125 }, { 361, 125 },
    { 365, 125 }, { 344, 124 }, { 340, 123 },
    { 336, 123 }, { 371, 129 }, { 332, 127 },
    { 358, 145 }, { 343, 145 }, { 399, 195 },
    { 297, 183 }, { 415, 282 }, { 221, 199 },
    { 442, 351 }, { 180, 153 }, { 452, 373 },
    { 169, 134 }, { 446, 375 }, { 174, 127 },
    { 441, 366 }, { 178, 135 }, { 364, 359 },
    { 320, 359 }, { 326, 485 }, { 368, 473 },
    { 256, 595 }, { 409, 609 }, { 238, 610 },
    { 402, 629 }, { 296, 635 }, { 468, 641 } }
local EXPECTED_LEFT_HAND_LANDMARKS = { { 444, 358 }, { 437, 361 }, { 434, 369 },
    { 434, 378 }, { 433, 385 }, { 447, 377 },
    { 446, 390 }, { 442, 396 }, { 439, 400 },
    { 450, 379 }, { 449, 392 }, { 444, 398 },
    { 440, 401 }, { 451, 380 }, { 449, 392 },
    { 445, 397 }, { 440, 400 }, { 450, 381 },
    { 448, 390 }, { 445, 395 }, { 442, 398 } }
local EXPECTED_RIGHT_HAND_LANDMARKS = { { 172, 162 }, { 181, 157 }, { 187, 149 },
    { 190, 142 }, { 194, 136 }, { 176, 129 },
    { 177, 116 }, { 177, 108 }, { 175, 101 },
    { 169, 128 }, { 168, 113 }, { 166, 104 },
    { 164, 97 }, { 163, 130 }, { 159, 117 },
    { 155, 110 }, { 153, 103 }, { 157, 136 },
    { 150, 128 }, { 145, 123 }, { 141, 118 } }

function _assert._landmarks_list_to_array(landmark_list, image_shape)
    local rows, cols, _ = unpack(image_shape)

    local landmarks = {}

    for i, lmk in ipairs(landmark_list.landmark:table()) do
        landmarks[i] = { lmk.x * cols, lmk.y * rows }
    end

    return landmarks
end

function _assert._annotate(id, frame, results, idx)
    mp_drawing.draw_landmarks(
        frame,
        results.face_landmarks,
        mp_holistic.FACEMESH_TESSELATION,
        mediapipe_lua.kwargs({
            landmark_drawing_spec = nil,
            connection_drawing_spec = drawing_styles.get_default_face_mesh_tesselation_style()
        }))
    mp_drawing.draw_landmarks(
        frame,
        results.pose_landmarks,
        mp_holistic.POSE_CONNECTIONS,
        mediapipe_lua.kwargs({ landmark_drawing_spec = drawing_styles.get_default_pose_landmarks_style() }))

    local path = __dirname__ .. "/testdata/" .. id .. "_frame_" .. idx .. ".png"
    cv2.imwrite(path, frame)
end

local function test_blank_image(self)
    local holistic = mp_holistic.Holistic()
    local image = cv2.Mat.zeros(100, 100, cv2.CV_8UC3)
    image:setTo(255.0)
    local results = holistic:process(image)
    self.assertIsNone(results.pose_landmarks)
end

local function test_on_image(self, id, static_image_mode, model_complexity,
                             refine_face_landmarks, num_frames)
    download_utils.download(
        "https://teleprogramma.pro/sites/default/files/styles/post_850x666/public/nodes/node_540493_1653677473.jpg",
        __dirname__ .. "/testdata/holistic.jpg",
        mediapipe_lua.kwargs({
            hash="sha256=bdf944c6d894cdb0670559ee79da1b1b1f080a0159c9c272a5c7ab012cf20037"
        })
    )

    local image_path = __dirname__ .. "/testdata/holistic.jpg"
    local image = cv2.imread(image_path)
    local holistic = mp_holistic.Holistic(mediapipe_lua.kwargs({
        static_image_mode = static_image_mode,
        model_complexity = model_complexity,
        refine_face_landmarks = refine_face_landmarks
    }))
    for idx = 0, num_frames - 1 do
        local results = holistic:process(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
        self._annotate("test_on_image_" .. id, image:copy(), results, idx)
        self.assertMatDiffLess(
            self._landmarks_list_to_array(results.pose_landmarks, image.shape),
            EXPECTED_POSE_LANDMARKS,
            POSE_DIFF_THRESHOLD)
        self.assertMatDiffLess(
            self._landmarks_list_to_array(results.left_hand_landmarks, image.shape),
            EXPECTED_LEFT_HAND_LANDMARKS,
            HAND_DIFF_THRESHOLD)
        self.assertMatDiffLess(
            self._landmarks_list_to_array(results.right_hand_landmarks, image.shape),
            EXPECTED_RIGHT_HAND_LANDMARKS,
            HAND_DIFF_THRESHOLD)
        -- TODO: Verify the correctness of the face landmarks.
        self.assertLen(results.face_landmarks.landmark,
            (function()
                if refine_face_landmarks then return 478 end
                return 468
            end)())
    end
end

describe("HolisticTest", function()
    it("should test_blank_image", function()
        test_blank_image(_assert)
    end)

    for _, args in ipairs({
        { 'static_lite',             true,  0, false, 3 },
        { 'static_full',             true,  1, false, 3 },
        { 'static_heavy',            true,  2, false, 3 },
        { 'video_lite',              false, 0, false, 3 },
        { 'video_full',              false, 1, false, 3 },
        { 'video_heavy',             false, 2, false, 3 },
        { 'static_full_refine_face', true,  1, true,  3 },
        { 'video_full_refine_face',  false, 1, true,  3 },
    }) do
        it("should test_on_image " .. args[1], function()
            test_on_image(_assert, unpack(args))
        end)
    end
end)
