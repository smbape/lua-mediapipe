cmake_minimum_required(VERSION 3.25)

cmake_path(GET ORIGIN_FILE PARENT_PATH dirname_ORGIN_FILE)
cmake_path(GET TARGET_FILE PARENT_PATH dirname_TARGET_FILE)
get_filename_component(SONAME "${TARGET_FILE}" NAME)

file(COPY_FILE "${ORIGIN_FILE}" "${TARGET_FILE}")
file(CHMOD "${TARGET_FILE}" FILE_PERMISSIONS
    OWNER_READ OWNER_WRITE OWNER_EXECUTE
    GROUP_READ GROUP_EXECUTE
    WORLD_READ WORLD_EXECUTE
)

execute_process(
    COMMAND patchelf --print-rpath "${ORIGIN_FILE}"
    OUTPUT_VARIABLE library_RPATH
    OUTPUT_STRIP_TRAILING_WHITESPACE
    COMMAND_ERROR_IS_FATAL ANY
)

string(REPLACE "$ORIGIN" "${dirname_ORGIN_FILE}" library_RPATH "${library_RPATH}")

string(REPLACE ":" ";" library_RPATH "${library_RPATH}")
set(library_RPATH_NEW)
foreach(path_var IN LISTS library_RPATH)
    cmake_path(NORMAL_PATH path_var)
    cmake_path(RELATIVE_PATH path_var BASE_DIRECTORY "${dirname_TARGET_FILE}")
    list(APPEND library_RPATH_NEW "$ORIGIN/${path_var}")
endforeach()
string(REPLACE ";" ":" library_RPATH_NEW "${library_RPATH_NEW}")

execute_process(
    COMMAND patchelf --force-rpath --set-rpath "${library_RPATH_NEW}" "${TARGET_FILE}"
    COMMAND_ECHO STDERR
    COMMAND_ERROR_IS_FATAL ANY
)
