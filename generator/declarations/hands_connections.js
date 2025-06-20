module.exports = ({language}) => [
    [`mediapipe.${ language }.solutions.hands_connections.`, "", ["/Properties"], [
        ["std::vector<std::tuple<int, int>>", "HAND_PALM_CONNECTIONS", "", ["/R", "/C"]],
        ["std::vector<std::tuple<int, int>>", "HAND_THUMB_CONNECTIONS", "", ["/R", "/C"]],
        ["std::vector<std::tuple<int, int>>", "HAND_INDEX_FINGER_CONNECTIONS", "", ["/R", "/C"]],
        ["std::vector<std::tuple<int, int>>", "HAND_MIDDLE_FINGER_CONNECTIONS", "", ["/R", "/C"]],
        ["std::vector<std::tuple<int, int>>", "HAND_RING_FINGER_CONNECTIONS", "", ["/R", "/C"]],
        ["std::vector<std::tuple<int, int>>", "HAND_PINKY_FINGER_CONNECTIONS", "", ["/R", "/C"]],
        ["std::vector<std::tuple<int, int>>", "HAND_CONNECTIONS", "", ["/R", "/C"]],
    ], "", ""],
];
