#!/usr/bin/env lua

--[[
Sources:
    https://colab.research.google.com/github/google-ai-edge/mediapipe-samples/blob/3d23f0e459907af064c3e7494dbb180851e1694c/examples/language_detector/python/%5BMediaPipe_Python_Tasks%5D_Language_Detector.ipynb
    https://github.com/google-ai-edge/mediapipe-samples/blob/3d23f0e459907af064c3e7494dbb180851e1694c/examples/language_detector/python/%5BMediaPipe_Python_Tasks%5D_Language_Detector.ipynb

Title: Language Detector with MediaPipe Tasks
--]]

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe

local download_utils = mediapipe.tasks.lua.core.download_utils

local MEDIAPIPE_SAMPLES_DATA_PATH = mediapipe_lua.fs_utils.findFile("samples") .. "/testdata"

local MODEL_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/language_detector.tflite"
local MODEL_URL = "https://storage.googleapis.com/mediapipe-models/language_detector/language_detector/float32/latest/language_detector.tflite"
local MODEL_HASH = "sha256=7db4f23dfe1ad8966b050b419a865da451143fd43eb6b606a256aadeeb1e5417"
download_utils.download(mediapipe_lua.kwargs({
    output = MODEL_FILE,
    url = MODEL_URL,
    hash = MODEL_HASH,
}))


-- Define the input text that you wants the model to classify.
local INPUT_TEXT = "分久必合合久必分" --@param {type:"string"}

-- STEP 1: Import the necessary modules.
local lua = mediapipe.tasks.lua
local text = mediapipe.tasks.lua.text

-- STEP 2: Create a LanguageDetector object.
local base_options = lua.BaseOptions(mediapipe_lua.kwargs({ model_asset_path = MODEL_FILE }))
local options = text.LanguageDetectorOptions(mediapipe_lua.kwargs({ base_options = base_options }))
local detector = text.LanguageDetector.create_from_options(options)

-- STEP 3: Get the language detcetion result for the input text.
local detection_result = detector:detect(INPUT_TEXT)

-- STEP 4: Process the detection result and print the languages detected and
-- their scores.
for _, detection in detection_result.detections:__ipairs() do
    print(("%s: (%.2f)"):format(detection.language_code, detection.probability))
end
