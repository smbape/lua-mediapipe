if(POLICY CMP0174)
    cmake_policy(SET CMP0174 NEW) # CMake 3.31+: cmake_parse_arguments(PARSE_ARGV) always defines a variable for each keyword given in the arguments
endif()


function(split_target_property output_prefix the_target property)
    # PUBLIC and PRIVATE values
    get_target_property(values_PUBLIC_AND_PRIVATE ${the_target} ${property})
    if (NOT values_PUBLIC_AND_PRIVATE)
        unset(values_PUBLIC_AND_PRIVATE)
    else()
        # Keep build interface generatory only
        list(TRANSFORM values_PUBLIC_AND_PRIVATE REPLACE "^\\\$<BUILD_INTERFACE:([^>]+)>" "\\1")
        list(FILTER values_PUBLIC_AND_PRIVATE EXCLUDE REGEX "^\\\$<")
    endif()

    # PUBLIC and INTERFACE values
    get_target_property(values_PUBLIC_AND_INTERFACE ${the_target} INTERFACE_${property})
    if (NOT values_PUBLIC_AND_INTERFACE)
        unset(values_PUBLIC_AND_INTERFACE)
    else()
        # Keep build interface generatory only
        list(TRANSFORM values_PUBLIC_AND_INTERFACE REPLACE "^\\\$<BUILD_INTERFACE:([^>]+)>" "\\1")
        list(FILTER values_PUBLIC_AND_INTERFACE EXCLUDE REGEX "^\\\$<")
    endif()

    # https://stackoverflow.com/questions/59577966/how-can-i-list-the-private-public-and-interface-include-directories-of-a-target#answer-59577967
    # https://stackoverflow.com/questions/59578248/how-do-i-manipulate-cmake-lists-as-sets#answer-59578250

    # PUBLIC = ${property} ∩ INTERFACE_${property}
    list_intersection(values_PUBLIC values_PUBLIC_AND_PRIVATE values_PUBLIC_AND_INTERFACE)

    # PRIVATE = ${property} - INTERFACE_${property}
    set(values_PRIVATE ${values_PUBLIC_AND_PRIVATE})
    list(REMOVE_ITEM values_PRIVATE ${values_PUBLIC_AND_INTERFACE})

    # INTERFACE = INTERFACE_${property} - ${property}
    set(values_INTERFACE ${values_PUBLIC_AND_INTERFACE})
    list(REMOVE_ITEM values_INTERFACE ${values_PUBLIC})

    set(${output_prefix}_PUBLIC ${values_PUBLIC} PARENT_SCOPE)
    set(${output_prefix}_PRIVATE ${values_PRIVATE} PARENT_SCOPE)
    set(${output_prefix}_INTERFACE ${values_INTERFACE} PARENT_SCOPE)
endfunction()

