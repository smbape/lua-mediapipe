#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/python/calculator_graph_test.py
--]]

local INDEX_BASE = 1 -- lua is 1-based indexed

local _assert = require("_assert")

local mediapipe_lua = require("mediapipe_lua")
local google = mediapipe_lua.google
local mediapipe = mediapipe_lua.mediapipe

local text_format = google.protobuf.text_format
local calculator_pb2 = mediapipe.framework.calculator_pb2
local packet_creator = mediapipe.lua.packet_creator
local packet_getter = mediapipe.lua.packet_getter
local calculator_graph = mediapipe.lua._framework_bindings.calculator_graph
local validated_graph_config = mediapipe.lua._framework_bindings.validated_graph_config

local CalculatorGraph = calculator_graph.CalculatorGraph
local ValidatedGraphConfig = validated_graph_config.ValidatedGraphConfig

local function test_graph_initialized_with_proto_config(self)
    local text_config = [[
        max_queue_size: 1
        input_stream: 'in'
        output_stream: 'out'
        node {
            calculator: 'PassThroughCalculator'
            input_stream: 'in'
            output_stream: 'out'
        }
    ]]
    local config_proto = calculator_pb2.CalculatorGraphConfig()
    text_format.Parse(text_config, config_proto)
    local graph = CalculatorGraph(mediapipe_lua.kwargs({ graph_config = config_proto }))

    local hello_world_packet = packet_creator.create_string('hello world')
    local out = {}
    local graph = CalculatorGraph(mediapipe_lua.kwargs({ graph_config = config_proto }))
    graph:observe_output_stream('out', function(_, packet) out[#out + 1] = packet end)
    graph:start_run()
    graph:add_packet_to_input_stream(mediapipe_lua.kwargs({
        stream = 'in', packet = hello_world_packet, timestamp = 0 }))
    graph:add_packet_to_input_stream(mediapipe_lua.kwargs({
        stream = 'in', packet = hello_world_packet:at(1) }))
    graph:close()
    mediapipe_lua.notifyCallbacks()
    self.assertEqual(
        graph.graph_input_stream_add_mode,
        calculator_graph.GraphInputStreamAddMode.WAIT_TILL_NOT_FULL)
    self.assertEqual(graph.max_queue_size, 1)
    self.assertFalse(graph:has_error())
    self.assertLen(out, 2)
    self.assertEqual(out[0 + INDEX_BASE].timestamp.value, 0)
    self.assertEqual(out[1 + INDEX_BASE].timestamp.value, 1)
    self.assertEqual(packet_getter.get_str(out[0 + INDEX_BASE]), 'hello world')
    self.assertEqual(packet_getter.get_str(out[1 + INDEX_BASE]), 'hello world')
end

local function test_graph_initialized_with_text_config(self)
    local text_config = [[
        max_queue_size: 1
        input_stream: 'in'
        output_stream: 'out'
        node {
            calculator: 'PassThroughCalculator'
            input_stream: 'in'
            output_stream: 'out'
        }
    ]]

    local hello_world_packet = packet_creator.create_string('hello world')
    local out = {}
    local graph = CalculatorGraph(mediapipe_lua.kwargs({ graph_config = text_config }))
    graph:observe_output_stream('out', function(_, packet) out[#out + 1] = packet end)
    graph:start_run()
    graph:add_packet_to_input_stream(mediapipe_lua.kwargs({
        stream = 'in', packet = hello_world_packet:at(0) }))
    graph:add_packet_to_input_stream(mediapipe_lua.kwargs({
        stream = 'in', packet = hello_world_packet, timestamp = 1 }))
    graph:close()
    mediapipe_lua.notifyCallbacks()
    self.assertEqual(
        graph.graph_input_stream_add_mode,
        calculator_graph.GraphInputStreamAddMode.WAIT_TILL_NOT_FULL)
    self.assertEqual(graph.max_queue_size, 1)
    self.assertFalse(graph:has_error())
    self.assertLen(out, 2)
    self.assertEqual(out[0 + INDEX_BASE].timestamp.value, 0)
    self.assertEqual(out[1 + INDEX_BASE].timestamp.value, 1)
    self.assertEqual(packet_getter.get_str(out[0 + INDEX_BASE]), 'hello world')
    self.assertEqual(packet_getter.get_str(out[1 + INDEX_BASE]), 'hello world')
end

local function test_graph_validation_and_initialization(self)
    local text_config = [[
        max_queue_size: 1
        input_stream: 'in'
        output_stream: 'out'
        node {
            calculator: 'PassThroughCalculator'
            input_stream: 'in'
            output_stream: 'out'
        }
    ]]

    local hello_world_packet = packet_creator.create_string('hello world')
    local out = {}
    local validated_graph = ValidatedGraphConfig()
    self.assertFalse(validated_graph:initialized())
    validated_graph:initialize(mediapipe_lua.kwargs({ graph_config = text_config }))
    self.assertTrue(validated_graph:initialized())

    local graph = CalculatorGraph(mediapipe_lua.kwargs({ validated_graph_config = validated_graph }))
    graph:observe_output_stream('out', function(_, packet) out[#out + 1] = packet end)
    graph:start_run()
    graph:add_packet_to_input_stream(mediapipe_lua.kwargs({
        stream = 'in', packet = hello_world_packet:at(0) }))
    graph:add_packet_to_input_stream(mediapipe_lua.kwargs({
        stream = 'in', packet = hello_world_packet, timestamp = 1 }))
    graph:close()
    mediapipe_lua.notifyCallbacks()
    self.assertEqual(
        graph.graph_input_stream_add_mode,
        calculator_graph.GraphInputStreamAddMode.WAIT_TILL_NOT_FULL)
    self.assertEqual(graph.max_queue_size, 1)
    self.assertFalse(graph:has_error())
    self.assertLen(out, 2)
    self.assertEqual(out[0 + INDEX_BASE].timestamp.value, 0)
    self.assertEqual(out[1 + INDEX_BASE].timestamp.value, 1)
    self.assertEqual(packet_getter.get_str(out[0 + INDEX_BASE]), 'hello world')
    self.assertEqual(packet_getter.get_str(out[1 + INDEX_BASE]), 'hello world')
end

local function test_side_packet_graph(self)
    local text_config = [[
        node {
            calculator: 'StringToUint64Calculator'
            input_side_packet: "string"
            output_side_packet: "number"
        }
    ]]
    local config_proto = calculator_pb2.CalculatorGraphConfig()
    text_format.Parse(text_config, config_proto)
    local graph = CalculatorGraph(mediapipe_lua.kwargs({ graph_config = config_proto }))
    graph:start_run(mediapipe_lua.kwargs({
        input_side_packets = { ['string'] = packet_creator.create_string('42') }
    }))
    graph:wait_until_done()
    mediapipe_lua.notifyCallbacks()
    self.assertFalse(graph:has_error())
    self.assertEqual(
        packet_getter.get_uint(graph:get_output_side_packet('number')), 42)
end

local function test_sequence_input(self)
    local text_config = [[
        max_queue_size: 1
        input_stream: 'in'
        output_stream: 'out'
        node {
            calculator: 'PassThroughCalculator'
            input_stream: 'in'
            output_stream: 'out'
        }
    ]]
    local hello_world_packet = packet_creator.create_string('hello world')
    local out = {}
    local graph = CalculatorGraph(mediapipe_lua.kwargs({ graph_config = text_config }))
    graph:observe_output_stream('out', function(_, packet) out[#out + 1] = packet end)
    graph:start_run()

    local sequence_size = 1000
    for i = 0, sequence_size - 1 do
        graph:add_packet_to_input_stream(mediapipe_lua.kwargs({
            stream = 'in', packet = hello_world_packet, timestamp = i }))
        mediapipe_lua.notifyCallbacks()
    end
    graph:wait_until_idle()
    mediapipe_lua.notifyCallbacks()
    self.assertLen(out, sequence_size)
    for i = 0, sequence_size - 1 do
        self.assertEqual(out[i + INDEX_BASE].timestamp.value, i)
        self.assertEqual(packet_getter.get_str(out[i + INDEX_BASE]), 'hello world')
    end
end

describe("GraphTest", function()
    it("should test_graph_initialized_with_proto_config", function()
        test_graph_initialized_with_proto_config(_assert)
    end)
    it("should test_graph_initialized_with_text_config", function()
        test_graph_initialized_with_text_config(_assert)
    end)
    it("should test_graph_validation_and_initialization", function()
        test_graph_validation_and_initialization(_assert)
    end)
    it("should test_side_packet_graph", function()
        test_side_packet_graph(_assert)
    end)
    it("should test_sequence_input", function()
        test_sequence_input(_assert)
    end)
end)
