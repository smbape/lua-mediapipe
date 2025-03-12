module.exports = ({language}) => [
    [`mediapipe.${ language }.solutions.face_mesh_connections.`, "", ["/Properties"], [
        ["std::vector<std::tuple<int, int>>", "FACEMESH_LIPS", "", ["/R", "/C"]],
        ["std::vector<std::tuple<int, int>>", "FACEMESH_LEFT_EYE", "", ["/R", "/C"]],
        ["std::vector<std::tuple<int, int>>", "FACEMESH_LEFT_IRIS", "", ["/R", "/C"]],
        ["std::vector<std::tuple<int, int>>", "FACEMESH_LEFT_EYEBROW", "", ["/R", "/C"]],
        ["std::vector<std::tuple<int, int>>", "FACEMESH_RIGHT_EYE", "", ["/R", "/C"]],
        ["std::vector<std::tuple<int, int>>", "FACEMESH_RIGHT_EYEBROW", "", ["/R", "/C"]],
        ["std::vector<std::tuple<int, int>>", "FACEMESH_RIGHT_IRIS", "", ["/R", "/C"]],
        ["std::vector<std::tuple<int, int>>", "FACEMESH_FACE_OVAL", "", ["/R", "/C"]],
        ["std::vector<std::tuple<int, int>>", "FACEMESH_NOSE", "", ["/R", "/C"]],
        ["std::vector<std::tuple<int, int>>", "FACEMESH_CONTOURS", "", ["/R", "/C"]],
        ["std::vector<std::tuple<int, int>>", "FACEMESH_IRISES", "", ["/R", "/C"]],
        ["std::vector<std::tuple<int, int>>", "FACEMESH_TESSELATION", "", ["/R", "/C"]],
    ], "", ""],
];
