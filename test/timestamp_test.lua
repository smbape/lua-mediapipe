#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/python/timestamp_test.py
--]]

local _assert = require("_assert")

local mediapipe_lua = require("mediapipe_lua")
local mediapipe = mediapipe_lua.mediapipe

local timestamp = mediapipe.lua._framework_bindings.timestamp

local Timestamp = timestamp.Timestamp

local function test_timestamp(self)
    local t = Timestamp(100)
    self.assertEqual(t.value, 100)
    self.assertEqual(tostring(t), '<mediapipe.Timestamp with value: 100>')
end

local function test_timestamp_copy_constructor(self)
    local ts1 = Timestamp(100)
    local ts2 = Timestamp(ts1)
    self.assertEqual(ts1, ts2)
end

local function test_timestamp_comparsion(self)
    local ts1 = Timestamp(100)
    local ts2 = Timestamp(100)
    self.assertEqual(ts1, ts2)
    local ts3 = Timestamp(200)
    self.assertNotEqual(ts1, ts3)
end

local function test_timestamp_special_values(self)
    local t1 = Timestamp.UNSET
    self.assertEqual(tostring(t1), '<mediapipe.Timestamp with value: UNSET>')
    local t2 = Timestamp.UNSTARTED
    self.assertEqual(tostring(t2), '<mediapipe.Timestamp with value: UNSTARTED>')
    local t3 = Timestamp.PRESTREAM
    self.assertEqual(tostring(t3), '<mediapipe.Timestamp with value: PRESTREAM>')
    local t4 = Timestamp.MIN
    self.assertEqual(tostring(t4), '<mediapipe.Timestamp with value: MIN>')
    local t5 = Timestamp.MAX
    self.assertEqual(tostring(t5), '<mediapipe.Timestamp with value: MAX>')
    local t6 = Timestamp.POSTSTREAM
    self.assertEqual(tostring(t6), '<mediapipe.Timestamp with value: POSTSTREAM>')
    local t7 = Timestamp.DONE
    self.assertEqual(tostring(t7), '<mediapipe.Timestamp with value: DONE>')
end

local function test_timestamp_comparisons(self)
    local ts1 = Timestamp(100)
    local ts2 = Timestamp(101)
    self.assertGreater(ts2, ts1)
    self.assertGreaterEqual(ts2, ts1)
    self.assertLess(ts1, ts2)
    self.assertLessEqual(ts1, ts2)
    self.assertNotEqual(ts1, ts2)
end

local function test_from_seconds(self)
    local now = os.time()
    local ts = Timestamp.from_seconds(now)
    self.assertAlmostEqual(now, ts:seconds(), mediapipe_lua.kwargs({delta=1}))
end

describe("TimestampTest", function()
    it("should test_timestamp", function()
        test_timestamp(_assert)
    end)
    it("should test_timestamp_copy_constructor", function()
        test_timestamp_copy_constructor(_assert)
    end)
    it("should test_timestamp_comparsion", function()
        test_timestamp_comparsion(_assert)
    end)
    it("should test_timestamp_special_values", function()
        test_timestamp_special_values(_assert)
    end)
    it("should test_timestamp_comparisons", function()
        test_timestamp_comparisons(_assert)
    end)
    it("should test_from_seconds", function()
        test_from_seconds(_assert)
    end)
end)
