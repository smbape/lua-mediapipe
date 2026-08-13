#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.35/mediapipe/tasks/python/test/components/containers/category_test.py
--]]

local _assert = require("_assert")

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe
local category_lib = mediapipe.tasks.lua.components.containers.category

local null = _assert.null

local _CATEGORY_WITH_NAMES = category_lib.Category(mediapipe_lua.kwargs({
    index = 1,
    score = 0.9,
    category_name = 'test_category_with_names',
    display_name = 'Test Category 1',
}))
local _DICT_WITH_NAMES = {
    index = 1,
    score = 0.9,
    category_name = 'test_category_with_names',
    display_name = 'Test Category 1',
}
local _CATEGORY_WITHOUT_NAMES = category_lib.Category(mediapipe_lua.kwargs({
    index = 2,
    score = 0.8,
    category_name = nil,
    display_name = nil,
}))
local _DICT_WITHOUT_NAMES = {
    index = 2,
    score = 0.8,
    category_name = null,
    display_name = null,
}


local function test_create_category_from_ctypes(self)
    local actual_category = _CATEGORY_WITH_NAMES
    self.assertDictAlmostEqual(actual_category, _DICT_WITH_NAMES)
end

local function test_create_category_from_ctypes_without_name_fields(self)
    local actual_category = _CATEGORY_WITHOUT_NAMES
    self.assertDictAlmostEqual(actual_category, _DICT_WITHOUT_NAMES)
end

local function test_create_category_from_ctypes_with_unknown_index(self)
    local category = category_lib.Category(mediapipe_lua.kwargs({
        index = -1,
        score = 0.8,
        category_name = nil,
        display_name = nil,
    }))

    self.assertDictAlmostEqual(category, {
        index = -1,
        score = 0.8,
        category_name = null,
        display_name = null,
    })
end

describe("CategoryTest", function()
    it("should test_create_category_from_ctypes", function()
        test_create_category_from_ctypes(_assert)
    end)
    it("should test_create_category_from_ctypes_without_name_fields", function()
        test_create_category_from_ctypes_without_name_fields(_assert)
    end)
    it("should test_create_category_from_ctypes_with_unknown_index", function()
        test_create_category_from_ctypes_with_unknown_index(_assert)
    end)
end)
