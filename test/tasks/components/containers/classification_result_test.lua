#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.35/mediapipe/tasks/python/test/components/containers/classification_result_test.py
--]]

local _assert = require("_assert")

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe
local category_lib = mediapipe.tasks.lua.components.containers.category
local classification_result_lib = mediapipe.tasks.lua.components.containers.classification_result

local INDEX_BASE = 1

local unpack = table.unpack or unpack ---@diagnostic disable-line: deprecated

local function is_callable(v)
    local typ = type(v)

    if typ == "number" or
        typ == "string" or
        typ == "boolean" or
        typ == "thread" then
        return false
    end

    if typ == "table" or typ == "userdata" then
        local metatable = getmetatable(v)
        return type(metatable) == "table" and type(rawget(metatable, "__call")) == "function"
    end

    return true
end

---@generic T
---@param ctor T
---@param init number|table
---@return T[]
local function new_table(ctor, init)
    local array = {}
    if type(init) == "number" then
        for i = 1, init do
            if is_callable(ctor) then
                array[i] = ctor()
            else
                array[i] = ctor
            end
        end
    else
        for i, initializer_list in ipairs(init) do
            array[i] = ctor(unpack(initializer_list))
        end
    end
    return array
end

local _MOCK_CATEGORY_NAME = "test_category"
local _MOCK_DISPLAY_NAME = "Test Category"
local _MOCK_TIMESTAMP_MS = 1000
local _MOCK_HEAD_NAME = "Head"
local _MOCK_HEAD_INDEX = 0
local _MOCK_CATEGORY = category_lib.Category(mediapipe_lua.kwargs({
    index = 1,
    score = 0.95,
    category_name = _MOCK_CATEGORY_NAME,
    display_name = _MOCK_DISPLAY_NAME,
}))


local function _create_classification_result(...)
    local args = { n = select("#", ...), ... }
    local has_kwarg = mediapipe_lua.kwargs.isinstance(args[args.n])
    local kwargs = has_kwarg and args[args.n] or mediapipe_lua.kwargs()
    local usedkw = 0

    -- get argument categories_count
    local categories_count
    local has_categories_count = false
    if (not has_kwarg) or args.n > 1 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("categories_count") then
            error("categories_count was both specified as a Positional and NamedParameter")
        end
        has_categories_count = args.n >= 1
        if has_categories_count then
            categories_count = args[1]
        end
    elseif kwargs:has("categories_count") then
        -- named parameter
        has_categories_count = true
        categories_count = kwargs:get("categories_count")
        usedkw = usedkw + 1
    else
        error("categories_count is mandatory")
    end

    -- get argument classifications_count
    local classifications_count
    local has_classifications_count = false
    if (not has_kwarg) or args.n > 2 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("classifications_count") then
            error("classifications_count was both specified as a Positional and NamedParameter")
        end
        has_classifications_count = args.n >= 2
        if has_classifications_count then
            classifications_count = args[2]
        end
    elseif kwargs:has("classifications_count") then
        -- named parameter
        has_classifications_count = true
        classifications_count = kwargs:get("classifications_count")
        usedkw = usedkw + 1
    else
        error("classifications_count is mandatory")
    end

    if usedkw ~= kwargs:size() then
        error("there are " .. (kwargs:size() - usedkw) .. " unknown named parameters")
    end

    --- ====================== ---
    --- CODE LOGIC STARTS HERE ---
    --- ====================== ---

    --[[ Creates a ClassificationResultC struct.

  Args:
    categories_count: The number of categories to create.
    classifications_count: The number of classifications to create.

  Returns:
    A ClassificationResultC struct with the given properties.
  --]]
    local category = category_lib.Category(mediapipe_lua.kwargs({
        index = _MOCK_CATEGORY.index,
        score = _MOCK_CATEGORY.score,
        category_name = _MOCK_CATEGORY_NAME,
        display_name = _MOCK_DISPLAY_NAME,
    }))
    local categories = new_table(category, categories_count)

    local classifications = classification_result_lib.Classifications(mediapipe_lua.kwargs({
        categories = categories,
        head_index = _MOCK_HEAD_INDEX,
        head_name = _MOCK_HEAD_NAME,
    }))
    local classifications_array = new_table(classifications, classifications_count)

    return classification_result_lib.ClassificationResult(mediapipe_lua.kwargs({
        classifications = classifications_array,
        timestamp_ms = _MOCK_TIMESTAMP_MS,
    }))
end