function(ImportLibrary_Populate generated_targets_var)
    set(options
        LINKSHARED
        LINKSTATIC
        ALWAYSLINK
    )
    set(oneValueArgs
        TARGET
        IMPORTED_DEPS
        TARGET_DEPS
        SOURCES
        DEPS
        RULE
    )
    set(multiValueArgs)
    cmake_parse_arguments(PARSE_ARGV 1 library
        "${options}" "${oneValueArgs}" "${multiValueArgs}"
    )

    if (library_UNPARSED_ARGUMENTS)
        string(REPLACE ";" ", " library_UNPARSED_ARGUMENTS "${library_UNPARSED_ARGUMENTS}")
        message(FATAL_ERROR "Unknown arguments [${library_UNPARSED_ARGUMENTS}]")
    endif()

    foreach(keyword IN ITEMS OUTPUT_VARIABLE NAME PKGNAME)
        if (NOT library_${keyword})
            message(FATAL_ERROR "${keyword} argument is missing")
        endif()
    endforeach()

    foreach(arg IN LISTS options)
        if (library_${arg})
            set(library_${arg} ${arg})
        else()
            unset(library_${arg})
        endif()
    endforeach()


    if ((NOT TARGET "${library_TARGET}") AND (library_TARGET MATCHES "^[_a-zA-Z0-9]+$"))
        string(TOUPPER "${library_TARGET}" library_TARGET_prefix)
        find_package(PkgConfig QUIET)
        pkg_check_modules(${library_TARGET_prefix} "lib${library_TARGET}" IMPORTED_TARGET)
        if(${library_TARGET_prefix}_FOUND)
            set(library_TARGET "PkgConfig::${library_TARGET_prefix}")
        endif()
    endif()

    if (NOT TARGET "${library_TARGET}")
        message(FATAL_ERROR "${library_TARGET} is not an existing target")
    endif()


    if (library_TARGET IN_LIST ${generated_targets_var})
        return()
    endif()
    list(APPEND ${generated_targets_var} ${library_TARGET})

    get_target_property(library_ALIASED_TARGET ${library_TARGET} ALIASED_TARGET)
    if (library_ALIASED_TARGET)
        set(library_TARGET ${library_ALIASED_TARGET})
    endif()

    get_target_property(__imported ${library_TARGET} IMPORTED)
    if (NOT __imported)
        message(FATAL_ERROR "link library ${library_TARGET} is not an imported target")
    endif()

    # Include directories
    get_target_property(__interface_include_directories ${library_TARGET} INTERFACE_INCLUDE_DIRECTORIES)
    if (__interface_include_directories)
        list(APPEND ${library_IMPORTED_DEPS}_INCLUDE_DIR ${__interface_include_directories})
        set(has_INCLUDE_DIR TRUE)
    endif()

    # Libraries
    get_target_property(__interface_link_libraries ${library_TARGET} INTERFACE_LINK_LIBRARIES)
    if (__interface_link_libraries)
        foreach(linked_library IN LISTS __interface_link_libraries)
            _add_bazel_library(${generated_targets_var}
                TARGET          ${linked_library}
                IMPORTED_DEPS   ${library_IMPORTED_DEPS}
                TARGET_DEPS     ${library_TARGET_DEPS}
                SOURCES         ${library_SOURCES}
                DEPS            ${library_DEPS}
                RULE            ${library_RULE}
                ${library_LINKSHARED}
                ${library_LINKSTATIC}
                ${library_ALWAYSLINK}
            )
        endforeach()
    endif()

    # Compile options
    get_target_property(__interface_compile_options ${library_TARGET} INTERFACE_COMPILE_OPTIONS)
    if (__interface_compile_options)
        list(APPEND ${library_IMPORTED_DEPS}_COMPILE_OPTIONS ${__interface_compile_options})
    endif()

    string(TOUPPER ${CMAKE_BUILD_TYPE} __imported_configuration)

    get_target_property(__imported_configurations ${library_TARGET} IMPORTED_CONFIGURATIONS)
    if (__imported_configurations AND NOT __imported_configuration IN_LIST __imported_configurations)
        list(GET __imported_configurations 0 __imported_configuration)
    endif()

    get_target_property(__imported_implib ${library_TARGET} IMPORTED_IMPLIB_${__imported_configuration})
    if (NOT __imported_implib)
        get_target_property(__imported_implib ${library_TARGET} IMPORTED_IMPLIB)
    endif()
    if (__imported_implib)
        list(APPEND ${library_IMPORTED_DEPS}_LIBRARIES ${__imported_implib})
        set(has_LIBRARIES TRUE)
    endif()

    get_target_property(__imported_location ${library_TARGET} IMPORTED_LOCATION_${__imported_configuration})
    if (NOT __imported_location)
        get_target_property(__imported_location ${library_TARGET} IMPORTED_LOCATION)
    endif()
    if (__imported_location)
        list(APPEND ${library_IMPORTED_DEPS}_LIBRARIES ${__imported_location})
        set(has_LIBRARIES TRUE)
    endif()

    if (has_INCLUDE_DIR)
        list_cmake_convert(TO_CMAKE_PATH ${library_IMPORTED_DEPS}_INCLUDE_DIR)
        list(REMOVE_DUPLICATES ${library_IMPORTED_DEPS}_INCLUDE_DIR)
    endif()

    if (has_LIBRARIES)
        list(REMOVE_DUPLICATES ${library_IMPORTED_DEPS}_LIBRARIES)
    endif()

    set(${generated_targets_var} ${${generated_targets_var}} PARENT_SCOPE)

    set(${library_IMPORTED_DEPS}_INCLUDE_DIR "${${library_IMPORTED_DEPS}_INCLUDE_DIR}" PARENT_SCOPE)
    set(${library_IMPORTED_DEPS}_LIBRARIES "${${library_IMPORTED_DEPS}_LIBRARIES}" PARENT_SCOPE)
    set(${library_TARGET_DEPS} "${${library_TARGET_DEPS}}" PARENT_SCOPE)
    set(${library_SOURCES} "${${library_SOURCES}}" PARENT_SCOPE)
    set(${library_DEPS} "${${library_DEPS}}" PARENT_SCOPE)
endfunction()

