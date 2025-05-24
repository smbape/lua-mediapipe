#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/google-ai-edge/mediapipe/blob/v0.10.14/mediapipe/python/packet_test.py
--]]

local INDEX_BASE = 1 -- lua is 1-based indexed
local int = math.floor

local _assert = require("_assert")
local _mat_utils = require("_mat_utils")

local mediapipe_lua = require("mediapipe_lua")
local google = mediapipe_lua.google
local mediapipe = mediapipe_lua.mediapipe

local opencv_lua = require("opencv_lua")
local cv2 = opencv_lua.cv

local text_format = google.protobuf.text_format
local detection_pb2 = mediapipe.framework.formats.detection_pb2
local packet_creator = mediapipe.lua.packet_creator
local packet_getter = mediapipe.lua.packet_getter
local calculator_graph = mediapipe.lua._framework_bindings.calculator_graph
local image = mediapipe.lua._framework_bindings.image
local image_frame = mediapipe.lua._framework_bindings.image_frame
local packet = mediapipe.lua._framework_bindings.packet

local CalculatorGraph = calculator_graph.CalculatorGraph
local Image = image.Image
local ImageFormat = image_frame.ImageFormat
local ImageFrame = image_frame.ImageFrame

local function test_empty_packet(self)
    local p = packet.Packet()
    self.assertTrue(p:is_empty())
end

local function test_boolean_packet(self)
    local p = packet_creator.create_bool(true)
    p.timestamp = 0
    self.assertEqual(packet_getter.get_bool(p), true)
    self.assertEqual(p.timestamp.value, 0)
end

local function test_int_packet(self)
    local p = packet_creator.create_int(42)
    p.timestamp = 0
    self.assertEqual(packet_getter.get_int(p), 42)
    self.assertEqual(p.timestamp.value, 0)
end

local function test_int8_packet(self)
    local p = packet_creator.create_int8(int(2 ^ 7 - 1))
    p.timestamp = 0
    self.assertEqual(packet_getter.get_int(p), 2 ^ 7 - 1)
    self.assertEqual(p.timestamp.value, 0)
end

local function test_int16_packet(self)
    local p = packet_creator.create_int16(int(2 ^ 15 - 1))
    p.timestamp = 0
    self.assertEqual(packet_getter.get_int(p), 2 ^ 15 - 1)
    self.assertEqual(p.timestamp.value, 0)
end

local function test_int32_packet(self)
    local p = packet_creator.create_int32(int(2 ^ 31 - 1))
    p.timestamp = 0
    self.assertEqual(packet_getter.get_int(p), 2 ^ 31 - 1)
    self.assertEqual(p.timestamp.value, 0)
end

local function test_int64_packet(self)
    -- 0x7FFFFFFFFFFFFFFF == 2 ^ 63 - 1 is too big to be represented as an number in lua
    -- it is converted to double, therefore, loosing precision
    -- 2 ^ 62 - 1 seems to be fine
    local p = packet_creator.create_int64(int(2 ^ 62 - 1))
    p.timestamp = 0
    self.assertEqual(packet_getter.get_int(p), 2 ^ 62 - 1)
    self.assertEqual(p.timestamp.value, 0)
end

local function test_uint8_packet(self)
    local p = packet_creator.create_uint8(int(2 ^ 8 - 1))
    p.timestamp = 0
    self.assertEqual(packet_getter.get_uint(p), 2 ^ 8 - 1)
    self.assertEqual(p.timestamp.value, 0)
end

local function test_uint16_packet(self)
    local p = packet_creator.create_uint16(int(2 ^ 16 - 1))
    p.timestamp = 0
    self.assertEqual(packet_getter.get_uint(p), 2 ^ 16 - 1)
    self.assertEqual(p.timestamp.value, 0)
end

local function test_uint32_packet(self)
    local p = packet_creator.create_uint32(int(2 ^ 32 - 1))
    p.timestamp = 0
    self.assertEqual(packet_getter.get_uint(p), 2 ^ 32 - 1)
    self.assertEqual(p.timestamp.value, 0)
