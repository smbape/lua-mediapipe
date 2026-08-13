#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.35/mediapipe/tasks/python/test/core/base_options_test.py
--]]

local _assert = require("_assert")

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe
local base_options_lib = mediapipe.tasks.lua.core.base_options

local function test_convert_to_ctypes_with_model_asset_path(self)
    local options = base_options_lib.BaseOptions(mediapipe_lua.kwargs({ model_asset_path = '/path/to/model' }))
    self.assertEqual(options.model_asset_path, '/path/to/model')
    self.assertIsNone(options.model_asset_buffer)
    self.assertEqual(
        options.delegate, base_options_lib.BaseOptions.Delegate.CPU
    )
end

local function test_convert_to_ctypes_with_model_asset_buffer(self)
    local options = base_options_lib.BaseOptions(mediapipe_lua.kwargs({ model_asset_buffer = 'buffer' }))
    self.assertIsNone(options.model_asset_path)
    self.assertEqual(options.model_asset_buffer, 'buffer')
    self.assertEqual(
        options.delegate, base_options_lib.BaseOptions.Delegate.CPU
    )
end

local function test_convert_to_ctypes_with_gpu_delegate(self)
    local options = base_options_lib.BaseOptions(mediapipe_lua.kwargs({
        model_asset_path = '/path/to/model',
        delegate = base_options_lib.BaseOptions.Delegate.GPU,
    }))
    self.assertEqual(options.model_asset_path, '/path/to/model')
    self.assertEqual(
        options.delegate, base_options_lib.BaseOptions.Delegate.GPU
    )
end

local function test_convert_to_ctypes_without_delegate(self)
    local options = base_options_lib.BaseOptions(mediapipe_lua.kwargs({
        model_asset_path = '/path/to/model', delegate = nil
    }))
    self.assertEqual(options.model_asset_path, '/path/to/model')
    self.assertEqual(
        options.delegate, base_options_lib.BaseOptions.Delegate.CPU
    )
end

describe("BaseOptionsTest", function()
    it("should test_convert_to_ctypes_with_model_asset_path", function()
        test_convert_to_ctypes_with_model_asset_path(_assert)
    end)
    it("should test_convert_to_ctypes_with_model_asset_buffer", function()
        test_convert_to_ctypes_with_model_asset_buffer(_assert)
    end)
    it("should test_convert_to_ctypes_with_gpu_delegate", function()
        test_convert_to_ctypes_with_gpu_delegate(_assert)
    end)
    it("should test_convert_to_ctypes_without_delegate", function()
        test_convert_to_ctypes_without_delegate(_assert)
    end)
end)
