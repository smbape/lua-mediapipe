local mediapipe_lua = require("mediapipe_lua")
local text_format = mediapipe_lua.google.protobuf.text_format
local cmessage = mediapipe_lua.google.protobuf.lua.cmessage
local _assert = require("_assert")

function _assert.assertProtoEquals(first, second, msg)
    if type(first) == "string" then
        first = text_format.Parse(first, second.new())
    end

    cmessage.NomalizeNumberFields(first)
    cmessage.NomalizeNumberFields(second)

    if msg == nil then
        msg = "expecting both proto buffers to be equals"
    end
    _assert.assertEqual(first, second, msg)
end

return nil