function _assert._assert_category_matches(self, ...)
    local args = { n = select("#", ...), ... }
    local has_kwarg = mediapipe_lua.kwargs.isinstance(args[args.n])
    local kwargs = has_kwarg and args[args.n] or mediapipe_lua.kwargs()
    local usedkw = 0

    -- get argument actual
    local actual
    local has_actual = false
    if (not has_kwarg) or args.n > 1 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("actual") then
            error("actual was both specified as a Positional and NamedParameter")
        end
        has_actual = args.n >= 1
        if has_actual then
            actual = args[1]
        end
    elseif kwargs:has("actual") then
        -- named parameter
        has_actual = true
        actual = kwargs:get("actual")
        usedkw = usedkw + 1
    else
        error("actual is mandatory")
    end

    -- get argument expected
    local expected
    local has_expected = false
    if (not has_kwarg) or args.n > 2 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("expected") then
            error("expected was both specified as a Positional and NamedParameter")
        end
        has_expected = args.n >= 2
        if has_expected then
            expected = args[2]
        end
    elseif kwargs:has("expected") then
        -- named parameter
        has_expected = true
        expected = kwargs:get("expected")
        usedkw = usedkw + 1
    else
        error("expected is mandatory")
    end

    if usedkw ~= kwargs:size() then
        error("there are " .. (kwargs:size() - usedkw) .. " unknown named parameters")
    end

    --- ====================== ---
    --- CODE LOGIC STARTS HERE ---
    --- ====================== ---

    self.assertEqual(expected.index, actual.index)
    self.assertAlmostEqual(expected.score, actual.score)
    self.assertEqual(expected.category_name, actual.category_name)
    self.assertEqual(expected.display_name, actual.display_name)
end

function _assert._assert_classsification_matches(self, ...)
    local args = { n = select("#", ...), ... }
    local has_kwarg = mediapipe_lua.kwargs.isinstance(args[args.n])
    local kwargs = has_kwarg and args[args.n] or mediapipe_lua.kwargs()
    local usedkw = 0

    -- get argument actual_result
    local actual_result
    local has_actual_result = false
    if (not has_kwarg) or args.n > 1 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("actual_result") then
            error("actual_result was both specified as a Positional and NamedParameter")
        end
        has_actual_result = args.n >= 1
        if has_actual_result then
            actual_result = args[1]
        end
    elseif kwargs:has("actual_result") then
        -- named parameter
        has_actual_result = true
        actual_result = kwargs:get("actual_result")
        usedkw = usedkw + 1
    else
        error("actual_result is mandatory")
    end

    -- get argument expected_categories
    local expected_categories
    local has_expected_categories = false
    if (not has_kwarg) or args.n > 2 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("expected_categories") then
            error("expected_categories was both specified as a Positional and NamedParameter")
        end
        has_expected_categories = args.n >= 2
        if has_expected_categories then
            expected_categories = args[2]
        end
    elseif kwargs:has("expected_categories") then
        -- named parameter
        has_expected_categories = true
        expected_categories = kwargs:get("expected_categories")
        usedkw = usedkw + 1
    else
        error("expected_categories is mandatory")
    end

    if usedkw ~= kwargs:size() then
        error("there are " .. (kwargs:size() - usedkw) .. " unknown named parameters")
    end

    --- ====================== ---
    --- CODE LOGIC STARTS HERE ---
    --- ====================== ---

    self.assertEqual(actual_result.head_index, _MOCK_HEAD_INDEX)
    self.assertEqual(actual_result.head_name, _MOCK_HEAD_NAME)
    self.assertLen(actual_result.categories, #expected_categories)
    for i, expected_category in ipairs(expected_categories) do
        self:_assert_category_matches(
            actual_result.categories[i - INDEX_BASE], expected_category
        )
    end
end

local function test_converts_fully_populated_classification_result_to_lua(self)
    local actual_result = _create_classification_result(mediapipe_lua.kwargs({
        categories_count = 2, classifications_count = 1
    }))

    self.assertEqual(actual_result.timestamp_ms, _MOCK_TIMESTAMP_MS)
    self.assertLen(actual_result.classifications, 1)
    self:_assert_classsification_matches(mediapipe_lua.kwargs({
        actual_result = actual_result.classifications[0],
        expected_categories = { _MOCK_CATEGORY, _MOCK_CATEGORY },
    }))
end

local function test_converts_empty_classification_result_to_lua(self)
    local actual_result = _create_classification_result(mediapipe_lua.kwargs({
        categories_count = 0, classifications_count = 0
    }))

    self.assertEqual(actual_result.timestamp_ms, _MOCK_TIMESTAMP_MS)
    self.assertEmpty(actual_result.classifications)
end

describe("ClassificationResultTest", function()
    it("should test_converts_fully_populated_classification_result_to_lua", function()
        test_converts_fully_populated_classification_result_to_lua(_assert)
    end)
    it("should test_converts_empty_classification_result_to_lua", function()
        test_converts_empty_classification_result_to_lua(_assert)
    end)
end)
