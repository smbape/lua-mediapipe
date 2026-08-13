#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.35/mediapipe/tasks/python/test/components/containers/landmark_test.py
--]]

local _assert = require("_assert")
local null = _assert.null

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe
local landmark_lib = mediapipe.tasks.lua.components.containers.landmark

local function test_create_landmark_from_ctypes(self)
    local actual_landmark = landmark_lib.Landmark(mediapipe_lua.kwargs({
        x = 0.1,
        y = 0.2,
        z = 0.3,
        visibility = 0.4,
        presence = 0.5,
        name = 'test_landmark',
    }))

    local expected_values = {
        x = 0.1,
        y = 0.2,
        z = 0.3,
        visibility = 0.4,
        presence = 0.5,
        name = 'test_landmark',
    }

    self.assertDictAlmostEqual(actual_landmark, expected_values)
end

local function test_create_landmark_from_ctypes_without_optional_fields(self)
    local actual_landmark = landmark_lib.Landmark(mediapipe_lua.kwargs({
        x = 0.1,
        y = 0.2,
        z = 0.3,
        visibility = nil,
        presence = nil,
        name = nil,
    }))

    local expected_values = {
        x = 0.1,
        y = 0.2,
        z = 0.3,
        visibility = null,
        presence = null,
        name = null,
    }

    self.assertDictAlmostEqual(actual_landmark, expected_values)
end

describe("LandmarkTest", function()
    it("should test_create_landmark_from_ctypes", function()
        test_create_landmark_from_ctypes(_assert)
    end)
    it("should test_create_landmark_from_ctypes_without_optional_fields", function()
        test_create_landmark_from_ctypes_without_optional_fields(_assert)
    end)
end)


local function test_create_normalized_landmark_from_ctypes(self)
    local actual_landmark = landmark_lib.NormalizedLandmark(mediapipe_lua.kwargs({
        x = 0.1,
        y = 0.2,
        z = 0.3,
        visibility = 0.4,
        presence = 0.5,
        name = 'test_landmark',
    }))

    local expected_values = {
        x = 0.1,
        y = 0.2,
        z = 0.3,
        visibility = 0.4,
        presence = 0.5,
        name = 'test_landmark',
    }
    self.assertDictAlmostEqual(actual_landmark, expected_values)
end

local function test_create_normalized_landmark_from_ctypes_without_optional_fields(self)
    local actual_landmark = landmark_lib.NormalizedLandmark(mediapipe_lua.kwargs({
        x = 0.1,
        y = 0.2,
        z = 0.3,
        visibility = nil,
        presence = nil,
        name = nil,
    }))

    local expected_values = {
        x = 0.1,
        y = 0.2,
        z = 0.3,
        visibility = null,
        presence = null,
        name = null,
    }
    self.assertDictAlmostEqual(actual_landmark, expected_values)
end

describe("NormalizedLandmarkTest", function()
    it("should test_create_normalized_landmark_from_ctypes", function()
        test_create_normalized_landmark_from_ctypes(_assert)
    end)
    it("should test_create_normalized_landmark_from_ctypes_without_optional_fields", function()
        test_create_normalized_landmark_from_ctypes_without_optional_fields(_assert)
    end)
end)