end

local function test_uint64_packet(self)
    -- 0x7FFFFFFFFFFFFFFF == 2 ^ 64 - 1 is too big to be represented as an number in lua
    -- it is converted to double, therefore, loosing precision
    -- 2 ^ 62 - 1 seems to be fine
    local p = packet_creator.create_uint64(int(2 ^ 62 - 1))
    p.timestamp = 0
    self.assertEqual(packet_getter.get_uint(p), 2 ^ 62 - 1)
    self.assertEqual(p.timestamp.value, 0)
end

local function test_float_packet(self)
    local p = packet_creator.create_float(0.42)
    p.timestamp = 0
    self.assertAlmostEqual(packet_getter.get_float(p), 0.42)
    self.assertEqual(p.timestamp.value, 0)
end

local function test_double_packet(self)
    local p = packet_creator.create_double(0.42)
    p.timestamp = 0
    self.assertAlmostEqual(packet_getter.get_float(p), 0.42)
    self.assertEqual(p.timestamp.value, 0)
end

local function test_detection_proto_packet(self)
    local detection = detection_pb2.Detection()

    text_format.Parse("score: 0.5", detection)
    text_format.Parse("score: 0.6", detection)

    local proto_packet = packet_creator.create_proto(detection)

    local output_proto = packet_getter.get_proto(proto_packet)

    local p = packet_creator.create_proto(detection):at(100)
    self.assertEqual(p.timestamp.value, 100)

    local cmessage = google.protobuf.lua.cmessage

    local scores = cmessage.GetFieldValue(detection, "score")
    self.assertLen(scores, 2)

    -- index access
    self.assertAlmostEqual(scores[0], 0.5)
    self.assertAlmostEqual(scores[1], 0.6)

    local scores = detection.score
    self.assertLen(scores, 2)

    -- index access
    self.assertAlmostEqual(scores[0], 0.5)
    self.assertAlmostEqual(scores[1], 0.6)
end

local function test_string_packet(self)
    local p = packet_creator.create_string('abc'):at(100)
    self.assertEqual(packet_getter.get_str(p), 'abc')
    self.assertEqual(p.timestamp.value, 100)
    p.timestamp = 200
    self.assertEqual(p.timestamp.value, 200)
end

local function test_int_array_packet(self)
    local p = packet_creator.create_int_array({ 1, 2, 3 }):at(100)
    self.assertEqual(p.timestamp.value, 100)
end

local function test_float_array_packet(self)
    local p = packet_creator.create_float_array({ 0.1, 0.2, 0.3 }):at(100)
    self.assertEqual(p.timestamp.value, 100)
end

local function test_int_vector_packet(self)
    local p = packet_creator.create_int_vector({ 1, 2, 3 }):at(100)
    self.assertListEqual(packet_getter.get_int_list(p), { 1, 2, 3 })
    self.assertEqual(p.timestamp.value, 100)
end

local function test_float_vector_packet(self)
    local p = packet_creator.create_float_vector({ 0.1, 0.2, 0.3 }):at(100)
    local output_list = packet_getter.get_float_list(p)
    self.assertAlmostEqual(output_list[0 + INDEX_BASE], 0.1)
    self.assertAlmostEqual(output_list[1 + INDEX_BASE], 0.2)
    self.assertAlmostEqual(output_list[2 + INDEX_BASE], 0.3)
    self.assertEqual(p.timestamp.value, 100)
end

local function test_image_vector_packet(self)
    local w, h, offset = 80, 40, 10
    local mat = _mat_utils.randomImage(w, h, cv2.CV_8UC3, 0, 2 ^ 8)
    local roi = mat:new({ offset, offset, w - 2 * offset, h - 2 * offset })
    local p = packet_creator.create_image_vector({
        Image(mediapipe_lua.kwargs({ image_format = ImageFormat.SRGB, data = mat })),
        Image(mediapipe_lua.kwargs({
            image_format = ImageFormat.SRGB,
            data = roi
        }))
    }):at(100)
    local output_list = packet_getter.get_image_list(p)
    self.assertLen(output_list, 2)
    self.assertMatEqual(output_list[0 + INDEX_BASE]:mat_view(), mat)
    self.assertMatEqual(output_list[1 + INDEX_BASE]:mat_view(), roi)
    self.assertEqual(p.timestamp.value, 100)
