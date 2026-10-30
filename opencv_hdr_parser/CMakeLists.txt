cmake_minimum_required(VERSION 3.25)

project(opencv_hdr_parser)

set(OpenCV_HDR_PARSER_URL_HASH_SHA256_500 619cfc4e00987a905e06e11e780b963d90b3b0b86d41a8278a9b3a9d81780702)

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
