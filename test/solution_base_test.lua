#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/python/solution_base_test.py
--]]

local unpack = table.unpack or unpack ---@diagnostic disable-line: deprecated

local _assert = require("_assert")
local _mat_utils = require("_mat_utils")

local mediapipe_lua = require("mediapipe_lua")
local google = mediapipe_lua.google
local mediapipe = mediapipe_lua.mediapipe

local opencv_lua = require("opencv_lua")
local cv2 = opencv_lua.cv

local text_format = google.protobuf.text_format
local calculator_pb2 = mediapipe.framework.calculator_pb2
local detection_pb2 = mediapipe.framework.formats.detection_pb2
local solution_base = mediapipe.lua.solution_base
local PacketDataType = mediapipe.lua.solution_base.PacketDataType

local CALCULATOR_OPTIONS_TEST_GRAPH_CONFIG = [[
    input_stream: 'image_in'
    output_stream: 'image_out'
    node {
        name: 'ImageTransformation'
        calculator: 'ImageTransformationCalculator'
        input_stream: 'IMAGE:image_in'
        output_stream: 'IMAGE:image_out'
        options: {
            [mediapipe.ImageTransformationCalculatorOptions.ext] {
                 output_width: 10
                 output_height: 10
            }
        }
        node_options: {
            [type.googleapis.com/mediapipe.ImageTransformationCalculatorOptions] {
                 output_width: 10
                 output_height: 10
            }
        }
    }
]]

local function test_valid_input_data_type_proto(self)
    local text_config = [[
        input_stream: 'input_detections'
        output_stream: 'output_detections'
        node {
            calculator: 'DetectionUniqueIdCalculator'
            input_stream: 'DETECTION_LIST:input_detections'
            output_stream: 'DETECTION_LIST:output_detections'
        }
    ]]
    local config_proto = text_format.Parse(text_config,
                                                                     calculator_pb2.CalculatorGraphConfig())
    local solution = solution_base.SolutionBase(mediapipe_lua.kwargs({graph_config=config_proto}))
    local input_detections = detection_pb2.DetectionList()
    local detection_1 = input_detections.detection:add()
    text_format.Parse('score: 0.5', detection_1)
    local detection_2 = input_detections.detection:add()
    text_format.Parse('score: 0.8', detection_2)
    local results = solution:process({['input_detections'] = input_detections})
    local inspect = require("inspect")
    self.assertNotEqual(results.output_detections, nil)
    self.assertLen(results.output_detections.detection, 2)
    local expected_detection_1 = detection_pb2.Detection()
    text_format.Parse('score: 0.5, detection_id: 1', expected_detection_1)
    local expected_detection_2 = detection_pb2.Detection()
    text_format.Parse('score: 0.8, detection_id: 2', expected_detection_2)
    self.assertEqual(results.output_detections.detection[0],
                                     expected_detection_1)
    self.assertEqual(results.output_detections.detection[1],
                                     expected_detection_2)
end

local function test_solution_process(self, id, text_config, side_inputs)
    self:_process_and_verify(mediapipe_lua.kwargs({
                    config_proto=text_format.Parse(text_config,
                                                                                 calculator_pb2.CalculatorGraphConfig()),
                    side_inputs=side_inputs}))
end

local function test_modifying_calculator_proto2_options(self)
    local config_proto = text_format.Parse(CALCULATOR_OPTIONS_TEST_GRAPH_CONFIG,
                                                                     calculator_pb2.CalculatorGraphConfig())
    -- To test proto2 options only, remove the proto3 node_options field from the
    -- graph config.
    self.assertEqual('ImageTransformation', config_proto.node[0].name)
    config_proto.node[0]:ClearField('node_options')
    self:_process_and_verify(mediapipe_lua.kwargs({
                    config_proto=config_proto,
                    calculator_params={
                            ['ImageTransformation.output_width'] = 0,
                            ['ImageTransformation.output_height'] = 0
                    }}))
end

local function test_modifying_calculator_proto3_node_options(self)
    local config_proto = text_format.Parse(CALCULATOR_OPTIONS_TEST_GRAPH_CONFIG,
                                                                     calculator_pb2.CalculatorGraphConfig())
    -- To test proto3 node options only, remove the proto2 options field from the
    -- graph config.
    self.assertEqual('ImageTransformation', config_proto.node[0].name)
    config_proto.node[0]:ClearField('options')
    self:_process_and_verify(mediapipe_lua.kwargs({
                    config_proto=config_proto,
                    calculator_params={
                            ['ImageTransformation.output_width'] = 0,
                            ['ImageTransformation.output_height'] = 0
                    }}))
end

