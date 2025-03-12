#!/usr/bin/env lua

--[[
Sources:
    https://colab.research.google.com/github/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/text_classification/python/text_classifier.ipynb
    https://github.com/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/text_classification/python/text_classifier.ipynb

Title: Text Classifier with MediaPipe Tasks
--]]

local INDEX_BASE = 1 -- lua is 1-based indexed

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe

local download_utils = mediapipe.lua.solutions.download_utils

local MEDIAPIPE_SAMPLES_DATA_PATH = mediapipe_lua.fs_utils.findFile("samples") .. "/testdata"

local MODEL_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/bert_classifier.tflite"
local MODEL_URL = "https://storage.googleapis.com/mediapipe-models/text_classifier/bert_classifier/float32/1/bert_classifier.tflite"
local MODEL_HASH = "sha256=9b45012ab143d88d61e10ea501d6c8763f7202b86fa987711519d89bfa2a88b1"
download_utils.download(mediapipe_lua.kwargs({
    file = MODEL_FILE,
    url = MODEL_URL,
    hash = MODEL_HASH,
}))


-- Define the input text that you wants the model to classify.
local INPUT_TEXT = "I'm looking forward to what will come next."

-- STEP 1: Import the necessary modules.
local lua = mediapipe.tasks.lua
local text = mediapipe.tasks.lua.text

-- STEP 2: Create an TextClassifier object.
local base_options = lua.BaseOptions(mediapipe_lua.kwargs({ model_asset_path = MODEL_FILE }))
local options = text.TextClassifierOptions(mediapipe_lua.kwargs({ base_options = base_options }))
local classifier = text.TextClassifier.create_from_options(options)

-- STEP 3: Classify the input text.
local classification_result = classifier:classify(INPUT_TEXT)

-- STEP 4: Process the classification result. In this case, print out the most likely category.
local top_category = classification_result.classifications[0 + INDEX_BASE].categories[0 + INDEX_BASE]
print(("%s: (%.2f)"):format(top_category.category_name, top_category.score))
