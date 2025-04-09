#!/usr/bin/env lua

--[[
Sources:
    https://colab.research.google.com/github/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/text_embedder/python/text_embedder.ipynb
    https://github.com/google-ai-edge/mediapipe-samples/blob/8c1d61ad6eb12f1f98ed95c3c8b64cb9801f3230/examples/text_embedder/python/text_embedder.ipynb

Title: Text Embedding with MediaPipe Tasks
--]]

local INDEX_BASE = 1 -- lua is 1-based indexed

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe

local download_utils = mediapipe.lua.solutions.download_utils

local MEDIAPIPE_SAMPLES_DATA_PATH = mediapipe_lua.fs_utils.findFile("samples") .. "/testdata"

local MODEL_FILE = MEDIAPIPE_SAMPLES_DATA_PATH .. "/bert_embedder.tflite"
local MODEL_URL = "https://storage.googleapis.com/mediapipe-models/text_embedder/bert_embedder/float32/1/bert_embedder.tflite"
local MODEL_HASH = "sha256=02ae6279faf86c2cd4ff18f61876c878bcc0b572b472f0678897a184c4ac7ef6"
download_utils.download(mediapipe_lua.kwargs({
    output = MODEL_FILE,
    url = MODEL_URL,
    hash = MODEL_HASH,
}))

local lua = mediapipe.tasks.lua
local text = mediapipe.tasks.lua.text

-- Create your base options with the model that was downloaded earlier
local base_options = lua.BaseOptions(mediapipe_lua.kwargs({ model_asset_path = MODEL_FILE }))

-- Set your values for using normalization and quantization
local l2_normalize = true --@param {type:"boolean"}
local quantize = false    --@param {type:"boolean"}

-- Create the final set of options for the Embedder
local options = text.TextEmbedderOptions(mediapipe_lua.kwargs({
    base_options = base_options, l2_normalize = l2_normalize, quantize = quantize }))

local embedder = text.TextEmbedder.create_from_options(options)

-- Retrieve the first and second sets of text that will be compared
local first_text = "I'm feeling so good" --@param {type:"string"}
local second_text = "I'm okay I guess"   --@param {type:"string"}

-- Convert both sets of text to embeddings
local first_embedding_result = embedder:embed(first_text)
local second_embedding_result = embedder:embed(second_text)

-- Calculate and print similarity
local similarity = text.TextEmbedder.cosine_similarity(
    first_embedding_result.embeddings[0 + INDEX_BASE],
    second_embedding_result.embeddings[0 + INDEX_BASE])
print("similarity = " .. similarity)