local function test_adding_calculator_options(self)
    local config_proto = text_format.Parse(CALCULATOR_OPTIONS_TEST_GRAPH_CONFIG,
                                                                     calculator_pb2.CalculatorGraphConfig())
    -- To test a calculator with no options field, remove both proto2 options and
    -- proto3 node_options fields from the graph config.
    self.assertEqual('ImageTransformation', config_proto.node[0].name)
    config_proto.node[0]:ClearField('options')
    config_proto.node[0]:ClearField('node_options')
    self:_process_and_verify(mediapipe_lua.kwargs({
                    config_proto=config_proto,
                    calculator_params={
                            ['ImageTransformation.output_width'] = 0,
                            ['ImageTransformation.output_height'] = 0
                    }}))
end

local function test_solution_reset(self, id, text_config, side_inputs)
    local config_proto = text_format.Parse(text_config,
                                                                     calculator_pb2.CalculatorGraphConfig())
    local input_image = _mat_utils.randomImage(3, 3, cv2.CV_8UC3, 0, 27)
    local solution = solution_base.SolutionBase(mediapipe_lua.kwargs({
                    graph_config=config_proto, side_inputs=side_inputs}))
    for i = 1, 20 do
        local outputs = solution:process(input_image)
        self.assertMatEqual(input_image, outputs.image_out)
        solution:reset()
    end
end

local function test_solution_stream_type_hints(self)
    local text_config = [[
        input_stream: 'union_type_image_in'
        output_stream: 'image_type_out'
        node {
            calculator: 'ToImageCalculator'
            input_stream: 'IMAGE:union_type_image_in'
            output_stream: 'IMAGE:image_type_out'
        }
    ]]
    local config_proto = text_format.Parse(text_config,
                                                                     calculator_pb2.CalculatorGraphConfig())
    local input_image = _mat_utils.randomImage(3, 3, cv2.CV_8UC3, 0, 27)
    local solution = solution_base.SolutionBase(mediapipe_lua.kwargs({
                    graph_config=config_proto,
                    stream_type_hints={['union_type_image_in'] = PacketDataType.IMAGE
                                                        }}))
    for i = 1, 20 do
        local outputs = solution:process(input_image)
        self.assertMatEqual(input_image, outputs.image_type_out)
    end

    local solution2 = solution_base.SolutionBase(mediapipe_lua.kwargs({
                    graph_config=config_proto,
                    stream_type_hints={['union_type_image_in'] = PacketDataType.IMAGE_FRAME
                                                        }}))
    for i = 1, 20 do
        local outputs = solution2:process(input_image)
        self.assertMatEqual(input_image, outputs.image_type_out)
    end
end

function _assert._process_and_verify (self, ... )
        local args={n=select("#", ...), ...}
        local has_kwarg = mediapipe_lua.kwargs.isinstance(args[args.n])
        local kwargs = has_kwarg and args[args.n] or mediapipe_lua.kwargs()
        local usedkw = 0

        -- get argument config_proto
        local config_proto
        local has_config_proto = false
        if (not has_kwarg) or args.n > 1 then
                -- positional parameter should not be a named parameter
                if has_kwarg and kwargs:has("config_proto") then
                        error("config_proto was both specified as a Positional and NamedParameter")
                end
                has_config_proto = args.n >= 1
                if has_config_proto then
                        config_proto = args[1]
                end
        elseif kwargs:has("config_proto") then
                -- named parameter
                has_config_proto = true
                config_proto = kwargs:get("config_proto")
                usedkw = usedkw + 1
        else
                error("config_proto is mandatory")
        end

        -- get argument side_inputs
        local side_inputs = nil
        local has_side_inputs = false
        if (not has_kwarg) or args.n > 2 then
                -- positional parameter should not be a named parameter
                if has_kwarg and kwargs:has("side_inputs") then
                        error("side_inputs was both specified as a Positional and NamedParameter")
                end
                has_side_inputs = args.n >= 2
                if has_side_inputs then
                        side_inputs = args[2]
                end
        elseif kwargs:has("side_inputs") then
                -- named parameter
                has_side_inputs = true
                side_inputs = kwargs:get("side_inputs")
                usedkw = usedkw + 1
        end

        -- get argument calculator_params
        local calculator_params = nil
        local has_calculator_params = false
        if (not has_kwarg) or args.n > 3 then
                -- positional parameter should not be a named parameter
                if has_kwarg and kwargs:has("calculator_params") then
                        error("calculator_params was both specified as a Positional and NamedParameter")
                end
                has_calculator_params = args.n >= 3
                if has_calculator_params then
                        calculator_params = args[3]
                end
        elseif kwargs:has("calculator_params") then
                -- named parameter
                has_calculator_params = true
                calculator_params = kwargs:get("calculator_params")
                usedkw = usedkw + 1
        end

        if usedkw ~= kwargs:size() then
                error("there are " .. (kwargs:size() - usedkw) .. " unknown named parameters")
        end

        --- ====================== ---
        --- CODE LOGIC STARTS HERE ---
        --- ====================== ---

        local input_image = _mat_utils.randomImage(3, 3, cv2.CV_8UC3, 0, 27)
        local solution = solution_base.SolutionBase(mediapipe_lua.kwargs({
                                graph_config=config_proto,
                                side_inputs=side_inputs,
                                calculator_params=calculator_params}))
        local outputs = solution:process(input_image)
        local outputs2 = solution:process({['image_in'] = input_image})
        self.assertMatEqual(input_image, outputs.image_out)
        self.assertMatEqual(input_image, outputs2.image_out)
