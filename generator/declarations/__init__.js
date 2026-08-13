module.exports = ({language}) => [
    // In python, 'import mediapipe.tasks.python' will load the module define by the file mediapipe/tasks/python/__init__.py
    // The equivalent in COM is CreateObj('mediapipe.tasks.autoit')
    // In python, 'from mediapipe.tasks import python' will load the module define by the file mediapipe/tasks/__init__.py and expose module.python
    // The equivalent in COM is CreateObj('mediapipe.tasks').autoit
    // In lua, it is only possible to chain properties from the root module, i.e. require("mediapipe_lua").mediapipe.tasks.lua
    // Therefore, after require("mediapipe_lua").mediapipe.tasks = require("mediapipe_lua").mediapipe.tasks.lua,
    //     lua_rawget_create_if_nil(L, { "mediapipe", "tasks", "lua" }) will create a new table, not reusing the one before assignation
    // Therefore losing the previously setted properties and metatable
    // To work around that constraint, in c++, it is done mediapipe.tasks.lua.lua = mediapipe.tasks.lua; mediapipe.tasks = mediapipe.tasks.lua

    // import mediapipe.tasks.python as tasks
    // from mediapipe.tasks.python.vision.core.image import Image
    // from mediapipe.tasks.python.vision.core.image import ImageFormat
    // ["mediapipe.", "", ["/Properties"], [
    //     [`mediapipe::tasks::${ language }`, "tasks", "", ["/R", "=this", "/S"]], // Causes mediapipe.tasks.* to no more be functional
    //     ["mediapipe::Image", "Image", "", ["/R", "=this", "/S"]],
    //     ["mediapipe::ImageFormat::Format", "ImageFormat", "", ["/R", "=this", "/S"]], // Causes mediapipe.ImageFormat.Format to no more be functional
    // ], "", ""],
];
