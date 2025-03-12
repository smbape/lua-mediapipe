# Build curl from source with some dependencies

# search for __declspec(dllimport) to find the SYMBOL to define to avoid LINK : warning LNK4217
# search install( to avoid installation
# search for Find<Library> to know what cmake variables must be set
# search for add_library( to know what are the corresponding libraries
# set_target_properties(<Library> PROPERTIES EXCLUDE_FROM_ALL TRUE) to avoid befault building of the target

# ================================================================
# Tell cmake that we will need zlib.
# ================================================================
set(ZLIB_VERSION 1.3.1)
set(ZLIB_VERSION_SHA256 38ef96b8dfe510d42707d9c781877914792541133e1870841463bfa73f883e32)

include(FetchContent)
FetchContent_Populate(zlib
    URL           https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/zlib-${ZLIB_VERSION}.tar.xz
    URL_HASH      SHA256=${ZLIB_VERSION_SHA256}
    PATCH_COMMAND "${PATCH_EXECUTABLE}" -p 1 -d "<SOURCE_DIR>" -i "${CMAKE_SOURCE_DIR}/patches/001-zlib-src.patch"
)

set(SKIP_INSTALL_ALL ON)

# Hack to ensure that zlib is built with BUILD_SHARED_LIBS OFF
set(BUILD_SHARED_LIBS_BACKUP ${BUILD_SHARED_LIBS})
set(BUILD_SHARED_LIBS OFF)
add_subdirectory("${zlib_SOURCE_DIR}" "${zlib_BINARY_DIR}")
set_property(DIRECTORY "${zlib_SOURCE_DIR}" PROPERTY EXCLUDE_FROM_ALL TRUE)
set(BUILD_SHARED_LIBS ${BUILD_SHARED_LIBS_BACKUP}) 


add_library(ZLIB::ZLIB ALIAS zlibstatic)
set(ZLIB_LIBRARY ZLIB::ZLIB)
set(ZLIB_INCLUDE_DIR "${zlib_SOURCE_DIR}")
# ================================================================


# ================================================================
# Tell cmake that we will need zstd.
# ================================================================
set(ZSTD_VERSION 1.5.7)
set(ZSTD_VERSION_SHA256 eb33e51f49a15e023950cd7825ca74a4a2b43db8354825ac24fc1b7ee09e6fa3)

include(FetchContent)
FetchContent_Populate(zstd
    URL         https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/zstd-${ZSTD_VERSION}.tar.gz
    URL_HASH    SHA256=${ZSTD_VERSION_SHA256}
)

# Hack to ensure that zstd is built with BUILD_SHARED_LIBS OFF
set(BUILD_SHARED_LIBS_BACKUP ${BUILD_SHARED_LIBS})
set(BUILD_SHARED_LIBS OFF)
set(ZSTD_BUILD_SHARED OFF)
add_subdirectory("${zstd_SOURCE_DIR}/build/cmake" "${zstd_BINARY_DIR}")
set_property(DIRECTORY "${zstd_SOURCE_DIR}/build/cmake" PROPERTY EXCLUDE_FROM_ALL TRUE)
set(BUILD_SHARED_LIBS ${BUILD_SHARED_LIBS_BACKUP}) 

set(ZSTD_FOUND TRUE)
set(ZSTD_LIBRARY libzstd)
set(ZSTD_LIBRARIES ${ZSTD_LIBRARY})
# libzstd is a cmake target, no need to ZSTD_INCLUDE_DIR
# set(ZSTD_INCLUDE_DIR "${zstd_SOURCE_DIR}/lib")
# ================================================================


# ================================================================
# Tell cmake that we will need brotli.
# ================================================================
set(BROTLI_VERSION 1.1.0)
set(BROTLI_VERSION_SHA256 e720a6ca29428b803f4ad165371771f5398faba397edf6778837a18599ea13ff)

include(FetchContent)
FetchContent_Populate(brotli
    URL         https://github.com/google/brotli/archive/refs/tags/v${BROTLI_VERSION}.tar.gz
    URL_HASH    SHA256=${BROTLI_VERSION_SHA256}
)