end

local function test_image_frame_vector_packet(self)
    local mat_rgb = _mat_utils.randomImage(40, 30, cv2.CV_8UC3, 0, 2 ^ 8)
    local mat_float = _mat_utils.randomImage(30, 40, cv2.CV_32FC1, 0, 1)
    local p = packet_creator.create_image_frame_vector({
        ImageFrame(mediapipe_lua.kwargs({ image_format = ImageFormat.SRGB, data = mat_rgb })),
        ImageFrame(mediapipe_lua.kwargs({ image_format = ImageFormat.VEC32F1, data = mat_float })),
    }):at(100)
    local output_list = packet_getter.get_image_frame_list(p)
    self.assertLen(output_list, 2)
    self.assertMatEqual(output_list[0 + INDEX_BASE]:mat_view(), mat_rgb)
    self.assertMatEqual(output_list[1 + INDEX_BASE]:mat_view(), mat_float)
    self.assertEqual(p.timestamp.value, 100)
end

local function test_get_image_frame_list_packet_capture(self)
    local h, w = 30, 40
    local p = packet_creator.create_image_frame_vector({
        ImageFrame(mediapipe_lua.kwargs({
            image_format = ImageFormat.SRGB,
            data = cv2.Mat.ones(w, h, cv2.CV_8UC3),
        })),
    }):at(100)
    local output_list = packet_getter.get_image_frame_list(p)
    -- Even if the packet variable p gets deleted, the packet object still exists
    -- because it is captured by the deleter of the ImageFrame in the returned
    -- output_list.
    p = nil
    collectgarbage()
    self.assertLen(output_list, 1)
    self.assertEqual(output_list[0 + INDEX_BASE].image_format, ImageFormat.SRGB)
    self.assertMatEqual(output_list[0 + INDEX_BASE]:mat_view(), cv2.Mat.ones(w, h, cv2.CV_8UC3))
end

local function test_string_vector_packet(self)
    local p = packet_creator.create_string_vector({ 'a', 'b', 'c' }):at(100)
    self.assertListEqual(packet_getter.get_str_list(p), { 'a', 'b', 'c' })
    self.assertEqual(p.timestamp.value, 100)
end

local function test_packet_vector_packet(self)
    local p = packet_creator.create_packet_vector({
        packet_creator.create_float(0.42),
        packet_creator.create_int(42),
        packet_creator.create_string('42')
    }):at(100)
    local output_list = packet_getter.get_packet_list(p)
    self.assertAlmostEqual(packet_getter.get_float(output_list[0 + INDEX_BASE]), 0.42)
    self.assertEqual(packet_getter.get_int(output_list[1 + INDEX_BASE]), 42)
    self.assertEqual(packet_getter.get_str(output_list[2 + INDEX_BASE]), '42')
    self.assertEqual(p.timestamp.value, 100)
end

local function test_string_to_packet_map_packet(self)
    local p = packet_creator.create_string_to_packet_map({
        ['float'] = packet_creator.create_float(0.42),
        ['int'] = packet_creator.create_int(42),
        ['string'] = packet_creator.create_string('42')
    }):at(100)
    local output_list = packet_getter.get_str_to_packet_dict(p)
    self.assertAlmostEqual(packet_getter.get_float(output_list['float']), 0.42)
    self.assertEqual(packet_getter.get_int(output_list['int']), 42)
    self.assertEqual(packet_getter.get_str(output_list['string']), '42')
    self.assertEqual(p.timestamp.value, 100)
end

