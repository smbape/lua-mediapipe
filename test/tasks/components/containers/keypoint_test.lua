#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.35/mediapipe/tasks/python/test/components/containers/keypoint_test.py
--]]

local _assert = require("_assert")

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe
local keypoint_lib = mediapipe.tasks.lua.components.containers.keypoint

local function test_create_from_ctypes_succeeds(self, ...)
    local args = { n = select("#", ...), ... }
    local has_kwarg = mediapipe_lua.kwargs.isinstance(args[args.n])
    local kwargs = has_kwarg and args[args.n] or mediapipe_lua.kwargs()
    local usedkw = 0

    -- get argument x
    local x
    local has_x = false
    if (not has_kwarg) or args.n > 1 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("x") then
            error("x was both specified as a Positional and NamedParameter")
        end
        has_x = args.n >= 1
        if has_x then
            x = args[1]
        end
    elseif kwargs:has("x") then
        -- named parameter
        has_x = true
        x = kwargs:get("x")
        usedkw = usedkw + 1
    else
        error("x is mandatory")
    end

    -- get argument y
    local y
    local has_y = false
    if (not has_kwarg) or args.n > 2 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("y") then
            error("y was both specified as a Positional and NamedParameter")
        end
        has_y = args.n >= 2
        if has_y then
            y = args[2]
        end
    elseif kwargs:has("y") then
        -- named parameter
        has_y = true
        y = kwargs:get("y")
        usedkw = usedkw + 1
    else
        error("y is mandatory")
    end

    -- get argument label
    local label
    local has_label = false
    if (not has_kwarg) or args.n > 3 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("label") then
            error("label was both specified as a Positional and NamedParameter")
        end
        has_label = args.n >= 3
        if has_label then
            label = args[3]
        end
    elseif kwargs:has("label") then
        -- named parameter
        has_label = true
        label = kwargs:get("label")
        usedkw = usedkw + 1
    end

    -- get argument score
    local score
    local has_score = false
    if (not has_kwarg) or args.n > 4 then
        -- positional parameter should not be a named parameter
        if has_kwarg and kwargs:has("score") then
            error("score was both specified as a Positional and NamedParameter")
        end
        has_score = args.n >= 4
        if has_score then
            score = args[4]
        end
    elseif kwargs:has("score") then
        -- named parameter
        has_score = true
        score = kwargs:get("score")
        usedkw = usedkw + 1
    else
        error("y is mandatory")
    end

    if usedkw ~= kwargs:size() then
        error("there are " .. (kwargs:size() - usedkw) .. " unknown named parameters")
    end

    --- ====================== ---
    --- CODE LOGIC STARTS HERE ---
    --- ====================== ---

    local actual_keypoint = keypoint_lib.NormalizedKeypoint(mediapipe_lua.kwargs({
        x = x, y = y, label = label, score = score
    }))

    local expected_keypoint_values = {
        x = x,
        y = y,
        label = label,
        score = score,
    }
    self.assertDictAlmostEqual(actual_keypoint, expected_keypoint_values)
end


describe("NormalizedKeypointTest", function()
    for _, args in ipairs({
        mediapipe_lua.kwargs({
            testcase_name = 'with_optional_fields',
            x = 0.1,
            y = 0.2,
            label = 'test_label',
            score = 0.9,
        }),
        mediapipe_lua.kwargs({
            testcase_name = 'without_optional_fields',
            x = 0.1,
            y = 0.2,
            label = nil,
            score = 0.0,
        }),
    }) do
        it("should test_create_from_ctypes_succeeds " .. args.testcase_name, function()
            args.testcase_name = nil
            test_create_from_ctypes_succeeds(_assert, args)
        end)
    end
end)
