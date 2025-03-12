module.exports = ({language}) => {
    const ns_face_mesh_connections = `mediapipe::${ language }::solutions::face_mesh_connections`;

    return [
        [`mediapipe.${ language }.solutions.face_mesh.`, "", ["/Properties"], [
            ["int", "FACEMESH_NUM_LANDMARKS", "", ["/R", "/C"]],
            ["int", "FACEMESH_NUM_LANDMARKS_WITH_IRISES", "", ["/R", "/C"]],
            ["std::vector<std::tuple<int, int>>", "FACEMESH_CONTOURS", "", [`/RExpr=${ ns_face_mesh_connections }::FACEMESH_CONTOURS`, "/C"]],
            ["std::vector<std::tuple<int, int>>", "FACEMESH_FACE_OVAL", "", [`/RExpr=${ ns_face_mesh_connections }::FACEMESH_FACE_OVAL`, "/C"]],
            ["std::vector<std::tuple<int, int>>", "FACEMESH_IRISES", "", [`/RExpr=${ ns_face_mesh_connections }::FACEMESH_IRISES`, "/C"]],
            ["std::vector<std::tuple<int, int>>", "FACEMESH_LEFT_EYE", "", [`/RExpr=${ ns_face_mesh_connections }::FACEMESH_LEFT_EYE`, "/C"]],
            ["std::vector<std::tuple<int, int>>", "FACEMESH_LEFT_EYEBROW", "", [`/RExpr=${ ns_face_mesh_connections }::FACEMESH_LEFT_EYEBROW`, "/C"]],
            ["std::vector<std::tuple<int, int>>", "FACEMESH_LEFT_IRIS", "", [`/RExpr=${ ns_face_mesh_connections }::FACEMESH_LEFT_IRIS`, "/C"]],
            ["std::vector<std::tuple<int, int>>", "FACEMESH_LIPS", "", [`/RExpr=${ ns_face_mesh_connections }::FACEMESH_LIPS`, "/C"]],
            ["std::vector<std::tuple<int, int>>", "FACEMESH_NOSE", "", [`/RExpr=${ ns_face_mesh_connections }::FACEMESH_NOSE`, "/C"]],
            ["std::vector<std::tuple<int, int>>", "FACEMESH_RIGHT_EYE", "", [`/RExpr=${ ns_face_mesh_connections }::FACEMESH_RIGHT_EYE`, "/C"]],
            ["std::vector<std::tuple<int, int>>", "FACEMESH_RIGHT_EYEBROW", "", [`/RExpr=${ ns_face_mesh_connections }::FACEMESH_RIGHT_EYEBROW`, "/C"]],
            ["std::vector<std::tuple<int, int>>", "FACEMESH_RIGHT_IRIS", "", [`/RExpr=${ ns_face_mesh_connections }::FACEMESH_RIGHT_IRIS`, "/C"]],
            ["std::vector<std::tuple<int, int>>", "FACEMESH_TESSELATION", "", [`/RExpr=${ ns_face_mesh_connections }::FACEMESH_TESSELATION`, "/C"]],
        ], "", ""],
    ];
};