function(get_bazel_library)
    set(options
        LINKSHARED
        LINKSTATIC
        ALWAYSLINK
    )
    set(oneValueArgs
        NAME
        PKGNAME
        OUTPUT_VARIABLE
        RULE
        LINKNAME
    )
    set(multiValueArgs
        INCLUDES
        LOCAL_INCLUDES
        SOURCES
        COPTS
        DEFINES
        LOCAL_DEFINES
        LINKOPTS
        DEPS
    )
    cmake_parse_arguments(PARSE_ARGV 0 library
        "${options}" "${oneValueArgs}" "${multiValueArgs}"
    )

    if (library_UNPARSED_ARGUMENTS)
        string(REPLACE ";" ", " library_UNPARSED_ARGUMENTS "${library_UNPARSED_ARGUMENTS}")
        message(FATAL_ERROR "Unknown arguments [${library_UNPARSED_ARGUMENTS}]")
    endif()

    foreach(keyword IN ITEMS OUTPUT_VARIABLE NAME PKGNAME)
        if (NOT library_${keyword})
            message(FATAL_ERROR "${keyword} argument is missing")
        endif()
    endforeach()

    if (library_LOCAL_INCLUDES)
        if (WIN32)
            list(TRANSFORM library_LOCAL_INCLUDES PREPEND "/I")
        else()
            list(TRANSFORM library_LOCAL_INCLUDES PREPEND "-I")
        endif()
        list(APPEND library_COPTS ${library_LOCAL_INCLUDES})
    endif()

    set(library_OUPUT
        "{"
        "    name: \"${library_NAME}\","
        "    pkgname: \"${library_PKGNAME}\","
    )

    if (library_RULE)
        list(APPEND library_OUPUT "    rule: \"${library_RULE}\",")
    endif()

    if (library_INCLUDES)
        list_to_json_array(library_INCLUDES INDENT "    ")
        list(APPEND library_OUPUT "    includes: ${library_INCLUDES},")
    endif()

    set(library_KWARGS)

    set(library_PREFIXES "$<EMPTY>")
    list(APPEND library_PREFIXES "")
    list(APPEND library_PREFIXES ${CMAKE_FIND_LIBRARY_PREFIXES})
    list(POP_FRONT library_PREFIXES)
    unset(library_SYSTEM_LIBRARIES)

    foreach(item_library IN LISTS library_SOURCES)
        set(_next_library FALSE)

        cmake_path(GET item_library FILENAME item_library_FILENAME)
        string(LENGTH "${item_library_FILENAME}" item_library_FILENAME_LENGTH)
        set(_item_library "${item_library}")
        if (WIN32)
            string(TOLOWER "${item_library}" item_library)
        endif()

        foreach(library_SUFFIX IN LISTS CMAKE_FIND_LIBRARY_SUFFIXES)
            if (_next_library)
                break()
            endif()

            string(LENGTH "${library_SUFFIX}" library_SUFFIX_LENGTH)

            foreach(library_PREFIX IN LISTS library_PREFIXES)
                if (NOT item_library_FILENAME MATCHES "^${library_PREFIX}.+${library_SUFFIX}$")
                    continue()
                endif()

                string(LENGTH "${library_PREFIX}" library_PREFIX_LENGTH)
                math(EXPR library_REMAINING_LENGTH "${item_library_FILENAME_LENGTH} - ${library_PREFIX_LENGTH} - ${library_SUFFIX_LENGTH}")
                string(SUBSTRING "${item_library_FILENAME}" ${library_PREFIX_LENGTH} ${library_REMAINING_LENGTH} library_LIBNAME)

                if (WIN32)
                    string(TOLOWER "${library_LIBNAME}" library_LIBNAME)
                endif()

                unset(_system_library)
                find_library(_system_library "${library_LIBNAME}"
                    NO_CACHE
                    NO_PACKAGE_ROOT_PATH
                    NO_CMAKE_PATH
                    NO_CMAKE_ENVIRONMENT_PATH
                    NO_CMAKE_INSTALL_PREFIX
                )

                if (_system_library AND WIN32)
                    string(TOLOWER "${_system_library}" _system_library)
                endif()

                if (_system_library STREQUAL item_library)
                    list(APPEND library_SYSTEM_LIBRARIES "${_item_library}")
                    if (WIN32)
                        list(APPEND library_LINKOPTS "${library_LIBNAME}${library_SUFFIX}")
                    else()
                        list(APPEND library_LINKOPTS "-l${library_LIBNAME}")
                    endif()
                    set(_next_library TRUE)
                    break()
                endif()
            endforeach()
        endforeach()
    endforeach()

    list(REMOVE_ITEM library_SOURCES ${library_SYSTEM_LIBRARIES})

    if (library_SOURCES)
        # Some linux libraries (brotli, nghttp2) assumes -iquote .
        # However, bazel sandbox will not find related heades
        # if they are not in the include directories.
        # Therefore, manually add those headers to srcs attribute
        set(library_LOCAL_INCLUDES ${library_SOURCES})
        list_cmake_path(GET library_LOCAL_INCLUDES PARENT_PATH)
        list(REMOVE_DUPLICATES library_LOCAL_INCLUDES)
        list(TRANSFORM library_LOCAL_INCLUDES APPEND "/*.h" OUTPUT_VARIABLE library_C_HEADERS)
        list(TRANSFORM library_LOCAL_INCLUDES APPEND "/*.hh" OUTPUT_VARIABLE library_CC_HEADERS)
        list(TRANSFORM library_LOCAL_INCLUDES APPEND "/*.hpp" OUTPUT_VARIABLE library_CPP_HEADERS)
        list(TRANSFORM library_LOCAL_INCLUDES APPEND "/*.hxx" OUTPUT_VARIABLE library_CXX_HEADERS)

        file(GLOB library_LOCAL_INCLUDES ${library_C_HEADERS} ${library_CC_HEADERS} ${library_CPP_HEADERS} ${library_CXX_HEADERS})
        if (library_LOCAL_INCLUDES)
            list(APPEND library_SOURCES ${library_LOCAL_INCLUDES})
        endif()

        list(REMOVE_DUPLICATES library_SOURCES)

        # .def file should go to win_def_file attr
        set(library_DEF_FILES ${library_SOURCES})
        list(FILTER library_DEF_FILES INCLUDE REGEX "\\.def$")
        if (library_DEF_FILES)
            list(APPEND library_KWARGS "win_def_file: \"${library_DEF_FILES}\",")
        endif()

        # Resource files are not supported by bazel
        list(FILTER library_SOURCES EXCLUDE REGEX "\\.(def|rc)$")

        list_to_json_array(library_SOURCES INDENT "    ")
        list(APPEND library_OUPUT "    libraries: ${library_SOURCES},")
    endif()

    if (library_COPTS)
        list_to_json_array(library_COPTS INDENT "        ")
        list(APPEND library_KWARGS "copts: ${library_COPTS},")
    endif()

    if (library_DEFINES)
        list_to_json_array(library_DEFINES INDENT "        ")
        list(APPEND library_KWARGS "defines: ${library_DEFINES},")
    endif()

    if (library_LOCAL_DEFINES)
        list_to_json_array(library_LOCAL_DEFINES INDENT "        ")
        list(APPEND library_KWARGS "local_defines: ${library_LOCAL_DEFINES},")
    endif()

    if (library_LINKOPTS)
        list_to_json_array(library_LINKOPTS INDENT "        ")
        list(APPEND library_KWARGS "linkopts: ${library_LINKOPTS},")
    endif()

    if (library_DEPS)
        list_to_json_array(library_DEPS INDENT "        ")
        list(APPEND library_KWARGS "deps: ${library_DEPS},")
    endif()

    if (library_LINKNAME)
        list(APPEND library_KWARGS "linkname: \"${library_LINKNAME}\",")
    endif()

    if (library_LINKSHARED)
        list(APPEND library_KWARGS "linkshared: true,")
    endif()

    if (library_LINKSTATIC)
        list(APPEND library_KWARGS "linkstatic: true,")
    endif()

    if (library_ALWAYSLINK)
        list(APPEND library_KWARGS "alwayslink: true,")
    endif()

    if (library_KWARGS)
        string(REPLACE ";" "\n        " library_KWARGS "${library_KWARGS}")
        list(APPEND library_OUPUT "    kwargs: {")
        list(APPEND library_OUPUT "        ${library_KWARGS}")
        list(APPEND library_OUPUT "    },")
    endif()

    list(APPEND library_OUPUT "}")

    string(REPLACE ";" "\n" library_OUPUT "${library_OUPUT}")

    set(${library_OUTPUT_VARIABLE} "${library_OUPUT}" PARENT_SCOPE)
