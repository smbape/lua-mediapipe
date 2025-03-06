cmake_minimum_required(VERSION 3.25)

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
  ${relative_SOURCE_DIR}scripts/new_version.lua
  ${relative_SOURCE_DIR}scripts/pack.js
  ${relative_SOURCE_DIR}scripts/tasks.sh
  ${relative_SOURCE_DIR}BUILD
)

foreach(item ${files_to_change})
  vcpkg_regex_replace_string("${item}" "(/lua-mediapipe/releases/download/v|/lua-mediapipe/tree/v)[0-9]+\\.[0-9]+\\.[0-9]+" "\\1${PROJECT_VERSION}")
  vcpkg_regex_replace_string("${item}" "(/google-ai-edge/mediapipe/archive/refs/tags/v|mediapipe-|MEDIAIPIPE_VERSION:-|${target_name} )[0-9]+(\\.[0-9]+)+" "\\1${Mediapipe_VERSION}")
  vcpkg_regex_replace_string("${item}" "MEDIAPIPE_VERSION = \"[0-9]+(\\.[0-9]+)+\"" "MEDIAIPIPE_VERSION = \"${Mediapipe_VERSION}\"")
  vcpkg_regex_replace_string("${item}" "/v[0-9]+(\\.[0-9]+)+/mediapipe/" "/v${Mediapipe_VERSION}/mediapipe/")
  vcpkg_regex_replace_string("${item}" "(--branch v)[0-9]+\\.[0-9]+\\.[0-9]+( https://github.com/smbape/lua-mediapipe)" "\\1${PROJECT_VERSION}\\2")
  vcpkg_regex_replace_string("${item}" "(opencv-|/opencv/opencv/blob/|opencv_lua |OPENCV_VERSION:-)[0-9]+\\.[0-9]+\\.[0-9]+" "\\1${OpenCV_VERSION}")

  # Force LF EOL
  configure_file(${item} ${item} @ONLY NEWLINE_STYLE LF)
endforeach()

set(EXECUTABLE_OUTPUT_PATH "${CMAKE_BINARY_DIR}/bin" CACHE PATH "Output directory for applications")
set(LIBRARY_OUTPUT_PATH "${CMAKE_BINARY_DIR}/lib" CACHE PATH "Output directory for libraries")

if (WIN32)
  # Avoid long paths on windows
  # https://bazel.build/remote/output-directories#layout
  set(OUTPUT_USER_ROOT "C:/_bazel_" CACHE PATH "Bazel output user root")
endif()

if (WIN32)
  option(XNN_DISABLE_AVX "Disable XNN AVX" OFF)
else()
  option(XNN_DISABLE_AVX "Disable XNN AVX" ON)
endif()

find_program(BAZEL_EXECUTABLE
  NAMES bazel
  DOC 
  REQUIRED "Bazel executable"
)

option(MEDIAPIPE_DISABLE_GPU "Disable GPU support" ON)

set(BAZEL_BUILD "${BAZEL_EXECUTABLE}")

if (DEFINED OUTPUT_USER_ROOT)
  list(APPEND BAZEL_BUILD "--output_user_root=${OUTPUT_USER_ROOT}")
endif()

if (DEFINED OUTPUT_BASE)
  list(APPEND BAZEL_BUILD "--output_base=${OUTPUT_BASE}")
endif()

list(APPEND BAZEL_BUILD
  build -c ${COMPILATION_MODE}
  --strip=never
  --action_env "PYTHON_BIN_PATH=${PYTHON_BIN_PATH}"
  --verbose_failures
  # --sandbox_debug

  # https://github.com/bazelbuild/bazel/issues/8444#issuecomment-513204396
  # --spawn_strategy=local
)

if (MEDIAPIPE_DISABLE_GPU)
  list(APPEND BAZEL_BUILD --define MEDIAPIPE_DISABLE_GPU=1)
endif()

if (ENABLE_ODML_CONVERTER)
  list(APPEND BAZEL_BUILD --define ENABLE_ODML_CONVERTER=1)
endif()

if (XNN_DISABLE_AVX)
  list(APPEND BAZEL_BUILD --define xnn_enable_avxvnni=false --define xnn_enable_avx512amx=false)
endif()