local function test_uint8_image_packet(self)
    local uint8_img = _mat_utils.randomImage(math.random(3, 100), math.random(3, 100), cv2.CV_8UC3, 0, 2 ^ 8)
    local image_frame_packet = packet_creator.create_image_frame(
        image_frame.ImageFrame(mediapipe_lua.kwargs({
            image_format = image_frame.ImageFormat.SRGB, data = uint8_img })))
    local output_image_frame = packet_getter.get_image_frame(image_frame_packet)
    self.assertMatEqual(output_image_frame:mat_view(), uint8_img)
    local image_packet = packet_creator.create_image(
        Image(mediapipe_lua.kwargs({ image_format = ImageFormat.SRGB, data = uint8_img })))
    local output_image = packet_getter.get_image(image_packet)
    self.assertMatEqual(output_image:mat_view(), uint8_img)
end

local function test_uint16_image_packet(self)
    local uint16_img = _mat_utils.randomImage(math.random(3, 100), math.random(3, 100), cv2.CV_16UC4, 0, 2 ^ 16)
    local image_frame_packet = packet_creator.create_image_frame(
        ImageFrame(mediapipe_lua.kwargs({ image_format = ImageFormat.SRGBA64, data = uint16_img })))
    local output_image_frame = packet_getter.get_image_frame(image_frame_packet)
    self.assertMatEqual(output_image_frame:mat_view(), uint16_img)
    local image_packet = packet_creator.create_image(
        Image(mediapipe_lua.kwargs({ image_format = ImageFormat.SRGBA64, data = uint16_img })))
    local output_image = packet_getter.get_image(image_packet)
    self.assertMatEqual(output_image:mat_view(), uint16_img)
end

local function test_float_image_frame_packet(self)
    local float_img = _mat_utils.randomImage(math.random(3, 100), math.random(3, 100), cv2.CV_32FC2, 0.0, 1.0)
    local image_frame_packet = packet_creator.create_image_frame(
        ImageFrame(mediapipe_lua.kwargs({ image_format = ImageFormat.VEC32F2, data = float_img })))
    local output_image_frame = packet_getter.get_image_frame(image_frame_packet)
    self.assertMatAlmostEqual(output_image_frame:mat_view(), float_img)
    local image_packet = packet_creator.create_image(
        Image(mediapipe_lua.kwargs({ image_format = ImageFormat.VEC32F2, data = float_img })))
    local output_image = packet_getter.get_image(image_packet)
    self.assertMatEqual(output_image:mat_view(), float_img)
end

local function test_image_frame_packet_creation_copy_mode(self)
    local w, h, channels = math.random(3, 100), math.random(3, 100), 3
    local rgb_data = _mat_utils.randomImage(w, h, cv2.CV_MAKETYPE(cv2.CV_8U, channels), 0, 2 ^ 8)
    local p = packet_creator.create_image_frame(mediapipe_lua.kwargs({
        image_format = ImageFormat.SRGB, data = rgb_data }))

    local output_frame = packet_getter.get_image_frame(p)
    self.assertEqual(output_frame.height, h)
    self.assertEqual(output_frame.width, w)
    self.assertEqual(output_frame.channels, channels)
    self.assertMatEqual(output_frame:mat_view(), rgb_data)
end

local function test_image_frame_packet_creation_reference_mode(self)
    local w, h, channels = math.random(3, 100), math.random(3, 100), 3
    local rgb_data = _mat_utils.randomImage(w, h, cv2.CV_MAKETYPE(cv2.CV_8U, channels), 0, 2 ^ 8)
    local image_frame_packet = packet_creator.create_image_frame(mediapipe_lua.kwargs({
        image_format = ImageFormat.SRGB, data = rgb_data, copy = false }))
    image_frame_packet = nil
    collectgarbage()
    local rgb_data_copy = rgb_data:copy()

    local text_config = [[
        node {
            calculator: 'PassThroughCalculator'
            input_side_packet: "in"
            output_side_packet: "out"
        }
    ]]

    local graph = CalculatorGraph(mediapipe_lua.kwargs({ graph_config = text_config }))
    graph:start_run(mediapipe_lua.kwargs({
        input_side_packets = {
            ['in'] =
                packet_creator.create_image_frame(mediapipe_lua.kwargs({
                    image_format = ImageFormat.SRGB, data = rgb_data, copy = false }))
        }
    }))
    graph:wait_until_done()
    local output_packet = graph:get_output_side_packet('out')
    -- rgb_data = nil
    graph = nil
    collectgarbage()
    -- The pixel data of the output image frame packet should still be valid
    -- after the graph and the original rgb_data data are deleted.
    self.assertMatEqual(
        packet_getter.get_image_frame(output_packet):mat_view(),
        rgb_data_copy)