endfunction()

function(generate_bazel_library_imported generated_targets_var)
    set(options
        LINKSHARED
        LINKSTATIC
        ALWAYSLINK
    )
    set(oneValueArgs
        TARGET
        NAME
        PKGNAME
        OUTPUT_VARIABLE
        RULE
        LINKNAME
    )
    set(multiValueArgs)
    cmake_parse_arguments(PARSE_ARGV 1 library
        "${options}" "${oneValueArgs}" "${multiValueArgs}"
    )

    if (library_UNPARSED_ARGUMENTS)
        string(REPLACE ";" ", " library_UNPARSED_ARGUMENTS "${library_UNPARSED_ARGUMENTS}")
        message(FATAL_ERROR "Unknown arguments [${library_UNPARSED_ARGUMENTS}]")
    endif()

    foreach(keyword IN ITEMS OUTPUT_VARIABLE NAME PKGNAME)
        if (NOT library_${keyword})
            message(FATAL_ERROR "${keyword} argument is missing")
        endif()
    endforeach()

    foreach(arg IN LISTS options)
        if (library_${arg})
            set(library_${arg} ${arg})
        else()
            unset(library_${arg})
        endif()
    endforeach()

    if (NOT TARGET "${library_TARGET}")
        message(FATAL_ERROR "${library_TARGET} is not an existing target")
    endif()

    if (library_TARGET IN_LIST ${generated_targets_var})
        unset(${library_OUTPUT_VARIABLE} PARENT_SCOPE)
        return()
    endif()

    unset(_library_TARGET_DEPS)
    unset(_library_SOURCES)
    unset(_library_DEPS)

    ImportLibrary_Populate(${generated_targets_var}
        TARGET          ${library_TARGET}
        IMPORTED_DEPS   library
        TARGET_DEPS     _library_TARGET_DEPS
        SOURCES         _library_SOURCES
        DEPS            _library_DEPS
        RULE            ${library_RULE}
        ${library_LINKSHARED}
        ${library_LINKSTATIC}
        ${library_ALWAYSLINK}
    )

    unset(_bazel_library)

    get_bazel_library(
        OUTPUT_VARIABLE _bazel_library
        NAME            ${library_NAME}
        PKGNAME         ${library_PKGNAME}
        RULE            ${library_RULE}
        LINKNAME        ${library_LINKNAME}
        INCLUDES        ${library_INCLUDE_DIR}
        SOURCES         ${_library_SOURCES} ${library_LIBRARIES}
        COPTS           ${library_COMPILE_OPTIONS}
        DEPS            ${_library_DEPS}
        ${library_LINKSHARED}
        ${library_LINKSTATIC}
        ${library_ALWAYSLINK}
    )

    list(APPEND _library_TARGET_DEPS ${_bazel_library})

    set(${library_OUTPUT_VARIABLE} ${_library_TARGET_DEPS} PARENT_SCOPE)
    set(${generated_targets_var} ${${generated_targets_var}} PARENT_SCOPE)
