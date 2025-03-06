module.exports = ({self, self_get, language}) => [
    ["class mediapipe.Packet", "", ["/Simple"], [], "", ""],

    ["mediapipe.Packet.Packet", "mediapipe.Packet.Packet", [], [], "", ""],

    ["mediapipe.Packet.Packet", "mediapipe.Packet.Packet", [], [
        ["mediapipe::Packet", "Packet", "", ["/Ref", "/C"]],
    ], "", ""],

    ["mediapipe.Packet.", "", ["/Properties"], [
        ["mediapipe::Timestamp", "timestamp", "", [
            "/R", "=Timestamp()",
            `/WExpr=${ self } = std::move(${ self_get("At") }($value))`,
            "/WType=int64_t", `/WExpr=${ self } = std::move(${ self_get("At") }(Timestamp($value)))`,
        ]],
    ], "", ""],

    ["mediapipe.Packet.IsEmpty", "bool", ["=is_empty"], [], "", ""],

    ["mediapipe.Packet.At", "mediapipe::Packet", ["=at"], [
        ["int64_t", "ts_value", "", ["/Cast=Timestamp"]],
    ], "", ""],

    ["mediapipe.Packet.At", "mediapipe::Packet", ["=at"], [
        ["Timestamp", "ts", "", []],
    ], "", ""],

    ["mediapipe.Packet.sol::meta_function::to_string", "std::string", ["/Call=Packet__tostring", `/Expr=${ self }`], [], "", ""],

    // expose a packet property like in mediapipe python
    [`mediapipe.${ language }._framework_bindings.packet.`, "", ["/Properties"], [
        ["mediapipe::Packet", "Packet", "", ["/R", "=this", "/S"]],
    ], "", ""],
];