end

local function test_image_frame_packet_copy_creation_with_cropping(self)
    local w, h = math.random(40, 100), math.random(40, 100)
    local channels, offset = 3, 10
    local rgb_data = _mat_utils.randomImage(w, h, cv2.CV_MAKETYPE(cv2.CV_8U, channels), 0, 2 ^ 8)
    local roi = rgb_data:new({ offset, offset, w - 2 * offset, h - 2 * offset })
    local p = packet_creator.create_image_frame(mediapipe_lua.kwargs({
        image_format = ImageFormat.SRGB,
        data = roi
    }))
    local output_frame = packet_getter.get_image_frame(p)
    self.assertEqual(output_frame.height, h - 2 * offset)
    self.assertEqual(output_frame.width, w - 2 * offset)
    self.assertEqual(output_frame.channels, channels)
    self.assertMatEqual(roi, output_frame:mat_view())
end

local function test_image_packet_creation_copy_mode(self)
    local w, h, channels = math.random(3, 100), math.random(3, 100), 3
    local rgb_data = _mat_utils.randomImage(w, h, cv2.CV_MAKETYPE(cv2.CV_8U, channels), 0, 2 ^ 8)
    local p = packet_creator.create_image(mediapipe_lua.kwargs({
        image_format = ImageFormat.SRGB, data = rgb_data }))

    local output_image = packet_getter.get_image(p)
    self.assertEqual(output_image.height, h)
    self.assertEqual(output_image.width, w)
    self.assertEqual(output_image.channels, channels)
    self.assertMatEqual(output_image:mat_view(), rgb_data)
end

local function test_image_packet_creation_reference_mode(self)
    local w, h, channels = math.random(3, 100), math.random(3, 100), 3
    local rgb_data = _mat_utils.randomImage(w, h, cv2.CV_MAKETYPE(cv2.CV_8U, channels), 0, 2 ^ 8)
    local image_packet = packet_creator.create_image(mediapipe_lua.kwargs({
        image_format = ImageFormat.SRGB, data = rgb_data, copy = false }))
    image_packet = nil
    collectgarbage()
    local rgb_data_copy = rgb_data:copy()
    local text_config = [[
        node {
            calculator: 'PassThroughCalculator'
            input_side_packet: "in"
            output_side_packet: "out"
        }
    ]]
    local graph = CalculatorGraph(mediapipe_lua.kwargs({ graph_config = text_config }))
    graph:start_run(mediapipe_lua.kwargs({
        input_side_packets = {
            ['in'] =
                packet_creator.create_image(mediapipe_lua.kwargs({
                    image_format = ImageFormat.SRGB, data = rgb_data, copy = false }))
        }
    }))
    graph:wait_until_done()
    local output_packet = graph:get_output_side_packet('out')
    -- rgb_data = nil
    graph = nil
    collectgarbage()
    -- The pixel data of the output image frame packet should still be valid
    -- after the graph and the original rgb_data data are deleted.
    self.assertMatEqual(
        packet_getter.get_image(output_packet):mat_view(), rgb_data_copy)
end