# list(APPEND BAZEL_BUILD --keep_going)
list(APPEND BAZEL_BUILD 
    --define LUA_MODULE_NAME=${target_name}
    --define LUA_MODULE_VERSION=${LUA_MODULE_VERSION}
    --define LUA_MODULE_LIB_NAME=Mediapipe
    --define LUA_MODULE_LIB_VERSION=${Mediapipe_VERSION}
)

if(
  ${VIRTUAL_ENV_created} OR
  (NOT EXISTS "${mediapipe_BINARY_DIR}/external/com_google_protobuf/any_proto-descriptor-set.proto.bin") OR
  (NOT EXISTS "${mediapipe_SOURCE_DIR}/bazel-mediapipe-src/external/com_google_protobuf/src")
)
  execute_process(
    COMMAND ${BAZEL_BUILD} mediapipe/python:builtin_calculators
    WORKING_DIRECTORY "${mediapipe_SOURCE_DIR}"
    COMMAND_ECHO STDERR
    COMMAND_ERROR_IS_FATAL ANY
  )
endif()

option(SKIP_bindings_generation "Skip binding files generation" OFF)

if (NOT SKIP_bindings_generation)
  set(src_gen_cmd "${NODE_EXECUTABLE}" --unhandled-rejections=strict --trace-uncaught --trace-warnings generator/index.js)

  if (ENABLE_ODML_CONVERTER)
    list(APPEND src_gen_cmd -DENABLE_ODML_CONVERTER)
  endif()

  set(ENV{CMAKE_BINARY_DIR} "${CMAKE_BINARY_DIR}")
  set(ENV{Python3_EXECUTABLE} "${Python3_EXECUTABLE}")
  execute_process(
    COMMAND ${src_gen_cmd}
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    COMMAND_ECHO STDERR
    COMMAND_ERROR_IS_FATAL ANY
  )
endif()

file(GLOB_RECURSE project_rules_files
  "${relative_SOURCE_DIR}rules_impl/*"
  "${relative_SOURCE_DIR}scripts/configure_bazel.js"
)

file(GLOB_RECURSE project_source_headers
  "${relative_SOURCE_DIR}src/*.h*"
  "${relative_SOURCE_DIR}generated/*.h*"
)

file(GLOB_RECURSE project_source_files
  "${relative_SOURCE_DIR}src/*.c"
  "${relative_SOURCE_DIR}src/*.cc"
  "${relative_SOURCE_DIR}src/*.cpp"
  "${relative_SOURCE_DIR}src/*.cxx"
  "${relative_SOURCE_DIR}generated/*.c"
  "${relative_SOURCE_DIR}generated/*.cc"
  "${relative_SOURCE_DIR}generated/*.cpp"
  "${relative_SOURCE_DIR}generated/*.cxx"
)

set(BAZEL_OUTPUT_NAME "${CMAKE_SHARED_LIBRARY_PREFIX}${target_name}")

set(BAZEL_OUPUT_LIBRARY "${mediapipe_BINARY_DIR}/${MEDIAPIPE_ADDON_PACKAGE}/${BAZEL_OUTPUT_NAME}")

if (WIN32 OR BUILD_SHARED_LIBS)
  set(BAZEL_OUPUT_LIBRARY "${BAZEL_OUPUT_LIBRARY}${CMAKE_SHARED_LIBRARY_SUFFIX}")
  set(OUPUT_LIBRARY_NAME "${target_name}${CMAKE_SHARED_LIBRARY_SUFFIX}")
else()
  set(BAZEL_OUPUT_LIBRARY "${BAZEL_OUPUT_LIBRARY}${CMAKE_STATIC_LIBRARY_SUFFIX}")
  set(OUPUT_LIBRARY_NAME "${target_name}${CMAKE_STATIC_LIBRARY_SUFFIX}")
endif()

add_custom_command(OUTPUT "${BAZEL_OUPUT_LIBRARY}"
  COMMAND           echo ${BAZEL_BUILD} ${MEDIAPIPE_ADDON_PACKAGE}:lib
  COMMAND           ${BAZEL_BUILD} ${MEDIAPIPE_ADDON_PACKAGE}:lib
  WORKING_DIRECTORY "${mediapipe_SOURCE_DIR}"
  DEPENDS           ${project_source_files} ${project_rules_files}
  VERBATIM
  USES_TERMINAL
)
add_custom_target(${target_name}_lib DEPENDS "${BAZEL_OUPUT_LIBRARY}")