set(BROTLI_DISABLE_TESTS ON)

# Hack to ensure that brotli is built with BUILD_SHARED_LIBS OFF
set(BUILD_SHARED_LIBS_BACKUP ${BUILD_SHARED_LIBS})
set(BUILD_SHARED_LIBS OFF)
add_subdirectory("${brotli_SOURCE_DIR}" "${brotli_BINARY_DIR}")
set_property(DIRECTORY "${brotli_SOURCE_DIR}" PROPERTY EXCLUDE_FROM_ALL TRUE)
set(BUILD_SHARED_LIBS ${BUILD_SHARED_LIBS_BACKUP})

# Fix common not in include directories
# Bazel is strict about it
target_include_directories(brotlidec PRIVATE "${brotli_SOURCE_DIR}/c/common")
target_include_directories(brotlienc PRIVATE "${brotli_SOURCE_DIR}/c/common")

# For curl
unset(BROTLI_INCLUDE_DIRS)
set(BROTLI_FOUND TRUE)
set(BROTLIDEC_FOUND TRUE)
set(BROTLICOMMON_LIBRARY brotlicommon)
set(BROTLIDEC_LIBRARY brotlidec)
set(BROTLI_LIBRARIES ${BROTLIDEC_LIBRARY} ${BROTLICOMMON_LIBRARY})
# brotlicommon is a cmake target, no need to BROTLI_INCLUDE_DIR
# set(BROTLI_INCLUDE_DIR "${brotli_SOURCE_DIR}/c/include")

# For nghttp2
set(LIBBROTLIENC_FOUND TRUE)
set(LIBBROTLIENC_VERSION ${BROTLI_VERSION})
set(LIBBROTLIENC_FOUND TRUE)
set(LIBBROTLIENC_LIBRARY brotlienc)
set(LIBBROTLIENC_VERSION ${BROTLI_VERSION})
set(LIBBROTLIENC_LIBRARIES ${LIBBROTLIENC_LIBRARY})
# brotlienc is a cmake target, no need to LIBBROTLIENC_INCLUDE_DIR
# set(LIBBROTLIENC_INCLUDE_DIR "${brotli_SOURCE_DIR}/c/include")

set(LIBBROTLIDEC_FOUND TRUE)
set(LIBBROTLIDEC_VERSION ${BROTLI_VERSION})
set(LIBBROTLIDEC_FOUND TRUE)
set(LIBBROTLIDEC_LIBRARY brotlienc)
set(LIBBROTLIDEC_VERSION ${BROTLI_VERSION})
set(LIBBROTLIDEC_LIBRARIES ${LIBBROTLIDEC_LIBRARY})
# brotlienc is a cmake target, no need to LIBBROTLIDEC_INCLUDE_DIR
# set(LIBBROTLIDEC_INCLUDE_DIR "${brotli_SOURCE_DIR}/c/include")

# ================================================================


# ================================================================
# Tell cmake that we will need nghttp2.
# ================================================================
set(NGHTTP2_VERSION 1.65.0)
set(NGHTTP2_VERSION_SHA256 f1b9df5f02e9942b31247e3d415483553bc4ac501c87aa39340b6d19c92a9331)

include(FetchContent)
FetchContent_Populate(nghttp2
    URL           https://github.com/nghttp2/nghttp2/releases/download/v${NGHTTP2_VERSION}/nghttp2-${NGHTTP2_VERSION}.tar.xz
    URL_HASH      SHA256=${NGHTTP2_VERSION_SHA256}
    PATCH_COMMAND "${PATCH_EXECUTABLE}" -p 1 -d "<SOURCE_DIR>" -i "${CMAKE_SOURCE_DIR}/patches/001-nghttp2-src.patch"
)

