cmake_minimum_required(VERSION 3.25)

project(opencv_hdr_parser)

set(OpenCV_HDR_PARSER_URL_HASH_SHA256_4100 d221f9e14222ce73f9e3f01ddc0679e34b2662138e8fd64400f7e8f7d61e7fcc)

# Tell cmake that we will need mediapipe.
include(FetchContent)
FetchContent_Populate(opencv_hdr_parser
  URL               https://raw.githubusercontent.com/opencv/opencv/refs/tags/${OpenCV_VERSION}/modules/python/src2/hdr_parser.py
  URL_HASH          SHA256=${OpenCV_HDR_PARSER_URL_HASH_SHA256_${OpenCV_DLLVERSION}}
  DOWNLOAD_NO_EXTRACT TRUE
  DOWNLOAD_DIR      "${CMAKE_BINARY_DIR}/opencv/opencv-src/modules/python/src2"
  SOURCE_DIR        "${CMAKE_BINARY_DIR}/opencv/opencv-src"
  PATCH_COMMAND     "${PATCH_EXECUTABLE}" -p 1 -d "<SOURCE_DIR>" -i "${CMAKE_SOURCE_DIR}/patches/001-hdr_parser-src.patch"
)