add_custom_target(${target_name} ALL DEPENDS ${target_name}_lib)

if (MSVC AND NOT (CMAKE_GENERATOR STREQUAL "Ninja"))
  set(EXECUTABLE_OUTPUT_PATH "${EXECUTABLE_OUTPUT_PATH}/${CMAKE_BUILD_TYPE}")
  set(LIBRARY_OUTPUT_PATH "${LIBRARY_OUTPUT_PATH}/${CMAKE_BUILD_TYPE}")
endif()

if (WIN32)
  set(TARGET_FILE "${EXECUTABLE_OUTPUT_PATH}/${OUPUT_LIBRARY_NAME}")

  add_custom_command(TARGET ${target_name} POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
      "${BAZEL_OUPUT_LIBRARY}"
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
  set(TARGET_FILE "${LIBRARY_OUTPUT_PATH}/${OUPUT_LIBRARY_NAME}")

  add_custom_command(TARGET ${target_name} POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
      "${BAZEL_OUPUT_LIBRARY}"
      "${TARGET_FILE}"

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
  install(FILES "${TARGET_FILE}" DESTINATION lib)
else()
  install(FILES "${TARGET_FILE}" DESTINATION "${CMAKE_INSTALL_LIBDIR}")
endif()

# TODO : remove rpath when installing on unix

if (WIN32)
  install(
    FILES "${LIBRARY_OUTPUT_PATH}/${target_name}${CMAKE_STATIC_LIBRARY_SUFFIX}"
    DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    RENAME "${BAZEL_OUTPUT_NAME}${CMAKE_STATIC_LIBRARY_SUFFIX}"
  )
endif()

if (WITH_LUA_ROCKS AND CMAKE_INSTALL_PREFIX)
  install(CODE "set(CMAKE_BINARY_DIR \"${CMAKE_BINARY_DIR}\")")
  install(CODE "set(CMAKE_CURRENT_BINARY_DIR \"${CMAKE_CURRENT_BINARY_DIR}\")")
  install(CODE "set(CMAKE_CURRENT_SOURCE_DIR \"${CMAKE_CURRENT_SOURCE_DIR}\")")
  install(CODE "set(CMAKE_INSTALL_LIBDIR \"lib\")")
  install(CODE "set(CMAKE_INSTALL_PREFIX \"${CMAKE_INSTALL_PREFIX}\")")
  install(CODE "set(CMAKE_SOURCE_DIR \"${CMAKE_SOURCE_DIR}\")")

  install(CODE "set(mediapipe_SOURCE_DIR \"${mediapipe_SOURCE_DIR}\")")
  install(CODE "set(mediapipe_BINARY_DIR \"${mediapipe_BINARY_DIR}\")")
  install(SCRIPT "install_generated_files.cmake")

  if (UNIX)
    # Add any variables you need during post install.
    install(CODE "set(PROJECT_VERSION \"${PROJECT_VERSION}\")")
    install(CODE "set(Python3_EXECUTABLE \"${Python3_EXECUTABLE}\")")
    install(CODE "set(TARGET_FILE \"${TARGET_FILE}\")")
    install(CODE "set(target_name \"${target_name}\")")

    # CMake will execute this last in the build.
    # Install the script that does the post install work.
    install(SCRIPT "auditwheel_repair.cmake")
  endif()
endif()

# ===============
# Mediapipe Lua Test
# ===============
include(CTest)
enable_testing()

add_test(
  NAME test_build
  COMMAND "${LUA_INTERPRETER}" "samples/01-face_detection.lua"
  WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
)

set_tests_properties(test_build PROPERTIES DEPENDS ${target_name})

if(EXISTS "${CMAKE_INSTALL_PREFIX}/bin/lua${LUA_SUFFIX}${CMAKE_EXECUTABLE_SUFFIX}")
  add_test(
    NAME test_install
    COMMAND "${CMAKE_INSTALL_PREFIX}/bin/lua${LUA_SUFFIX}${CMAKE_EXECUTABLE_SUFFIX}" "samples/01-face_detection.lua"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
  )

  set_tests_properties(test_install PROPERTIES DEPENDS ${target_name})
endif()

# Pack
include(CPack)
set(CPACK_PROJECT_NAME ${target_name})
set(CPACK_PROJECT_VERSION ${LUA_MODULE_VERSION})

include(../cmake/get_temp_dir.cmake)
get_temp_dir(TEMPDIR)

if (TEMPDIR)
  if(WIN32)
    set(SILENT_OUT 2> NUL || type NUL > NUL)
  else()
    set(SILENT_OUT 2> /dev/null || true > /dev/null)
  endif()
  set(mediapipe_SOLUTIONS_DIR "${mediapipe_SOURCE_DIR}/mediapipe/python/solutions")

  set(item_target test_on_video_fullasl_hand_full_npz)
  set(item_test_data "${CMAKE_SOURCE_DIR}/test/solutions/testdata")
  set(item_output "${item_test_data}/test_on_video_full_asl_hand.full.yml")

  include(ExternalProject)
  ExternalProject_Add(
      asl_hand_25fps_mp4
      URL https://github.com/tensorflow/tfjs-models/raw/master/hand-pose-detection/test_data/asl_hand.25fps.mp4
      URL_HASH SHA256=57c10fb1eb76639edf43e9675213dcc495c51851e32a3592cacaa9437be4f37e
      DOWNLOAD_NO_EXTRACT TRUE
      DOWNLOAD_DIR      "${mediapipe_SOLUTIONS_DIR}/testdata"
      SOURCE_DIR        "${mediapipe_SOLUTIONS_DIR}/testdata"
      CONFIGURE_COMMAND ""
      BUILD_COMMAND     ""
      INSTALL_COMMAND   "${CMAKE_COMMAND}" -E copy_if_different "<DOWNLOAD_DIR>/asl_hand.25fps.mp4" "${item_test_data}/asl_hand.25fps.mp4"
  )

  add_custom_command(OUTPUT "${item_output}"
    COMMAND "${Python3_EXECUTABLE}" hands_test.py -- -k test_on_video ${SILENT_OUT}
    COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/test/solutions/npz_convert.py" "${TEMPDIR}/test_on_video_fullasl_hand.full.npz" -o "${item_output}"
    DEPENDS ${target_name}_lib asl_hand_25fps_mp4
    WORKING_DIRECTORY "${mediapipe_SOLUTIONS_DIR}"
    VERBATIM
  )
  add_custom_target(${item_target} DEPENDS "${item_output}")

  add_dependencies(${target_name} ${item_target})

  set(item_target test_on_video_fullpose_squats_npz)
  set(item_test_data "${CMAKE_SOURCE_DIR}/test/solutions/testdata")
  set(item_output "${item_test_data}/test_on_video_full_pose_squats.full.yml")

  include(ExternalProject)
  ExternalProject_Add(
      pose_squats_mp4
      URL https://github.com/tensorflow/tfjs-models/raw/master/pose-detection/test_data/pose_squats.mp4
      URL_HASH SHA256=ea9151e447b301985d5d65666551ef863b369a2e0f3a71ddd58abef2e722f96a
      DOWNLOAD_NO_EXTRACT TRUE
      DOWNLOAD_DIR      "${mediapipe_SOLUTIONS_DIR}/testdata"
      SOURCE_DIR        "${mediapipe_SOLUTIONS_DIR}/testdata"
      CONFIGURE_COMMAND ""
      BUILD_COMMAND     ""
      INSTALL_COMMAND   "${CMAKE_COMMAND}" -E copy_if_different "<DOWNLOAD_DIR>/pose_squats.mp4" "${item_test_data}/pose_squats.mp4"
  )

  add_custom_command(OUTPUT "${item_output}"
    COMMAND "${Python3_EXECUTABLE}" pose_test.py -- -k test_on_video ${SILENT_OUT}
    COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/test/solutions/npz_convert.py" "${TEMPDIR}/test_on_video_fullpose_squats.full.npz" -o "${item_output}"
    DEPENDS ${target_name}_lib pose_squats_mp4
    WORKING_DIRECTORY "${mediapipe_SOLUTIONS_DIR}"
    VERBATIM
  )
  add_custom_target(${item_target} DEPENDS "${item_output}")

  add_dependencies(${target_name} ${item_target})

  unset(item_output)
  unset(item_target)
endif()