# Hack to ensure that nghttp2 is built with BUILD_SHARED_LIBS OFF
set(BUILD_SHARED_LIBS_BACKUP ${BUILD_SHARED_LIBS})
set(BUILD_SHARED_LIBS OFF)
set(BUILD_STATIC_LIBS ON)
add_subdirectory("${nghttp2_SOURCE_DIR}" "${nghttp2_BINARY_DIR}")
set_property(DIRECTORY "${nghttp2_SOURCE_DIR}" PROPERTY EXCLUDE_FROM_ALL TRUE)
set(BUILD_SHARED_LIBS ${BUILD_SHARED_LIBS_BACKUP}) 

get_target_property(nghttp2_ALIASED_TARGET nghttp2::nghttp2 ALIASED_TARGET)
unset(nghttp2_ALIASED_TARGET)

set(NGHTTP2_FOUND TRUE)
set(NGHTTP2_LIBRARY nghttp2::nghttp2)
set(NGHTTP2_LIBRARIES ${NGHTTP2_LIBRARY})
# nghttp2::nghttp2 is a cmake target, no need to NGHTTP2_INCLUDE_DIR
# set(NGHTTP2_INCLUDE_DIR "${nghttp2_SOURCE_DIR}/lib/includes")
# ================================================================


# ================================================================
# Tell cmake that we will need curl.
# ================================================================
set(CURL_VERSION 8.12.1)
set(CURL_VERSION_SHA256 0341f1ed97a26c811abaebd37d62b833956792b7607ea3f15d001613c76de202)
string(REPLACE "." "_" CURL_VERSION_UNDERSCORE ${CURL_VERSION})

include(FetchContent)
FetchContent_Populate(curl
    URL           https://curl.se/download/curl-${CURL_VERSION}.tar.xz
                  https://github.com/curl/curl/releases/download/curl-${CURL_VERSION_UNDERSCORE}/curl-${CURL_VERSION}.tar.xz
    URL_HASH      SHA256=${CURL_VERSION_SHA256}
    PATCH_COMMAND "${PATCH_EXECUTABLE}" -p 1 -d "<SOURCE_DIR>" -i "${CMAKE_SOURCE_DIR}/patches/001-curl-src.patch"
)

# https://gitlab.kitware.com/cmake/cmake/-/blob/v3.31.6/Utilities/cmcurl/CMakeLists.txt

# Unneeded options
set(BUILD_CURL_EXE OFF)
set(BUILD_EXAMPLES OFF)
set(BUILD_LIBCURL_DOCS OFF)
set(BUILD_MISC_DOCS OFF)
set(BUILD_TESTING OFF)
set(CURL_DISABLE_INSTALL ON)
set(CURL_DISABLE_LDAP ON)
set(CURL_ENABLE_EXPORT_TARGET OFF)
set(CURL_USE_LIBPSL OFF)
set(CURL_USE_LIBSSH2 OFF)
set(USE_LIBIDN2 OFF)
set(SHARE_LIB_OBJECT OFF)

if (WIN32)
    set(CURL_USE_SCHANNEL ON)
endif()

# Hack to ensure that curl is built with BUILD_SHARED_LIBS OFF
set(BUILD_SHARED_LIBS_BACKUP ${BUILD_SHARED_LIBS})
set(BUILD_SHARED_LIBS OFF)
set(BUILD_STATIC_LIBS ON)
add_subdirectory("${curl_SOURCE_DIR}" "${curl_BINARY_DIR}")
set_property(DIRECTORY "${curl_SOURCE_DIR}" PROPERTY EXCLUDE_FROM_ALL TRUE)
set(BUILD_SHARED_LIBS ${BUILD_SHARED_LIBS_BACKUP}) 

# LINK : warning LNK4217: symbol 'nghttp2_version' defined in 'nghttp2.lo.lib(nghttp2_version.obj)' is imported by 'libcurl.lo.lib(version.obj)' in function 'curl_version_info'
get_target_property(libcurl_ALIASED_TARGET libcurl ALIASED_TARGET)
target_compile_definitions(${libcurl_ALIASED_TARGET} PRIVATE BUILDING_NGHTTP2)
unset(libcurl_ALIASED_TARGET)
# ================================================================
