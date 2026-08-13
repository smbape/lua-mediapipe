#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.35/mediapipe/tasks/python/test/components/containers/embedding_result_test.py
--]]

local _assert = require("_assert")

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe
local embedding_result_lib = mediapipe.tasks.lua.components.containers.embedding_result

local _Embedding = embedding_result_lib.Embedding
local _EmbeddingResult = embedding_result_lib.EmbeddingResult

local function _create_c_embedding_result(...)
    local args = { n = select("#", ...), ... }
    local has_kwarg = mediapipe_lua.kwargs.isinstance(args[args.n])
    local kwargs = has_kwarg and args[args.n] or mediapipe_lua.kwargs()
    local usedkw = 0

    -- get argument values
    local values
    local has_values = false
    if (not has_kwarg) or args.n > 1 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("values") then
            error("values was both specified as a Positional and NamedParameter")
        end
        has_values = args.n >= 1
        if has_values then
            values = args[1]
        end
    elseif kwargs:has("values") then
        -- named parameter
        has_values = true
        values = kwargs:get("values")
        usedkw = usedkw + 1
    else
        error("values is mandatory")
    end

    -- get argument is_quantized
    local is_quantized
    local has_is_quantized = false
    if (not has_kwarg) or args.n > 2 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("is_quantized") then
            error("is_quantized was both specified as a Positional and NamedParameter")
        end
        has_is_quantized = args.n >= 2
        if has_is_quantized then
            is_quantized = args[2]
        end
    elseif kwargs:has("is_quantized") then
        -- named parameter
        has_is_quantized = true
        is_quantized = kwargs:get("is_quantized")
        usedkw = usedkw + 1
    else
        error("is_quantized is mandatory")
    end

    -- get argument timestamp_ms
    local timestamp_ms
    local has_timestamp_ms = false
    if (not has_kwarg) or args.n > 3 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("timestamp_ms") then
            error("timestamp_ms was both specified as a Positional and NamedParameter")
        end
        has_timestamp_ms = args.n >= 3
        if has_timestamp_ms then
            timestamp_ms = args[3]
        end
    elseif kwargs:has("timestamp_ms") then
        -- named parameter
        has_timestamp_ms = true
        timestamp_ms = kwargs:get("timestamp_ms")
        usedkw = usedkw + 1
    end

    if usedkw ~= kwargs:size() then
        error("there are " .. (kwargs:size() - usedkw) .. " unknown named parameters")
    end

    --- ====================== ---
    --- CODE LOGIC STARTS HERE ---
    --- ====================== ---

    --[[ Creates a mock C EmbeddingResultC struct. ]] --
    local embedding = _Embedding(mediapipe_lua.kwargs({
        head_index = 0,
        head_name = "feature",
    }))
    if is_quantized then
        embedding.quantized_embedding = values
    else
        embedding.float_embedding = values
    end

    local embeddings = { embedding }
    return _EmbeddingResult(mediapipe_lua.kwargs({
        embeddings = embeddings,
        timestamp_ms = timestamp_ms,
    }))
end


