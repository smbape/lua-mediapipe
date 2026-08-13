cmake_minimum_required(VERSION 3.25)

project(opencv_hdr_parser)

set(OpenCV_HDR_PARSER_URL_HASH_SHA256_4130 6ddf96f573249e276734f8bcb72eab07d6f04be05d2e64f3af85bd9dcc49c936)

# Tell cmake that we will need hdr_parser.
include(FetchContent)
FetchContent_Populate(opencv_hdr_parser
    URL               https://raw.githubusercontent.com/opencv/opencv/refs/tags/${OpenCV_VERSION}/modules/python/src2/hdr_parser.py
    URL_HASH          SHA256=${OpenCV_HDR_PARSER_URL_HASH_SHA256_${OpenCV_DLLVERSION}}
    DOWNLOAD_NO_EXTRACT TRUE
    DOWNLOAD_DIR      "${CMAKE_BINARY_DIR}/opencv/opencv-src/modules/python/src2"
    SOURCE_DIR        "${CMAKE_BINARY_DIR}/opencv/opencv-src"
    PATCH_COMMAND     "${PATCH_EXECUTABLE}" -p1 -d "<SOURCE_DIR>" -i "${CMAKE_SOURCE_DIR}/patches/001-hdr_parser-src.patch"
)