end

describe("SolutionBaseTest", function()
    it("should test_valid_input_data_type_proto", function()
        test_valid_input_data_type_proto(_assert)
    end)

    for _, args in ipairs({
        { 'graph_without_side_packets', [[
            input_stream: 'image_in'
            output_stream: 'image_out'
            node {
                calculator: 'ImageTransformationCalculator'
                input_stream: 'IMAGE:image_in'
                output_stream: 'IMAGE:transformed_image_in'
            }
            node {
                calculator: 'ImageTransformationCalculator'
                input_stream: 'IMAGE:transformed_image_in'
                output_stream: 'IMAGE:image_out'
            }
        ]] },
        { 'graph_with_side_packets', [[
            input_stream: 'image_in'
            input_side_packet: 'allow_signal'
            input_side_packet: 'rotation_degrees'
            output_stream: 'image_out'
            node {
                calculator: 'ImageTransformationCalculator'
                input_stream: 'IMAGE:image_in'
                input_side_packet: 'ROTATION_DEGREES:rotation_degrees'
                output_stream: 'IMAGE:transformed_image_in'
            }
            node {
                calculator: 'GateCalculator'
                input_stream: 'transformed_image_in'
                input_side_packet: 'ALLOW:allow_signal'
                output_stream: 'image_out_to_transform'
            }
            node {
                calculator: 'ImageTransformationCalculator'
                input_stream: 'IMAGE:image_out_to_transform'
                input_side_packet: 'ROTATION_DEGREES:rotation_degrees'
                output_stream: 'IMAGE:image_out'
            }
        ]], {
            ['allow_signal'] = true,
            ['rotation_degrees'] = 0
        } },
    }) do
        it("should test_solution_process " .. args[1], function()
            test_solution_process(_assert, unpack(args))
        end)
    end

    it("should test_modifying_calculator_proto2_options", function()
        test_modifying_calculator_proto2_options(_assert)
    end)
    it("should test_modifying_calculator_proto3_node_options", function()
        test_modifying_calculator_proto3_node_options(_assert)
    end)
    it("should test_adding_calculator_options", function()
        test_adding_calculator_options(_assert)
    end)

    for _, args in ipairs({
        { 'graph_without_side_packets', [[
            input_stream: 'image_in'
            output_stream: 'image_out'
            node {
                calculator: 'ImageTransformationCalculator'
                input_stream: 'IMAGE:image_in'
                output_stream: 'IMAGE:transformed_image_in'
            }
            node {
                calculator: 'ImageTransformationCalculator'
                input_stream: 'IMAGE:transformed_image_in'
                output_stream: 'IMAGE:image_out'
            }
        ]] },
        { 'graph_with_side_packets', [[
            input_stream: 'image_in'
            input_side_packet: 'allow_signal'
            input_side_packet: 'rotation_degrees'
            output_stream: 'image_out'
            node {
                calculator: 'ImageTransformationCalculator'
                input_stream: 'IMAGE:image_in'
                input_side_packet: 'ROTATION_DEGREES:rotation_degrees'
                output_stream: 'IMAGE:transformed_image_in'
            }
            node {
                calculator: 'GateCalculator'
                input_stream: 'transformed_image_in'
                input_side_packet: 'ALLOW:allow_signal'
                output_stream: 'image_out_to_transform'
            }
            node {
                calculator: 'ImageTransformationCalculator'
                input_stream: 'IMAGE:image_out_to_transform'
                input_side_packet: 'ROTATION_DEGREES:rotation_degrees'
                output_stream: 'IMAGE:image_out'
            }
        ]], {
            ['allow_signal'] = true,
            ['rotation_degrees'] = 0
        } },
    }) do
        it("should test_solution_reset " .. args[1], function()
            test_solution_reset(_assert, unpack(args))
        end)
    end

    it("should test_solution_stream_type_hints", function()
        test_solution_stream_type_hints(_assert)
    end)
end)
