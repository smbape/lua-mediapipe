#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.35/mediapipe/tasks/python/test/components/containers/bounding_box_test.py
--]]

local _assert = require("_assert")

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe
local bounding_box_lib = mediapipe.tasks.lua.components.containers.bounding_box
local rect_lib = mediapipe.tasks.lua.components.containers.rect

local function test_create_bounding_box_from_ctypes_converts_values(self)
    local expected_values = {
        origin_x = 10,
        origin_y = 20,
        width = 40,
        height = 50,
        left = 10,
        top = 20,
        right = 50,
        bottom = 70
    }

    local actual_bounding_box = bounding_box_lib.BoundingBox(mediapipe_lua.kwargs({ origin_x = 10, origin_y = 20, width = 40, height = 50 }))
    self.assertDictAlmostEqual(actual_bounding_box, expected_values)

    local actual_rect = rect_lib.Rect(mediapipe_lua.kwargs({ left = 10, top = 20, right = 50, bottom = 70 }))
    self.assertDictAlmostEqual(actual_rect, expected_values)
end

describe("BoundingBoxTest", function()
    it("should test_create_bounding_box_from_ctypes_converts_values", function()
        test_create_bounding_box_from_ctypes_converts_values(_assert)
    end)
end)
