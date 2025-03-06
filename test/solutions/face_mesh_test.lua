#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/python/solutions/face_mesh_test.py
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
local drawing_styles = mediapipe.lua.solutions.drawing_styles
local mp_drawing = mediapipe.lua.solutions.drawing_utils
local mp_faces = mediapipe.lua.solutions.face_mesh

local DIFF_THRESHOLD = 5 -- pixels
local EYE_INDICES_TO_LANDMARKS = {
    [33] = { 345, 178 },
    [7] = { 348, 179 },
    [163] = { 352, 178 },
    [144] = { 357, 179 },
    [145] = { 365, 179 },
    [153] = { 371, 179 },
    [154] = { 378, 178 },
    [155] = { 381, 177 },
    [133] = { 383, 177 },
    [246] = { 347, 175 },
    [161] = { 350, 174 },
    [160] = { 355, 172 },
    [159] = { 362, 170 },
    [158] = { 368, 171 },
    [157] = { 375, 172 },
    [173] = { 380, 175 },
    [263] = { 467, 176 },
    [249] = { 464, 177 },
    [390] = { 460, 177 },
    [373] = { 455, 178 },
    [374] = { 448, 179 },
    [380] = { 441, 179 },
    [381] = { 435, 178 },
    [382] = { 432, 177 },
    [362] = { 430, 177 },
    [466] = { 465, 175 },
    [388] = { 462, 173 },
    [387] = { 457, 171 },
    [386] = { 450, 170 },
    [385] = { 444, 171 },
    [384] = { 437, 172 },
    [398] = { 432, 175 }
}

local IRIS_INDICES_TO_LANDMARKS = {
    [468] = { 362, 175 },
    [469] = { 371, 175 },
    [470] = { 362, 167 },
    [471] = { 354, 175 },
    [472] = { 363, 182 },
    [473] = { 449, 174 },
    [474] = { 458, 174 },
    [475] = { 449, 167 },
    [476] = { 440, 174 },
    [477] = { 449, 181 }
}

function _assert._annotate(id, frame, results, idx, draw_iris)
    for _, face_landmarks in ipairs(results.multi_face_landmarks) do
        mp_drawing.draw_landmarks(
            frame,
            face_landmarks,
            mp_faces.FACEMESH_TESSELATION,
            mediapipe_lua.kwargs({
                landmark_drawing_spec = nil,
                connection_drawing_spec = drawing_styles
                    .get_default_face_mesh_tesselation_style()
            }))
        mp_drawing.draw_landmarks(
            frame,
            face_landmarks,
            mp_faces.FACEMESH_CONTOURS,
            mediapipe_lua.kwargs({
                landmark_drawing_spec = nil,
                connection_drawing_spec = drawing_styles
                    .get_default_face_mesh_contours_style()
            }))
        if draw_iris then
            mp_drawing.draw_landmarks(
                frame,
                face_landmarks,
                mp_faces.FACEMESH_IRISES,
                mediapipe_lua.kwargs({
                    landmark_drawing_spec = nil,
                    connection_drawing_spec = drawing_styles
                        .get_default_face_mesh_iris_connections_style()
                }))
        end
    end

    local path = __dirname__ .. "/testdata/" .. id .. "_frame_" .. idx .. ".png"
    cv2.imwrite(path, frame)
end

local function test_blank_image(self)
    local faces = mp_faces.FaceMesh()
    local image = cv2.Mat.zeros(100, 100, cv2.CV_8UC3)
    image:setTo(255.0)
    local results = faces:process(image)
    self.assertIsNone(results.multi_face_landmarks)
end

local function test_face(self, id, static_image_mode, refine_landmarks, num_frames)
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
    local faces = mp_faces.FaceMesh(mediapipe_lua.kwargs({
        static_image_mode = static_image_mode,
        refine_landmarks = refine_landmarks,
        min_detection_confidence = 0.5
    }))

    for idx = 0, num_frames - 1 do
        local results = faces:process(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
        self._annotate("test_face_" .. id, image:copy(), results, idx, refine_landmarks)

        local multi_face_landmarks = {}

        for _, landmarks in ipairs(results.multi_face_landmarks) do
            self.assertLen(landmarks.landmark, (function()
                if refine_landmarks then
                    return mp_faces.FACEMESH_NUM_LANDMARKS_WITH_IRISES
                end
                return mp_faces.FACEMESH_NUM_LANDMARKS
            end)())

            local face_landmarks = {}
            for i, landmark in ipairs(landmarks.landmark:table()) do
                face_landmarks[i] = { landmark.x * cols, landmark.y * rows }
            end

            multi_face_landmarks[#multi_face_landmarks + 1] = face_landmarks
        end

        self.assertLen(multi_face_landmarks, 1)

        -- Verify the eye landmarks are correct as sanity check.
        for eye_idx, gt_lds in pairs(EYE_INDICES_TO_LANDMARKS) do
            local prediction_error = cv2.absdiff(
                cv2.Mat.createFromArray(multi_face_landmarks[0 + INDEX_BASE][eye_idx + INDEX_BASE], cv2.CV_32F),
                cv2.Mat.createFromArray(gt_lds, cv2.CV_32F))
            self.assertMatLess(prediction_error, DIFF_THRESHOLD)
        end

        if refine_landmarks then
            for iris_idx, gt_lds in pairs(IRIS_INDICES_TO_LANDMARKS) do
                local prediction_error = cv2.absdiff(
                    cv2.Mat.createFromArray(multi_face_landmarks[0 + INDEX_BASE][iris_idx + INDEX_BASE], cv2.CV_32F),
                    cv2.Mat.createFromArray(gt_lds, cv2.CV_32F))
                self.assertMatLess(prediction_error, DIFF_THRESHOLD)
            end
        end
    end
end

describe("FaceMeshTest", function()
    it("should test_blank_image", function()
        test_blank_image(_assert)
    end)

    for _, args in ipairs({
        { 'static_image_mode_no_attention',   true,  false, 5 },
        { 'static_image_mode_with_attention', true,  true,  5 },
        { 'streaming_mode_no_attention',      false, false, 10 },
        { 'streaming_mode_with_attention',    false, true,  10 },
    }) do
        it("should test_face " .. args[1], function()
            test_face(_assert, unpack(args))
        end)
    end
end)
