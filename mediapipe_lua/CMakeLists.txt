cmake_minimum_required(VERSION 3.25)

# ================================================================
# bit.lua
# ================================================================
function(mediapipe_write_bit_lua)
    set(mediapipe_GENERATED_INCLUDE_DIR "${CMAKE_SOURCE_DIR}/generated")
    file(READ "${CMAKE_SOURCE_DIR}/src/lua/bit.lua" _new_bit_string)

    set(_new_bit_string "R\"cdata(${_new_bit_string})cdata\"")
    set(bit_lua_FILE "${mediapipe_GENERATED_INCLUDE_DIR}/bit_string.lua.inc")

    if(EXISTS "${bit_lua_FILE}")
        file(READ "${bit_lua_FILE}" _old_bit_string)
    else()
        set(_old_bit_string "")
    endif()

    if(NOT (_old_bit_string STREQUAL _new_bit_string))
        file(WRITE "${bit_lua_FILE}" "${_new_bit_string}")
    endif()
endfunction()

mediapipe_write_bit_lua()
# ================================================================

# ===============
# Mediapipe Lua
# ===============
set(target_name mediapipe_lua)

include(GNUInstallDirs)
include(version.cmake)
include(../cmake/vcpkg_regex_replace_string.cmake)

file(RELATIVE_PATH relative_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}" "${CMAKE_SOURCE_DIR}")