endfunction()

function(_add_bazel_library generated_targets_var)
    set(options
        LINKSHARED
        LINKSTATIC
        ALWAYSLINK
    )
    set(oneValueArgs
        TARGET
        IMPORTED_DEPS
        TARGET_DEPS
        SOURCES
        DEPS
        RULE
    )
    set(multiValueArgs)
    cmake_parse_arguments(PARSE_ARGV 1 library
        "${options}" "${oneValueArgs}" "${multiValueArgs}"
    )

    if (library_UNPARSED_ARGUMENTS)
        string(REPLACE ";" ", " library_UNPARSED_ARGUMENTS "${library_UNPARSED_ARGUMENTS}")
        message(FATAL_ERROR "Unknown arguments [${library_UNPARSED_ARGUMENTS}]")
    endif()

    foreach(arg IN LISTS options)
        if (library_${arg})
            set(library_${arg} ${arg})
        else()
            unset(library_${arg})
        endif()
    endforeach()


    # foreach is just an astuce to perform early return without creating other functions
    foreach(item IN LISTS library_TARGET)
        # TODO : avoid rechecking the same library

        if (item MATCHES "(^-|\\${CMAKE_SHARED_LIBRARY_SUFFIX}$|\\${CMAKE_STATIC_LIBRARY_SUFFIX}$)")
            list(APPEND library_LINKOPTS "${item}")
            continue()
        endif()

        if (NOT TARGET "${item}")
            unset(item_library)
            find_library(item_library "${item}"
                PATHS ${library_LINK_DIRECTORIES}
                NO_CACHE
            )

            if (WIN32)
                # Extension checking is case sensitive on bazel
                cmake_path(GET item_library PARENT_PATH item_library_PARENT_PATH)
                cmake_path(GET item_library FILENAME item_library_FILENAME)
                string(TOLOWER "${item_library_FILENAME}" item_library_FILENAME)
                set(item_library "${item_library_PARENT_PATH}/${item_library_FILENAME}")
            endif()

            if (item_library MATCHES "(\\${CMAKE_SHARED_LIBRARY_SUFFIX}|\\${CMAKE_STATIC_LIBRARY_SUFFIX})$")
                list(APPEND ${library_IMPORTED_DEPS}_LIBRARIES "${item_library}")
                continue()
            endif()
        endif()

        if (item MATCHES "::")
            string(REPLACE "::" ";" item_PARTS "${item}")
            list(GET item_PARTS 0 item_NAME)
            list(GET item_PARTS 1 item_PKGNAME)
        else()
            set(item_NAME "${item}")
            set(item_PKGNAME "${item}")
        endif()

        if (DEFINED item_NEW_NAME_${item_NAME})
            set(item_NAME "${item_NEW_NAME_${item_NAME}}")
        endif()

        if (DEFINED item_NEW_PKFNAME_${item_NAME}_${item_PKGNAME})
            set(item_PKGNAME "${item_NEW_PKFNAME_${item_NAME}_${item_PKGNAME}}")
        endif()

        set(__imported TRUE)

        if (TARGET "${item}")
            get_target_property(__imported ${item} IMPORTED)
        endif()

        if (__imported)
            ImportLibrary_Populate(${generated_targets_var}
                TARGET          ${item}

                IMPORTED_DEPS   ${library_IMPORTED_DEPS}
                TARGET_DEPS     ${library_TARGET_DEPS}
                SOURCES         ${library_SOURCES}
                DEPS            ${library_DEPS}
                RULE            ${library_RULE}
                ${library_LINKSHARED}
                ${library_LINKSTATIC}
                ${library_ALWAYSLINK}
            )
        else()
            unset(item_LINKNAME)
            if (library_RULE STREQUAL "cc_object")
                set(item_LINKNAME ${item_PKGNAME}_link)
            endif()

            unset(_bazel_library_item)
            _generate_bazel_library(${generated_targets_var}
                OUTPUT_VARIABLE _bazel_library_item
                TARGET          ${item}
                NAME            ${item_NAME}
                PKGNAME         ${item_PKGNAME}
                LINKNAME        ${item_LINKNAME}
                RULE            ${library_RULE}
                ${library_LINKSHARED}
                ${library_LINKSTATIC}
                ${library_ALWAYSLINK}
            )

            if (_bazel_library_item)
                if (library_RULE STREQUAL "cc_object")
                    list(APPEND ${library_SOURCES} "@${item_NAME}//:${item_PKGNAME}")
                    list(APPEND ${library_DEPS} "@${item_NAME}//:${item_LINKNAME}")
                else()
                    list(APPEND ${library_DEPS} "@${item_NAME}//:${item_PKGNAME}")
                endif()

                list(APPEND ${library_TARGET_DEPS} ${_bazel_library_item})
            endif()
        endif()
    endforeach()


    set(${generated_targets_var} ${${generated_targets_var}} PARENT_SCOPE)

    set(${library_IMPORTED_DEPS}_INCLUDE_DIR "${${library_IMPORTED_DEPS}_INCLUDE_DIR}" PARENT_SCOPE)
    set(${library_IMPORTED_DEPS}_LIBRARIES "${${library_IMPORTED_DEPS}_LIBRARIES}" PARENT_SCOPE)
    set(${library_TARGET_DEPS} "${${library_TARGET_DEPS}}" PARENT_SCOPE)
    set(${library_SOURCES} "${${library_SOURCES}}" PARENT_SCOPE)
    set(${library_DEPS} "${${library_DEPS}}" PARENT_SCOPE)