function _assert._assert_embedding_result(self, ...)
    local args = { n = select("#", ...), ... }
    local has_kwarg = mediapipe_lua.kwargs.isinstance(args[args.n])
    local kwargs = has_kwarg and args[args.n] or mediapipe_lua.kwargs()
    local usedkw = 0

    -- get argument lua_result
    local lua_result
    local has_lua_result = false
    if (not has_kwarg) or args.n > 1 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("lua_result") then
            error("lua_result was both specified as a Positional and NamedParameter")
        end
        has_lua_result = args.n >= 1
        if has_lua_result then
            lua_result = args[1]
        end
    elseif kwargs:has("lua_result") then
        -- named parameter
        has_lua_result = true
        lua_result = kwargs:get("lua_result")
        usedkw = usedkw + 1
    else
        error("lua_result is mandatory")
    end

    -- get argument expected_values
    local expected_values
    local has_expected_values = false
    if (not has_kwarg) or args.n > 2 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("expected_values") then
            error("expected_values was both specified as a Positional and NamedParameter")
        end
        has_expected_values = args.n >= 2
        if has_expected_values then
            expected_values = args[2]
        end
    elseif kwargs:has("expected_values") then
        -- named parameter
        has_expected_values = true
        expected_values = kwargs:get("expected_values")
        usedkw = usedkw + 1
    else
        error("expected_values is mandatory")
    end

    -- get argument is_quantized
    local is_quantized
    local has_is_quantized = false
    if (not has_kwarg) or args.n > 3 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("is_quantized") then
            error("is_quantized was both specified as a Positional and NamedParameter")
        end
        has_is_quantized = args.n >= 3
        if has_is_quantized then
            is_quantized = args[3]
        end
    elseif kwargs:has("is_quantized") then
        -- named parameter
        has_is_quantized = true
        is_quantized = kwargs:get("is_quantized")
        usedkw = usedkw + 1
    else
        error("is_quantized is mandatory")
    end

    -- get argument expected_timestamp
    local expected_timestamp
    local has_expected_timestamp = false
    if (not has_kwarg) or args.n > 4 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("expected_timestamp") then
            error("expected_timestamp was both specified as a Positional and NamedParameter")
        end
        has_expected_timestamp = args.n >= 4
        if has_expected_timestamp then
            expected_timestamp = args[4]
        end
    elseif kwargs:has("expected_timestamp") then
        -- named parameter
        has_expected_timestamp = true
        expected_timestamp = kwargs:get("expected_timestamp")
        usedkw = usedkw + 1
    end

    if usedkw ~= kwargs:size() then
        error("there are " .. (kwargs:size() - usedkw) .. " unknown named parameters")
    end

    --- ====================== ---
    --- CODE LOGIC STARTS HERE ---
    --- ====================== ---

    --[[ Asserts that the Python EmbeddingResult matches the expected values. ]] --
    self.assertLen(lua_result.embeddings, 1)
    local embedding = lua_result.embeddings[0]
    if is_quantized then
        self.assertListEqual(embedding.embedding:table(), expected_values)
    else
        self.assertListAlmostEqual(embedding.embedding:table(), expected_values)
    end
    self.assertEqual(embedding.head_index, 0)
    self.assertEqual(embedding.head_name, "feature")
    self.assertEqual(lua_result.timestamp_ms, expected_timestamp)
end

local function test_from_ctypes_float_embedding(self)
    local float_values = { 0.1, 0.2, 0.3 }
    local converted_result = _create_c_embedding_result(
        float_values, mediapipe_lua.kwargs({ is_quantized = false })
    )
    self:_assert_embedding_result(
        converted_result, float_values, mediapipe_lua.kwargs({ is_quantized = false })
    )
end

local function test_from_ctypes_quantized_embedding(self)
    local quantized_values = { 100, 200, 255 }
    local converted_result = _create_c_embedding_result(
        quantized_values, mediapipe_lua.kwargs({ is_quantized = true })
    )
    self:_assert_embedding_result(
        converted_result, quantized_values, mediapipe_lua.kwargs({ is_quantized = true })
    )
end

local function test_from_ctypes_quantized_embedding_contains_a_zero_value(self)
    --[[ Tests conversion logic for strings with zero values. ]] --
    local quantized_values = { 0, 100, 200 }
    local converted_result = _create_c_embedding_result(
        quantized_values, mediapipe_lua.kwargs({ is_quantized = true })
    )
    self:_assert_embedding_result(
        converted_result, quantized_values, mediapipe_lua.kwargs({ is_quantized = true })
    )
end

local function test_from_ctypes_with_timestamp(self)
    local float_values = { 0.1, 0.2 }
    local converted_result = _create_c_embedding_result(
        float_values, mediapipe_lua.kwargs({ is_quantized = false, timestamp_ms = 12345 })
    )
    self:_assert_embedding_result(
        converted_result,
        float_values,
        mediapipe_lua.kwargs({
            is_quantized = false,
            expected_timestamp = 12345,
        })
    )
end

describe("EmbeddingResultTest", function()
    it("should test_from_ctypes_float_embedding", function()
        test_from_ctypes_float_embedding(_assert)
    end)
    it("should test_from_ctypes_quantized_embedding", function()
        test_from_ctypes_quantized_embedding(_assert)
    end)
    it("should test_from_ctypes_quantized_embedding_contains_a_zero_value", function()
        test_from_ctypes_quantized_embedding_contains_a_zero_value(_assert)
    end)
    it("should test_from_ctypes_with_timestamp", function()
        test_from_ctypes_with_timestamp(_assert)
    end)
end)