local function test_image_packet_copy_creation_with_cropping(self)
    local w, h = math.random(40, 100), math.random(40, 100)
    local channels, offset = 3, 10
    local rgb_data = _mat_utils.randomImage(w, h, cv2.CV_MAKETYPE(cv2.CV_8U, channels), 0, 2 ^ 8)
    local roi = rgb_data:new({ offset, offset, w - 2 * offset, h - 2 * offset })
    local p = packet_creator.create_image(mediapipe_lua.kwargs({
        image_format = ImageFormat.SRGB,
        data = roi
    }))
    local output_image = packet_getter.get_image(p)
    self.assertEqual(output_image.height, h - 2 * offset)
    self.assertEqual(output_image.width, w - 2 * offset)
    self.assertEqual(output_image.channels, channels)
    self.assertMatEqual(roi, output_image:mat_view())
end

describe("PacketTest", function()
    it("should test_empty_packet", function()
        test_empty_packet(_assert)
    end)
    it("should test_boolean_packet", function()
        test_boolean_packet(_assert)
    end)
    it("should test_int_packet", function()
        test_int_packet(_assert)
    end)
    it("should test_int8_packet", function()
        test_int8_packet(_assert)
    end)
    it("should test_int16_packet", function()
        test_int16_packet(_assert)
    end)
    it("should test_int32_packet", function()
        test_int32_packet(_assert)
    end)
    it("should test_int64_packet", function()
        test_int64_packet(_assert)
    end)
    it("should test_uint8_packet", function()
        test_uint8_packet(_assert)
    end)
    it("should test_uint16_packet", function()
        test_uint16_packet(_assert)
    end)
    it("should test_uint32_packet", function()
        test_uint32_packet(_assert)
    end)
    it("should test_uint64_packet", function()
        test_uint64_packet(_assert)
    end)
    it("should test_float_packet", function()
        test_float_packet(_assert)
    end)
    it("should test_double_packet", function()
        test_double_packet(_assert)
    end)
    it("should test_detection_proto_packet", function()
        test_detection_proto_packet(_assert)
    end)
    it("should test_string_packet", function()
        test_string_packet(_assert)
    end)
    it("should test_int_array_packet", function()
        test_int_array_packet(_assert)
    end)
    it("should test_float_array_packet", function()
        test_float_array_packet(_assert)
    end)
    it("should test_int_vector_packet", function()
        test_int_vector_packet(_assert)
    end)
    it("should test_float_vector_packet", function()
        test_float_vector_packet(_assert)
    end)
    it("should test_image_vector_packet", function()
        test_image_vector_packet(_assert)
    end)
    it("should test_image_frame_vector_packet", function()
        test_image_frame_vector_packet(_assert)
    end)
    it("should test_get_image_frame_list_packet_capture", function()
        test_get_image_frame_list_packet_capture(_assert)
    end)
    it("should test_string_vector_packet", function()
        test_string_vector_packet(_assert)
    end)
    it("should test_packet_vector_packet", function()
        test_packet_vector_packet(_assert)
    end)
    it("should test_string_to_packet_map_packet", function()
        test_string_to_packet_map_packet(_assert)
    end)
    it("should test_uint8_image_packet", function()
        test_uint8_image_packet(_assert)
    end)
    it("should test_uint16_image_packet", function()
        test_uint16_image_packet(_assert)
    end)
    it("should test_float_image_frame_packet", function()
        test_float_image_frame_packet(_assert)
    end)
    it("should test_image_frame_packet_creation_copy_mode", function()
        test_image_frame_packet_creation_copy_mode(_assert)
    end)
    it("should test_image_frame_packet_creation_reference_mode", function()
        test_image_frame_packet_creation_reference_mode(_assert)
    end)
    it("should test_image_frame_packet_copy_creation_with_cropping", function()
        test_image_frame_packet_copy_creation_with_cropping(_assert)
    end)
    it("should test_image_packet_creation_copy_mode", function()
        test_image_packet_creation_copy_mode(_assert)
    end)
    it("should test_image_packet_creation_reference_mode", function()
        test_image_packet_creation_reference_mode(_assert)
    end)
    it("should test_image_packet_copy_creation_with_cropping", function()
        test_image_packet_copy_creation_with_cropping(_assert)
    end)
end)