file(GLOB_RECURSE files_to_change
    ${relative_SOURCE_DIR}README.md
    ${relative_SOURCE_DIR}docs/hosting-you-own-binary-rocks-*
    ${relative_SOURCE_DIR}generator/index.js
    ${relative_SOURCE_DIR}luarocks/${target_name}-scm-1.rockspec
    ${relative_SOURCE_DIR}samples/*.lua
    ${relative_SOURCE_DIR}test/*.lua
    ${relative_SOURCE_DIR}scripts/new_version.lua
    ${relative_SOURCE_DIR}scripts/pack.js
    ${relative_SOURCE_DIR}scripts/prepublish.js
    ${relative_SOURCE_DIR}scripts/manual.sh
    ${relative_SOURCE_DIR}scripts/tasks.sh
    ${relative_SOURCE_DIR}BUILD
)

foreach(item ${files_to_change})
    vcpkg_regex_replace_string("${item}" "(/lua-mediapipe/releases/download/v|/lua-mediapipe/tree/v)[0-9]+\\.[0-9]+\\.[0-9]+" "\\1${PROJECT_VERSION}")
    vcpkg_regex_replace_string("${item}" "(/google-ai-edge/mediapipe/archive/refs/tags/v|/google-ai-edge/mediapipe/blob/v|mediapipe-|MEDIAPIPE_VERSION:-|${target_name} )[0-9]+(\\.[0-9]+)+" "\\1${Mediapipe_VERSION}")
    vcpkg_regex_replace_string("${item}" "MEDIAPIPE_VERSION = \"[0-9]+(\\.[0-9]+)+\"" "MEDIAPIPE_VERSION = \"${Mediapipe_VERSION}\"")
    vcpkg_regex_replace_string("${item}" "/v[0-9]+(\\.[0-9]+)+/mediapipe/" "/v${Mediapipe_VERSION}/mediapipe/")
    vcpkg_regex_replace_string("${item}" "(--branch v)[0-9]+\\.[0-9]+\\.[0-9]+( https://github.com/smbape/lua-mediapipe)" "\\1${PROJECT_VERSION}\\2")
    vcpkg_regex_replace_string("${item}" "(opencv-|/opencv/opencv/blob/|opencv_lua |OPENCV_VERSION:-)[0-9]+\\.[0-9]+\\.[0-9]+" "\\1${OpenCV_VERSION}")
endforeach()

set(EXECUTABLE_OUTPUT_PATH "${CMAKE_BINARY_DIR}/bin" CACHE PATH "Output directory for applications")
set(LIBRARY_OUTPUT_PATH "${CMAKE_BINARY_DIR}/lib" CACHE PATH "Output directory for libraries")

if (WIN32)
    # Avoid long paths on windows
    # https://bazel.build/remote/output-directories#layout
    set(OUTPUT_USER_ROOT "C:/_bazel_" CACHE PATH "Bazel output user root")
elseif(FALSE)
    # Avoid remaining temp files with installing from source with luarocks
    # Having OUTPUT_USER_ROOT inside CMAKE_SOURCE_DIR will cause an infinite Re-running CMake...
    # because bazel sets some of its file modification time in the future.
    # Changing those file modification time will cause bazel to say it is corrupted
    set(OUTPUT_USER_ROOT "${CMAKE_SOURCE_DIR}/.cache/_bazel_" CACHE PATH "Bazel output user root")

    if (EXISTS "${OUTPUT_USER_ROOT}")
        # Avoid infinite Re-running CMake...
        # because bazel files are in the future
        execute_process(
            COMMAND find "${OUTPUT_USER_ROOT}/install" -newermt "+0 days" -exec touch -r "${CMAKE_BINARY_DIR}/CMakeCache.txt" {} ";"
        )
    endif()
endif()

find_program(BAZEL_EXECUTABLE
    NAMES bazelisk bazel
    DOC "Bazel executable"
    REQUIRED
)

option(MEDIAPIPE_DISABLE_GPU "Disable GPU support" ON)

if (WIN32 AND NOT MEDIAPIPE_DISABLE_GPU)
    message(FATAL_ERROR "GPU Delegate is not yet supported for Windows")
endif()

set(BAZEL_GPU_OPTIONS)

if (MEDIAPIPE_DISABLE_GPU)
    list(APPEND BAZEL_GPU_OPTIONS --define MEDIAPIPE_DISABLE_GPU=1)
else()
    list(APPEND BAZEL_GPU_OPTIONS
        --copt=-DTFLITE_GPU_EXTRA_GLES_DEPS
        --copt=-DMEDIAPIPE_OMIT_EGL_WINDOW_BIT
        --copt=-DMESA_EGL_NO_X11_HEADERS
        --copt=-DEGL_NO_X11
    )

    if (CMAKE_SYSTEM_NAME STREQUAL "Darwin")
        list(APPEND BAZEL_GPU_OPTIONS --copt=-DMEDIAPIPE_GPU_BUFFER_USE_CV_PIXEL_BUFFER)
    endif()
endif()

set(BAZEL_BUILD
    "${BAZEL_EXECUTABLE}"
)

if (DEFINED OUTPUT_USER_ROOT)
    list(APPEND BAZEL_BUILD "--output_user_root=${OUTPUT_USER_ROOT}")
endif()

if (DEFINED OUTPUT_BASE)
    list(APPEND BAZEL_BUILD "--output_base=${OUTPUT_BASE}")
endif()

string(REPLACE ";" "$<SEMICOLON>" ENV_PATH "$ENV{PATH}")

if (UNIX)
    # [Running bazel in a subshell causes subshell to hang](https://github.com/bazelbuild/bazel/issues/19309)
    execute_process(
        COMMAND           "${CMAKE_COMMAND}" -E env "PATH=${ENV_PATH}" -- ${BAZEL_BUILD} info server_pid
        WORKING_DIRECTORY "${mediapipe_SOURCE_DIR}"
    )
endif()

list(APPEND BAZEL_BUILD
    build -c ${COMPILATION_MODE}
    --strip=never
    --verbose_failures

    # --keep_going
    # --sandbox_debug

    # https://github.com/bazelbuild/bazel/issues/8444#issuecomment-513204396
    # --spawn_strategy=local
)

set(BAZEL_BUILD_OPTIONS
    "--repo_env=HERMETIC_PYTHON_VERSION=${Python3_VERSION_MAJOR}.${Python3_VERSION_MINOR}"
    "--action_env=PYTHON_BIN_PATH=${Python3_EXECUTABLE}"
    "--python_path=${Python3_EXECUTABLE}"
)

if (WITH_CUDNN AND NOT WITH_CUDA)
    set(WITH_CUDA ON)
endif()

if (WITH_CUDA)
    if (WIN32)
        message(FATAL_ERROR "Starting in TF 2.11, CUDA build is not supported for Windows. For using TensorFlow GPU on Windows, you will need to build/install TensorFlow in WSL2.")
    endif()
    list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/cuda/Modules")
endif()

if (WITH_CUDA)
    find_package(CUDAToolkit REQUIRED)

    # https://github.com/tensorflow/tensorflow/blob/v2.19.0/.bazelrc#L223-L231
    # https://github.com/tensorflow/tensorflow/blob/v2.19.0/third_party/gpus/cuda/hermetic/cuda_json_init_repository.bzl#L41-L44
    list(APPEND BAZEL_BUILD_OPTIONS
        "--repo_env=TF_NEED_CUDA=1"
        "--repo_env=HERMETIC_CUDA_VERSION=${CUDAToolkit_VERSION}"
        "--repo_env=LOCAL_CUDA_PATH=${CUDAToolkit_LIBRARY_ROOT}"
        # --crosstool_top=@local_config_cuda//crosstool:toolchain
        # --@local_config_cuda//:enable_cuda
        # --@local_config_cuda//cuda:include_cuda_libs=true

        "--action_env=CC=${CMAKE_C_COMPILER}"
        "--action_env=CUDA_NVCC=1"
        # --@local_config_cuda//:cuda_compiler=nvcc
    )

    if (CUDA_ARCH_BIN)
        list(APPEND BAZEL_BUILD_OPTIONS
            "--repo_env=HERMETIC_CUDA_COMPUTE_CAPABILITIES=${CUDA_ARCH_BIN}"
        )
    endif()
endif()

if (WITH_CUDNN)
    set(CUDA_TOOLKIT_ROOT ${CUDAToolkit_LIBRARY_ROOT})
    find_package(CUDNN REQUIRED)

    # ================================
    # create a LOCAL_CUDNN_PATH
    # ================================
    set(LOCAL_CUDNN_PATH "${CMAKE_CURRENT_BINARY_DIR}/cudnn")
    file(MAKE_DIRECTORY "${LOCAL_CUDNN_PATH}/lib")

    file(CREATE_LINK "${CUDNN_INCLUDE_DIR}" "${LOCAL_CUDNN_PATH}/include" SYMBOLIC)

    cmake_path(GET CUDNN_LIBRARY FILENAME CUDNN_LIBRARY_FILENAME)
    file(CREATE_LINK "${CUDNN_LIBRARY}" "${LOCAL_CUDNN_PATH}/lib/${CUDNN_LIBRARY_FILENAME}" SYMBOLIC)
    unset(CUDNN_LIBRARY_FILENAME)
    # ================================

    # https://github.com/tensorflow/tensorflow/blob/v2.19.0/.bazelrc#L229
    # https://github.com/tensorflow/tensorflow/blob/v2.19.0/third_party/gpus/cuda/hermetic/cuda_json_init_repository.bzl#L45-L46
    list(APPEND BAZEL_BUILD_OPTIONS
        "--repo_env=HERMETIC_CUDNN_VERSION=${CUDNN_VERSION}"
        "--repo_env=LOCAL_CUDNN_PATH=${LOCAL_CUDNN_PATH}"
    )
endif()

if (ENABLE_ODML_CONVERTER)
    list(APPEND BAZEL_BUILD_OPTIONS --define ENABLE_ODML_CONVERTER=1)
endif()

if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    # https://man.freebsd.org/cgi/man.cgi?query=gcc11&sektion=1&manpath=freebsd-release-ports
    if (CMAKE_CXX_COMPILER_VERSION VERSION_LESS "11")
        list(APPEND BAZEL_BUILD_OPTIONS --define xnn_enable_avxvnni=false)
    endif()

    enable_language(ASM-ATT)

    if ((CMAKE_CXX_COMPILER_VERSION VERSION_EQUAL "11" OR CMAKE_CXX_COMPILER_VERSION VERSION_GREATER "11") AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS "12" AND CMAKE_ASM-ATT_COMPILER_ID STREQUAL "GNU")
        # binutils gained VNNI support in 2.36
        # https://github.com/google/XNNPACK/issues/6389#issuecomment-2356299909

        execute_process(
            COMMAND sh -c "${CMAKE_ASM-ATT_COMPILER} --version | sed -rn 's/GNU[[:space:]][Aa]ssembler[[:space:]].*[[:space:]]([0-9])/\\1/p'"
            OUTPUT_VARIABLE CMAKE_ASM-ATT_COMPILER_VERSION
        )

        if (NOT CMAKE_ASM-ATT_COMPILER_VERSION VERSION_GREATER_EQUAL "2.36")
            list(APPEND BAZEL_BUILD_OPTIONS --define xnn_enable_avxvnni=false)
        endif()
    endif()

    # https://man.freebsd.org/cgi/man.cgi?query=gcc12&sektion=1&manpath=freebsd-release-ports
    if (CMAKE_CXX_COMPILER_VERSION VERSION_LESS "12")
        list(APPEND BAZEL_BUILD_OPTIONS --define xnn_enable_avx512fp16=false)
    endif()

    # https://man.freebsd.org/cgi/man.cgi?query=gcc13&sektion=1&manpath=freebsd-release-ports
    if (CMAKE_CXX_COMPILER_VERSION VERSION_LESS "13")
        list(APPEND BAZEL_BUILD_OPTIONS --define xnn_enable_avxvnniint8=false)
    endif()
endif()

list(APPEND BAZEL_BUILD_OPTIONS
    --define LUA_MODULE_NAME=${target_name}
    --define LUA_MODULE_VERSION=${LUA_MODULE_VERSION}
    --define LUA_MODULE_LIB_NAME=Mediapipe
    --define LUA_MODULE_LIB_VERSION=${Mediapipe_VERSION}
)

set(BAZEL_BUILD_EXTRA_OPTIONS "" CACHE INTERNAL "Bazel build options")
if (BAZEL_BUILD_EXTRA_OPTIONS)
    list(APPEND BAZEL_BUILD_OPTIONS ${BAZEL_BUILD_EXTRA_OPTIONS})
endif()

list(APPEND BAZEL_BUILD ${BAZEL_GPU_OPTIONS} ${BAZEL_BUILD_OPTIONS})

# Make sure bazel-out is a symbolic link
# add_custom_command will create the directory needed to store OUTPUT.
# However, bazel creates bazel-out as a symbolic link in the output_user_root directory.
# If bazel-out already exists, bazel won't touch it, and generated files will be inacessible.
# The choosen work around is to delete bazel-out if it is not a symbolic link.
# Therefore, allowing bazel to create the symbolic link
set(invalid_SYMLINKS)
foreach(directory IN ITEMS bazel-bin bazel-out bazel-mediapipe-src)
    if (NOT IS_SYMLINK "${mediapipe_SOURCE_DIR}/${directory}")
        list(APPEND invalid_SYMLINKS "${mediapipe_SOURCE_DIR}/${directory}")
    endif()
endforeach()
set(ensure_SYMBOLIC_BAZEL_SYMLINKS "${CMAKE_COMMAND}" -E)
if (invalid_SYMLINKS)
    list(APPEND ensure_SYMBOLIC_BAZEL_SYMLINKS rm -rf ${invalid_SYMLINKS})
else()
    list(APPEND ensure_SYMBOLIC_BAZEL_SYMLINKS echo "Checked symlinks")
endif()

set(mediapipe_source_DEPENDS)

option(BUILD_python_wheel "Build mediapipe python wheel" OFF)

if (BUILD_python_wheel)
    vcpkg_regex_replace_string("${mediapipe_SOURCE_DIR}/setup.py" "__version__ = '[^']*'" "__version__ = '${Mediapipe_VERSION}'")

    set(PY_BAZEL_RC ${BAZEL_BUILD_OPTIONS})
    string(REPLACE ";" "\n" PY_BAZEL_RC "${PY_BAZEL_RC}")
    file(WRITE "${mediapipe_SOURCE_DIR}/.py-bazelrc" "${PY_BAZEL_RC}")

    set(python_wheel_MEDIAPIPE_DISABLE_GPU 0)
    if (MEDIAPIPE_DISABLE_GPU)
        set(python_wheel_MEDIAPIPE_DISABLE_GPU 1)
    endif()

    if (CMAKE_SIZEOF_VOID_P EQUAL 8)
        if (WIN32)
            set(wheel_suffix "win_amd64")
        elseif (LINUX)
            set(wheel_suffix "linux_x86_64")
        else()
            message(FATAL_ERROR "OS is not supported")
        endif()
    elseif(WIN32)
        set(wheel_suffix "win32")
    else()
        message(FATAL_ERROR "x86 build is not supported")
    endif()

    set(python_wheel_OUTPUT "${mediapipe_SOURCE_DIR}/dist/mediapipe-${Mediapipe_VERSION}-cp${Python3_VERSION_MAJOR}${Python3_VERSION_MINOR}-cp${Python3_VERSION_MAJOR}${Python3_VERSION_MINOR}-${wheel_suffix}.whl")

    set(python_wheel_COMMANDS
        COMMAND     ${ensure_SYMBOLIC_BAZEL_SYMLINKS}
        COMMAND     "${Python3_EXECUTABLE}" -m pip install numpy torch wheel
        COMMAND     "${CMAKE_COMMAND}" -E echo ${BAZEL_BUILD} "@com_google_protobuf//:protoc"
        COMMAND     "${CMAKE_COMMAND}" -E env "PATH=${ENV_PATH}" -- ${BAZEL_BUILD} "@com_google_protobuf//:protoc"
        COMMAND     "${CMAKE_COMMAND}" -E echo "${Python3_EXECUTABLE}" setup.py bdist_wheel clean --all
        COMMAND     "${CMAKE_COMMAND}" -E env
                        "PATH=${ENV_PATH}"
                        "OUTPUT_USER_ROOT=${OUTPUT_USER_ROOT}"
                        "OUTPUT_BASE=${OUTPUT_BASE}"
                        "MEDIAPIPE_DISABLE_GPU=${python_wheel_MEDIAPIPE_DISABLE_GPU}"
                        "MEDIAPIPE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
                        "PROTOC=${mediapipe_SOURCE_DIR}/bazel-bin/external/com_google_protobuf/protoc${CMAKE_EXECUTABLE_SUFFIX}"
                        "PROTO_PATH=${mediapipe_SOURCE_DIR}/bazel-mediapipe-src/external/com_google_protobuf/src"
                        --
                        "${Python3_EXECUTABLE}" setup.py bdist_wheel clean --all
    )

    if (LINUX AND ENABLE_REPAIR)
        list(APPEND python_wheel_COMMANDS
            COMMAND           "${Python3_EXECUTABLE}" -m pip install auditwheel
            COMMAND           "${Python3_EXECUTABLE}" -m auditwheel repair "${python_wheel_OUTPUT}" --exclude "opencv_lua.so"
        )
    endif()

    add_custom_command(OUTPUT "${python_wheel_OUTPUT}"
        ${python_wheel_COMMANDS}
        COMMAND           "${CMAKE_COMMAND}" -E touch_nocreate "${python_wheel_OUTPUT}"
        WORKING_DIRECTORY "${mediapipe_SOURCE_DIR}"
        VERBATIM
        USES_TERMINAL
    )
    add_custom_target(${target_name}_python_wheel DEPENDS "${python_wheel_OUTPUT}")

    list(APPEND mediapipe_source_DEPENDS ${target_name}_python_wheel)
endif()

set(mediapipe_source_OUTPUT "${mediapipe_BINARY_DIR}/mediapipe/tasks/c/${CMAKE_SHARED_LIBRARY_PREFIX}mediapipe_source${CMAKE_SHARED_LIBRARY_SUFFIX}")

add_custom_command(OUTPUT "${mediapipe_source_OUTPUT}"
    COMMAND           ${ensure_SYMBOLIC_BAZEL_SYMLINKS}
    COMMAND           "${CMAKE_COMMAND}" -E echo ${BAZEL_BUILD} //mediapipe/tasks/c:mediapipe_source
    COMMAND           "${CMAKE_COMMAND}" -E env "PATH=${ENV_PATH}" -- ${BAZEL_BUILD} //mediapipe/tasks/c:mediapipe_source
    COMMAND           "${CMAKE_COMMAND}" -E touch_nocreate "${mediapipe_source_OUTPUT}"
    WORKING_DIRECTORY "${mediapipe_SOURCE_DIR}"
    DEPENDS           ${mediapipe_source_DEPENDS} ${MEDIAPIPE_REPOSITORIES_DEPENDS}
    VERBATIM
    USES_TERMINAL
)
add_custom_target(${target_name}_mediapipe_source DEPENDS "${mediapipe_source_OUTPUT}" ${MEDIAPIPE_REPOSITORIES_DEPENDS})

set(src_gen_cmd "${NODE_EXECUTABLE}" --unhandled-rejections=strict --trace-uncaught --trace-warnings generator/index.js)
if (ENABLE_ODML_CONVERTER)
    list(APPEND src_gen_cmd -DENABLE_ODML_CONVERTER)
endif()

file(GLOB_RECURSE project_source_headers
    "${relative_SOURCE_DIR}src/*.h"
    "${relative_SOURCE_DIR}src/*.hh"
    "${relative_SOURCE_DIR}src/*.hpp"
    "${relative_SOURCE_DIR}src/*.hxx"
)

file(GLOB_RECURSE generator_files
    "${relative_SOURCE_DIR}generator/*.js"
)

set(generated_OUTPUT "${CMAKE_SOURCE_DIR}/generated/register_all.cpp")
add_custom_command(OUTPUT "${generated_OUTPUT}"
    COMMAND           "${CMAKE_COMMAND}" -E echo ${src_gen_cmd}
    COMMAND           "${CMAKE_COMMAND}" -E env "PATH=${ENV_PATH}" "CMAKE_BINARY_DIR=${CMAKE_BINARY_DIR}" "Python3_EXECUTABLE=${Python3_EXECUTABLE}" -- ${src_gen_cmd}
    COMMAND           "${CMAKE_COMMAND}" -E touch_nocreate "${generated_OUTPUT}"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    DEPENDS           ${project_source_headers} ${target_name}_mediapipe_source ${generator_files}
    VERBATIM
    USES_TERMINAL
)
add_custom_target(${target_name}_generated DEPENDS "${generated_OUTPUT}")

file(GLOB_RECURSE project_rules_files
    "${relative_SOURCE_DIR}rules_impl/*"
    "${relative_SOURCE_DIR}scripts/configure_bazel.js"
)

file(GLOB_RECURSE project_source_headers
    "${relative_SOURCE_DIR}src/*.h"
    "${relative_SOURCE_DIR}src/*.hh"
    "${relative_SOURCE_DIR}src/*.hpp"
    "${relative_SOURCE_DIR}src/*.hxx"
)

file(GLOB_RECURSE project_source_files
    "${relative_SOURCE_DIR}src/*.c"
    "${relative_SOURCE_DIR}src/*.cc"
    "${relative_SOURCE_DIR}src/*.cpp"
    "${relative_SOURCE_DIR}src/*.cxx"
)

file(GLOB_RECURSE project_lua_files
    "${relative_SOURCE_DIR}src/*.lua"
)

set(BAZEL_OUTPUT_NAME "${CMAKE_SHARED_LIBRARY_PREFIX}${target_name}")

set(BAZEL_OUTPUT_LIBRARY "${mediapipe_BINARY_DIR}/${MEDIAPIPE_ADDON_PACKAGE}/${BAZEL_OUTPUT_NAME}")

if (WIN32 OR BUILD_SHARED_LIBS)
    set(BAZEL_OUTPUT_LIBRARY "${BAZEL_OUTPUT_LIBRARY}${CMAKE_SHARED_LIBRARY_SUFFIX}")
    set(OUTPUT_LIBRARY_NAME "${target_name}${CMAKE_SHARED_LIBRARY_SUFFIX}")
else()
    set(BAZEL_OUTPUT_LIBRARY "${BAZEL_OUTPUT_LIBRARY}${CMAKE_STATIC_LIBRARY_SUFFIX}")
    set(OUTPUT_LIBRARY_NAME "${target_name}${CMAKE_STATIC_LIBRARY_SUFFIX}")
endif()

add_custom_command(OUTPUT "${BAZEL_OUTPUT_LIBRARY}"
    COMMAND           ${ensure_SYMBOLIC_BAZEL_SYMLINKS}
    COMMAND           "${CMAKE_COMMAND}" -E echo ${BAZEL_BUILD} ${MEDIAPIPE_ADDON_PACKAGE}:lib
    COMMAND           "${CMAKE_COMMAND}" -E env "PATH=${ENV_PATH}" -- ${BAZEL_BUILD} ${MEDIAPIPE_ADDON_PACKAGE}:lib
    WORKING_DIRECTORY "${mediapipe_SOURCE_DIR}"
    DEPENDS           ${project_source_headers} ${project_source_files} ${project_lua_files} ${project_rules_files} ${target_name}_generated ${MEDIAPIPE_REPOSITORIES_DEPENDS}
    VERBATIM
    USES_TERMINAL
)
add_custom_target(${target_name}_lib DEPENDS "${BAZEL_OUTPUT_LIBRARY}" ${MEDIAPIPE_REPOSITORIES_DEPENDS})

add_custom_target(${target_name} ALL DEPENDS ${target_name}_lib)

if (MSVC AND NOT (CMAKE_GENERATOR STREQUAL "Ninja"))
    set(EXECUTABLE_OUTPUT_PATH "${EXECUTABLE_OUTPUT_PATH}/${CMAKE_BUILD_TYPE}")
    set(LIBRARY_OUTPUT_PATH "${LIBRARY_OUTPUT_PATH}/${CMAKE_BUILD_TYPE}")
endif()

if (WIN32)
    set(TARGET_FILE "${EXECUTABLE_OUTPUT_PATH}/${OUTPUT_LIBRARY_NAME}")

    add_custom_command(TARGET ${target_name} POST_BUILD
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "${BAZEL_OUTPUT_LIBRARY}"
            "${TARGET_FILE}"

        COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "${mediapipe_BINARY_DIR}/${MEDIAPIPE_ADDON_PACKAGE}/${BAZEL_OUTPUT_NAME}.pdb"
            "${EXECUTABLE_OUTPUT_PATH}/${target_name}.pdb"

        COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "${mediapipe_BINARY_DIR}/${MEDIAPIPE_ADDON_PACKAGE}/${BAZEL_OUTPUT_NAME}.if${CMAKE_STATIC_LIBRARY_SUFFIX}"
            "${LIBRARY_OUTPUT_PATH}/${target_name}${CMAKE_STATIC_LIBRARY_SUFFIX}"

        COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "${mediapipe_BINARY_DIR}/${MEDIAPIPE_ADDON_PACKAGE}/${BAZEL_OUTPUT_NAME}.if.exp"
            "${LIBRARY_OUTPUT_PATH}/${target_name}.exp"
        COMMENT "Copy outputs ..." 
    )
else()
    set(TARGET_FILE "${LIBRARY_OUTPUT_PATH}/${OUTPUT_LIBRARY_NAME}")

    add_custom_command(
        TARGET ${target_name}
        POST_BUILD
        COMMAND "${CMAKE_COMMAND}"
        ARGS
            "-DORIGIN_FILE=${BAZEL_OUTPUT_LIBRARY}"
            "-DTARGET_FILE=${TARGET_FILE}"
            -P "${CMAKE_CURRENT_SOURCE_DIR}/copy_soname.cmake"

        COMMENT "Copy outputs ..." 
    )

endif()

foreach(item
    "mediapipe/modules/objectron/object_detection_oidv4_labelmap.txt"
    "mediapipe/modules/hand_landmark/handedness.txt"
)
    get_filename_component(item_target "${item}" NAME_WLE)
    set(item_output "${mediapipe_BINARY_DIR}/${item}")

    # copy ${mediapipe_SOURCE_DIR}/${item} to ${mediapipe_BINARY_DIR}/${item}
    add_custom_command(OUTPUT "${item_output}"
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different
                "${mediapipe_SOURCE_DIR}/${item}"
                "${mediapipe_BINARY_DIR}/${item}"
        DEPENDS ${target_name}_lib
        VERBATIM
    )
    add_custom_target(${item_target} DEPENDS "${item_output}")

    add_dependencies(${target_name} ${item_target})

    unset(item_output)
    unset(item_target)
endforeach()

if (WITH_LUA_ROCKS)
    include(../cmake/set_startup_project.cmake)
endif()

# ===============
# Mediapipe Lua Install
# ===============
if (WITH_LUA_ROCKS)
    file(RELATIVE_PATH INST_LIBDIR "${CMAKE_INSTALL_PREFIX}" "${LUA_INSTALL_LIBDIR}")
    file(RELATIVE_PATH INST_LUADIR "${CMAKE_INSTALL_PREFIX}" "${LUA_INSTALL_LUADIR}")

    set(LIBRAY_DESTINATION "${INST_LIBDIR}")
    set(ARCHIVE_DESTINATION "${INST_LIBDIR}/${target_name}/devel/lib")
    set(LUAMOD_DESTINATION "${INST_LUADIR}")
else()
    set(LIBRAY_DESTINATION "${CMAKE_INSTALL_LIBDIR}")
    set(ARCHIVE_DESTINATION "${CMAKE_INSTALL_LIBDIR}")
    set(LUAMOD_DESTINATION "lua")
endif()

install(FILES "${TARGET_FILE}" DESTINATION "${LIBRAY_DESTINATION}")

if (WIN32)
    install(
        FILES "${LIBRARY_OUTPUT_PATH}/${target_name}${CMAKE_STATIC_LIBRARY_SUFFIX}"
        DESTINATION "${CMAKE_INSTALL_LIBDIR}"
        RENAME "${BAZEL_OUTPUT_NAME}${CMAKE_STATIC_LIBRARY_SUFFIX}"
    )
endif()

# ===============
# Allegro5 Lua Repair
# ===============
install(CODE "
set(TARGET_EXPORT_NAME ${TARGET_EXPORT_NAME})
set(LIBRAY_DESTINATION ${LIBRAY_DESTINATION})
set(ARCHIVE_DESTINATION ${ARCHIVE_DESTINATION})
set(CMAKE_CONFIG_DESTINATION ${CMAKE_CONFIG_DESTINATION})
set(LUAMOD_DESTINATION ${LUAMOD_DESTINATION})
")

if (WITH_LUA_ROCKS)
    cmake_path(RELATIVE_PATH mediapipe_BINARY_DIR BASE_DIRECTORY "${CMAKE_BINARY_DIR}" OUTPUT_VARIABLE mediapipe_RELATIVE_BINARY_DIR)
    install(CODE "set(mediapipe_SOURCE_DIR \"${mediapipe_SOURCE_DIR}\")")
    install(CODE "set(mediapipe_BINARY_DIR \"${mediapipe_BINARY_DIR}\")")
    install(CODE "set(mediapipe_RELATIVE_BINARY_DIR \"${mediapipe_RELATIVE_BINARY_DIR}\")")
    install(SCRIPT "install_generated_files.cmake")
endif()

option(ENABLE_REPAIR "Repair installed library to ease distribution" OFF)

if (ENABLE_REPAIR)
    if (WIN32)
        add_library(${target_name}_loader SHARED loader.cpp)

        target_compile_definitions(${target_name}_loader PRIVATE
            LUA_MODULE_NAME=${target_name}
            LUA_MODULE_VERSION=${LUA_MODULE_VERSION}
            LUA_MODULE_LIB_NAME=Allegro5
            LUA_MODULE_LIB_VERSION=${Allegro5_VERSION}
            LUAAPI_EXPORTS
        )

        target_include_directories(${target_name}_loader PRIVATE
            "${CMAKE_SOURCE_DIR}/src/include"
        )

        target_link_libraries(${target_name}_loader PRIVATE ${LUA_LIBRARIES})
        target_include_directories(${target_name}_loader PRIVATE ${LUA_INCLUDE_DIR})

        install(TARGETS ${target_name}_loader
            LIBRARY DESTINATION "${LIBRAY_DESTINATION}/${target_name}"
            RUNTIME DESTINATION "${LIBRAY_DESTINATION}/${target_name}"
            ARCHIVE DESTINATION "${ARCHIVE_DESTINATION}/${target_name}"
        )

        set(REPAIR_DIR repaired)

        set(repair_CODE
            "set(TARGET_NAME ${target_name})"
            "set(ORIGIN_FILE \"${BAZEL_OUTPUT_LIBRARY}\")"
            "set(PROJECT_VERSION ${PROJECT_VERSION})"
            "set(Python3_EXECUTABLE \"${Python3_EXECUTABLE}\")"
            "set(TARGET_SOURCE_DIR \"${CMAKE_SOURCE_DIR}\")"
            "set(TARGET_CURRENT_SOURCE_DIR \"${CMAKE_CURRENT_SOURCE_DIR}\")"
            "set(TARGET_CURRENT_BINARY_DIR \"${CMAKE_CURRENT_BINARY_DIR}\")"
            "set(CMAKE_BUILD_TYPE ${CMAKE_BUILD_TYPE})"
            "set(REPAIR_DIR ${REPAIR_DIR})"
            "set(PACKAGE_DATA \"${target_name}${CMAKE_SHARED_LIBRARY_SUFFIX}\")"
            "unset(DLL_DIRECTORIES)"
        )

        if (VCPKG_INSTALLED_DIR)
            if (CMAKE_BUILD_TYPE STREQUAL "Debug")
                list(APPEND repair_CODE "list(APPEND DLL_DIRECTORIES \"${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/debug/bin\")")
            endif()

            list(APPEND repair_CODE "list(APPEND DLL_DIRECTORIES \"${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/bin\")")
        endif()

        foreach(flag IN ITEMS ignore_existing ignore_in_wheel no_mangle_all with_mangle strip custom_patch include_symbols include_imports)
            if (DELVEWHEEL_${flag})
                list(APPEND repair_CODE "set(DELVEWHEEL_${flag} ON)")
            endif()
        endforeach()

        foreach(option IN ITEMS add_path include add_dll exclude no_dll wheel_dir no_mangle lib_sdir namespace_pkg)
            foreach(value IN LISTS DELVEWHEEL_${option})
                list(APPEND repair_CODE "list(APPEND DELVEWHEEL_${option} \"${value}\")")
            endforeach()
        endforeach()

        list(JOIN repair_CODE "\n  " repair_CODE)
        install(CODE "${repair_CODE}")

        install(SCRIPT "delvewheel_repair.cmake")
    elseif (UNIX)
        set(REPAIR_DIR repaired)

        set(repair_CODE
            "set(TARGET_NAME ${target_name})"
            "set(ORIGIN_FILE \"${BAZEL_OUTPUT_LIBRARY}\")"
            "set(PROJECT_VERSION ${PROJECT_VERSION})"
            "set(Python3_EXECUTABLE \"${Python3_EXECUTABLE}\")"
            "set(TARGET_SOURCE_DIR \"${CMAKE_SOURCE_DIR}\")"
            "set(TARGET_CURRENT_SOURCE_DIR \"${CMAKE_CURRENT_SOURCE_DIR}\")"
            "set(TARGET_CURRENT_BINARY_DIR \"${CMAKE_CURRENT_BINARY_DIR}\")"
            "set(CMAKE_BUILD_TYPE ${CMAKE_BUILD_TYPE})"
            "set(REPAIR_DIR ${REPAIR_DIR})"
            "set(PACKAGE_DATA \"${target_name}${CMAKE_SHARED_LIBRARY_SUFFIX}\")"
        )

        foreach(flag IN ITEMS strip only_plat disable_isa_ext_check)
            if (AUDITWHEEL_${flag})
                list(APPEND repair_CODE "set(AUDITWHEEL_${flag} ON)")
            endif()
        endforeach()

        foreach(option IN ITEMS plat exclude)
            foreach(value IN LISTS AUDITWHEEL_${option})
                list(APPEND repair_CODE "list(APPEND AUDITWHEEL_${option} \"${value}\")")
            endforeach()
        endforeach()

        list(JOIN repair_CODE "\n  " repair_CODE)
        install(CODE "${repair_CODE}")

        install(SCRIPT "auditwheel_repair.cmake")
    endif()
endif()

# ===============
# Mediapipe Lua Test
# ===============
if (WITH_LUA_ROCKS)
    return()
endif()

# Needed python packages
pip_install(absl-py mediapipe>=0.10.35 numpy opencv-python)

include(CTest)
enable_testing()

add_test(
    NAME test_build
    COMMAND "${LUA_INTERPRETER}" "samples/01-face_detection.lua"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
)

set_tests_properties(test_build PROPERTIES DEPENDS ${target_name})

if(EXISTS "${CMAKE_INSTALL_PREFIX}/bin/lua${Lua_SUFFIX}${CMAKE_EXECUTABLE_SUFFIX}")
    add_test(
        NAME test_install
        COMMAND "${CMAKE_INSTALL_PREFIX}/bin/lua${Lua_SUFFIX}${CMAKE_EXECUTABLE_SUFFIX}" "samples/01-face_detection.lua"
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    )

    set_tests_properties(test_install PROPERTIES DEPENDS ${target_name})
endif()

# Pack
include(CPack)
set(CPACK_PROJECT_NAME ${target_name})
set(CPACK_PROJECT_VERSION ${LUA_MODULE_VERSION})
