cmake_minimum_required(VERSION 3.25)

set(mediapipe_INSTALL_DIR "${CMAKE_INSTALL_PREFIX}/${LIBRAY_DESTINATION}/mediapipe_lua")

function(install_file src dst)
    cmake_path(GET dst PARENT_PATH dst_parent)
    cmake_path(GET dst FILENAME dst_filename)

    file(INSTALL
        TYPE FILE
        FILES "${src}"
        DESTINATION "${dst_parent}"
        RENAME "${dst_filename}"
    )
endfunction()

cmake_path(NORMAL_PATH mediapipe_RELATIVE_BINARY_DIR)
if (mediapipe_RELATIVE_BINARY_DIR STREQUAL ".")
    set(mediapipe_RELATIVE_BINARY_DIR)
else()
    set(mediapipe_RELATIVE_BINARY_DIR "${mediapipe_RELATIVE_BINARY_DIR}/")
endif()

file(GLOB_RECURSE binarypb_FILES "${mediapipe_RELATIVE_BINARY_DIR}*.binarypb")

foreach(item IN LISTS binarypb_FILES)
    set(src_file "${item}")

    cmake_path(RELATIVE_PATH src_file BASE_DIRECTORY "${mediapipe_BINARY_DIR}" OUTPUT_VARIABLE dst_file)
    set(dst_file "${mediapipe_INSTALL_DIR}/${dst_file}")

    install_file("${src_file}" "${dst_file}")
endforeach()

set(source_FILES
    "mediapipe/modules/objectron/object_detection_oidv4_labelmap.txt"
    "mediapipe/modules/hand_landmark/handedness.txt"
)

foreach(item IN LISTS source_FILES)
    set(src_file "${mediapipe_SOURCE_DIR}/${item}")
    set(dst_file "${mediapipe_INSTALL_DIR}/${item}")
    install_file("${src_file}" "${dst_file}")
endforeach()