endfunction()

function(_generate_bazel_library generated_targets_var)
    set(options
        LINKSHARED
        LINKSTATIC
        ALWAYSLINK
    )
    set(oneValueArgs
        TARGET
        NAME
        PKGNAME
        OUTPUT_VARIABLE
        RULE
        LINKNAME
    )
    set(multiValueArgs
        NAME_OVERRIDES
        PKGNAME_OVERRIDES
    )
    cmake_parse_arguments(PARSE_ARGV 1 library
        "${options}" "${oneValueArgs}" "${multiValueArgs}"
    )

    if (library_UNPARSED_ARGUMENTS)
        string(REPLACE ";" ", " library_UNPARSED_ARGUMENTS "${library_UNPARSED_ARGUMENTS}")
        message(FATAL_ERROR "Unknown arguments [${library_UNPARSED_ARGUMENTS}]")
    endif()

    foreach(keyword IN ITEMS OUTPUT_VARIABLE NAME PKGNAME)
        if (NOT library_${keyword})
            message(FATAL_ERROR "${keyword} argument is missing")
        endif()
    endforeach()

    foreach(arg IN LISTS options)
        if (library_${arg})
            set(library_${arg} ${arg})
        else()
            unset(library_${arg})
        endif()
    endforeach()

    if (NOT TARGET "${library_TARGET}")
        message(FATAL_ERROR "${library_TARGET} is not an existing target")
    endif()

    foreach(item IN LISTS library_NAME_OVERRIDES)
        string(REPLACE "," ";" item_PARTS "${item}")
        list(GET item_PARTS 0 item_OLD_NAME)
        list(GET item_PARTS 1 item_NEW_NAME)
        set(item_NEW_NAME_${item_OLD_NAME} "${item_NEW_NAME}")
    endforeach()

    foreach(item IN LISTS library_PKGNAME_OVERRIDES)
        string(REPLACE "," ";" item_PARTS "${item}")
        list(GET item_PARTS 0 item_NAME)
        list(GET item_PARTS 1 item_OLD_PKGNAME)
        list(GET item_PARTS 2 item_NEW_PKGNAME)
        set(item_NEW_PKFNAME_${item_NAME}_${item_OLD_PKGNAME} "${item_NEW_PKGNAME}")
    endforeach()

    get_target_property(library_ALIASED_TARGET ${library_TARGET} ALIASED_TARGET)
    if (library_ALIASED_TARGET)
        set(library_TARGET ${library_ALIASED_TARGET})
    endif()

    get_target_property(__imported ${library_TARGET} IMPORTED)
    if (__imported)
        unset(_bazel_library)
        generate_bazel_library_imported(${generated_targets_var}
            OUTPUT_VARIABLE _bazel_library
            TARGET          ${library_TARGET}
            NAME            ${library_NAME}
            PKGNAME         ${library_PKGNAME}

            RULE            ${library_RULE}
            LINKNAME        ${library_LINKNAME}
            ${library_LINKSHARED}
            ${library_LINKSTATIC}
            ${library_ALWAYSLINK}
        )

        set(${library_OUTPUT_VARIABLE} ${_bazel_library} PARENT_SCOPE)
        return()
    endif()

    if (library_TARGET IN_LIST ${generated_targets_var})
        unset(${library_OUTPUT_VARIABLE} PARENT_SCOPE)
        return()
    endif()
    list(APPEND ${generated_targets_var} ${library_TARGET})

    # SOURCES
    get_target_property(library_SOURCE_DIR ${library_TARGET} SOURCE_DIR)
    if (NOT library_SOURCE_DIR)
        unset(library_SOURCE_DIR)
    endif()

    get_target_property(_library_SOURCES ${library_TARGET} SOURCES)
    if (NOT _library_SOURCES)
        unset(_library_SOURCES)
    else()
        list_cmake_path(ABSOLUTE_PATH _library_SOURCES BASE_DIRECTORY "${library_SOURCE_DIR}" NORMALIZE OUTPUT_VARIABLE)
    endif()

    get_target_property(library_TYPE ${library_TARGET} TYPE)

    # dependencies
    unset(bazel_library_deps)

    get_target_property(library_COPTS ${library_TARGET} COMPILE_FLAGS)
    if (NOT library_COPTS)
        unset(library_COPTS)
    endif()

    split_target_property(library_INCLUDES ${library_TARGET} INCLUDE_DIRECTORIES)
    if (library_TYPE STREQUAL "INTERFACE_LIBRARY")
        set(library_INCLUDES ${library_INCLUDES_INTERFACE})
        unset(library_LOCAL_INCLUDES)
    else()
        set(library_INCLUDES ${library_INCLUDES_PUBLIC} ${library_INCLUDES_INTERFACE})
        set(library_LOCAL_INCLUDES ${library_INCLUDES_PRIVATE})
    endif()

    split_target_property(library_DEFINES ${library_TARGET} COMPILE_DEFINITIONS)
    if (library_TYPE STREQUAL "INTERFACE_LIBRARY")
        set(library_DEFINES ${library_DEFINES_INTERFACE})
        unset(library_LOCAL_DEFINES)
    else()
        set(library_DEFINES ${library_DEFINES_PUBLIC} ${library_DEFINES_INTERFACE})
        set(library_LOCAL_DEFINES ${library_DEFINES_PRIVATE})
    endif()

    split_target_property(library_COPTS ${library_TARGET} COMPILE_OPTIONS)
    if (library_TYPE STREQUAL "INTERFACE_LIBRARY")
        list(APPEND library_COPTS ${library_COPTS_INTERFACE})
    else()
        list(APPEND library_COPTS ${library_COPTS_PUBLIC} ${library_COPTS_INTERFACE})
        list(APPEND library_COPTS ${library_COPTS_PRIVATE})
    endif()

    split_target_property(library_LINKOPTS ${library_TARGET} LINK_OPTIONS)
    if (library_TYPE STREQUAL "INTERFACE_LIBRARY")
        list(APPEND library_LINKOPTS ${library_LINKOPTS_INTERFACE})
    else()
        list(APPEND library_LINKOPTS ${library_LINKOPTS_PUBLIC} ${library_LINKOPTS_INTERFACE})
        list(APPEND library_LINKOPTS ${library_LINKOPTS_PRIVATE})
    endif()

    if (library_SOURCE_DIR AND NOT library_TYPE STREQUAL "INTERFACE_LIBRARY")
        get_property(library_DIRECTORY_DEFINES DIRECTORY "${library_SOURCE_DIR}" PROPERTY COMPILE_DEFINITIONS)
        if (library_DIRECTORY_DEFINES)
            list(APPEND library_LOCAL_DEFINES ${library_DIRECTORY_DEFINES})
        endif()

        # This property is initialized by the COMPILE_OPTIONS directory property when a target is created
        # get_property(library_DIRECTORY_COPTS DIRECTORY "${library_SOURCE_DIR}" PROPERTY COMPILE_OPTIONS)
        # if (library_DIRECTORY_COPTS)
        #     list(APPEND library_COPTS ${library_DIRECTORY_COPTS})
        # endif()

        # This property is initialized by the LINK_OPTIONS directory property when a target is created
        # get_property(library_DIRECTORY_LINKOPTS DIRECTORY "${library_SOURCE_DIR}" PROPERTY LINK_OPTIONS)
        # if (library_DIRECTORY_LINKOPTS)
        #     list(APPEND library_LINKOPTS ${library_DIRECTORY_LINKOPTS})
        # endif()
    endif()

    unset(library_LINK_DIRECTORIES)
    split_target_property(library_LINK_DIRECTORIES ${library_TARGET} LINK_DIRECTORIES)
    if (library_TYPE STREQUAL "INTERFACE_LIBRARY")
        list(APPEND library_LINK_DIRECTORIES ${library_LINK_DIRECTORIES_INTERFACE})
        # library_LINK_DIRECTORIES_PUBLIC will be added through deps transitive linkopts
    else()
        list(APPEND library_LINK_DIRECTORIES ${library_LINK_DIRECTORIES_PRIVATE})
        list(APPEND library_LINK_DIRECTORIES ${library_LINK_DIRECTORIES_PUBLIC} ${library_LINK_DIRECTORIES_INTERFACE})
    endif()

    if (library_SOURCE_DIR AND NOT library_TYPE STREQUAL "INTERFACE_LIBRARY")
        get_property(library_DIRECTORY_LINK_DIRECTORIES DIRECTORY "${library_SOURCE_DIR}" PROPERTY LINK_DIRECTORIES)
        if (library_DIRECTORY_LINK_DIRECTORIES)
            list(APPEND library_LINK_DIRECTORIES ${library_DIRECTORY_LINK_DIRECTORIES})
        endif()
    endif()

    # Traverse dependencies
    if (library_TYPE STREQUAL "INTERFACE_LIBRARY")
        get_target_property(library_LINK_LIBRARIES ${library_TARGET} INTERFACE_LINK_LIBRARIES)
    else()
        get_target_property(library_LINK_LIBRARIES ${library_TARGET} LINK_LIBRARIES)
    endif()
    if (NOT library_LINK_LIBRARIES)
        unset(library_LINK_LIBRARIES)
    endif()

    unset(_library_TARGET_DEPS)
    unset(_library_DEPS)

    foreach(linked_library IN LISTS library_LINK_LIBRARIES)
        _add_bazel_library(${generated_targets_var}
            TARGET          ${linked_library}
            IMPORTED_DEPS   ${library_TARGET}_deps
            TARGET_DEPS     _library_TARGET_DEPS
            SOURCES         _library_SOURCES
            DEPS            _library_DEPS
            RULE            ${library_RULE}
            ${library_LINKSHARED}
            ${library_LINKSTATIC}
            ${library_ALWAYSLINK}
        )
    endforeach()

    if (${library_TARGET}_deps_INCLUDE_DIR OR ${library_TARGET}_deps_LIBRARIES OR ${library_TARGET}_deps_COMPILE_OPTIONS)
        unset(_bazel_library_deps)
        get_bazel_library(
            OUTPUT_VARIABLE _bazel_library_deps
            NAME            ${library_PKGNAME}_${library_TARGET}_deps
            PKGNAME         deps
            INCLUDES        ${${library_TARGET}_deps_INCLUDE_DIR}
            SOURCES         ${${library_TARGET}_deps_LIBRARIES}
            COPTS           ${${library_TARGET}_deps_COMPILE_OPTIONS}
        )

        list(APPEND _library_DEPS "@${library_PKGNAME}_${library_TARGET}_deps//:deps")
        list(APPEND _library_TARGET_DEPS ${_bazel_library_deps})
    endif()

    unset(_bazel_library)
    get_bazel_library(
        OUTPUT_VARIABLE _bazel_library
        NAME            ${library_NAME}
        PKGNAME         ${library_PKGNAME}
        RULE            ${library_RULE}
        LINKNAME        ${library_LINKNAME}
        INCLUDES        ${library_INCLUDES}
        LOCAL_INCLUDES  ${library_LOCAL_INCLUDES}
        SOURCES         ${_library_SOURCES}
        COPTS           ${library_COPTS}
        LINKOPTS        ${library_LINKOPTS}
        DEFINES         ${library_DEFINES}
        LOCAL_DEFINES   ${library_LOCAL_DEFINES}
        DEPS            ${_library_DEPS}
        ${library_LINKSHARED}
        ${library_LINKSTATIC}
        ${library_ALWAYSLINK}
    )

    list(APPEND _library_TARGET_DEPS ${_bazel_library})

    set(${library_OUTPUT_VARIABLE} ${_library_TARGET_DEPS} PARENT_SCOPE)
    set(${generated_targets_var} ${${generated_targets_var}} PARENT_SCOPE)
endfunction()

function(generate_bazel_library)
    set(options)
    set(oneValueArgs
        TARGET
        OUTPUT_VARIABLE
    )
    set(multiValueArgs)
    cmake_parse_arguments(PARSE_ARGV 0 library
        "${options}" "${oneValueArgs}" "${multiValueArgs}"
    )
    unset(_seen_targets)
    _generate_bazel_library(_seen_targets ${ARGV})
    set(${library_OUTPUT_VARIABLE} ${${library_OUTPUT_VARIABLE}} PARENT_SCOPE)
endfunction()