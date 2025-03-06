cmake_minimum_required(VERSION 3.25)

set(mediapipe_INSTALL_DIR "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}/mediapipe_lua")

function(install_file src dst)
    file(SHA256 "${src}" src_hash)

    set(dst_hash)
    if (EXISTS "${dst}")
        file(SHA256 "${dst}" dst_hash)
    endif()

    if (EXISTS "${dst}" AND src_hash STREQUAL dst_hash)
        message(STATUS "Up-to-date: ${dst}")
    else()
        message(STATUS "Installing: ${dst}")

        cmake_path(GET dst PARENT_PATH dst_parent)
        file(MAKE_DIRECTORY "${dst_parent}")

        file(COPY_FILE "${src}" "${dst}")
        file(INSTALL "${src}" DESTINATION "${dst_parent}")

        cmake_path(GET src FILENAME src_filename)
        cmake_path(GET dst FILENAME dst_filename)
        if (NOT src_filename STREQUAL dst_filename)
            file(RENAME "${dst_parent}/${src_filename}" "${dst_parent}/${dst_filename}")
        endif()
    endif()
endfunction()

cmake_path(RELATIVE_PATH mediapipe_BINARY_DIR BASE_DIRECTORY "${CMAKE_BINARY_DIR}" OUTPUT_VARIABLE mediapipe_RELATIVE_BINARY_DIR)
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
