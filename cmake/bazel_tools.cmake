function(list_to_json_array list_NAME)
    set(options)
    set(oneValueArgs OUTPUT_VARIABLE INDENT)
    set(multiValueArgs)
    cmake_parse_arguments(PARSE_ARGV 1 list
        "${options}" "${oneValueArgs}" "${multiValueArgs}"
    )

    if (list_UNPARSED_ARGUMENTS)
        string(REPLACE ";" ", " list_UNPARSED_ARGUMENTS "${list_UNPARSED_ARGUMENTS}")
        message(FATAL_ERROR "Unknown arguments [${list_UNPARSED_ARGUMENTS}]")
    endif()

    if (NOT list_OUTPUT_VARIABLE)
        set(list_OUTPUT_VARIABLE ${list_NAME})
    endif()

    if (NOT list_INDENT)
        string(REPLACE ";" "\", \"" list_OUTPUT "${${list_NAME}}")
        set(${list_OUTPUT_VARIABLE} "[\"${list_OUTPUT}\"]" PARENT_SCOPE)
        return()
    endif()

    list(TRANSFORM ${list_NAME} PREPEND "    ${list_INDENT}\"")
    list(TRANSFORM ${list_NAME} APPEND "\",")
    list(PREPEND ${list_NAME} "[")
    list(APPEND ${list_NAME} "${list_INDENT}]")
    string(REPLACE ";" "\n" list_OUTPUT "${${list_NAME}}")

    set(${list_OUTPUT_VARIABLE} "${list_OUTPUT}" PARENT_SCOPE)
endfunction()

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

function(ImportLibrary_Populate the_target prefix)
    if (NOT TARGET "${the_target}")
        string(TOUPPER "${the_target}" the_target_prefix)
        find_package(PkgConfig QUIET)
        pkg_check_modules(${the_target_prefix} "lib${the_target}" IMPORTED_TARGET)
        if(${the_target_prefix}_FOUND)
            set(the_target "PkgConfig::${the_target_prefix}")
        endif()
    endif()

    if (NOT TARGET "${the_target}")
        message(FATAL_ERROR "${the_target} is a non-existent target")
    endif()

    get_target_property(library_ALIASED_TARGET ${the_target} ALIASED_TARGET)
    if (library_ALIASED_TARGET)
        set(the_target ${library_ALIASED_TARGET})
    endif()

    get_target_property(__imported ${the_target} IMPORTED)
    if (NOT __imported)
        message(FATAL_ERROR "link library ${the_target} is not an imported target")
    endif()

    # Include directories
    get_target_property(__interface_include_directories ${the_target} INTERFACE_INCLUDE_DIRECTORIES)
    if (__interface_include_directories)
        list(APPEND ${prefix}_INCLUDE_DIR ${__interface_include_directories})
        list_cmake_convert(TO_CMAKE_PATH ${prefix}_INCLUDE_DIR)
        list(REMOVE_DUPLICATES ${prefix}_INCLUDE_DIR)
        set(${prefix}_INCLUDE_DIR "${${prefix}_INCLUDE_DIR}" PARENT_SCOPE)
    endif()

    # Libraries
    get_target_property(__interface_link_libraries ${the_target} INTERFACE_LINK_LIBRARIES)
    if (__interface_link_libraries)
        foreach(linked_library IN LISTS __interface_link_libraries)
            if (TARGET "${linked_library}")
                ImportLibrary_Populate(${linked_library} ${prefix})
            else()
                list(APPEND ${prefix}_LIBRARIES "${linked_library}")
            endif()
        endforeach()
    endif()

    string(TOUPPER ${CMAKE_BUILD_TYPE} __imported_configuration)

    get_target_property(__imported_configurations ${the_target} IMPORTED_CONFIGURATIONS)
    if (__imported_configurations AND NOT __imported_configuration IN_LIST __imported_configurations)
        list(GET __imported_configurations 0 __imported_configuration)
    endif()

    get_target_property(__imported_implib ${the_target} IMPORTED_IMPLIB_${__imported_configuration})
    if (NOT __imported_implib)
        get_target_property(__imported_implib ${the_target} IMPORTED_IMPLIB)
    endif()
    if (__imported_implib)
        list(APPEND ${prefix}_LIBRARIES ${__imported_implib})
    endif()

    get_target_property(__imported_location ${the_target} IMPORTED_LOCATION_${__imported_configuration})
    if (NOT __imported_location)
        get_target_property(__imported_location ${the_target} IMPORTED_LOCATION)
    endif()
    if (__imported_location)
        list(APPEND ${prefix}_LIBRARIES ${__imported_location})
    endif()

    if (${prefix}_LIBRARIES)
        list(REMOVE_DUPLICATES ${prefix}_LIBRARIES)
        set(${prefix}_LIBRARIES "${${prefix}_LIBRARIES}" PARENT_SCOPE)
    endif()
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
        # Many linux libraries (nghttp2) assumes -iquote .
        # However, bazel sandbox will not find related heades
        # If they are not in the include directories.
        # Therefores, manually add those headers to srcs attribute
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

function(generate_bazel_library_imported)
    set(options)
    set(oneValueArgs
        TARGET
        NAME
        PKGNAME
        OUTPUT_VARIABLE
    )
    set(multiValueArgs)
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

    if (NOT TARGET "${library_TARGET}")
        message(FATAL_ERROR "${library_TARGET} is a non-existent target")
    endif()

    ImportLibrary_Populate(${library_TARGET} library)

    get_bazel_library(
        OUTPUT_VARIABLE ${library_OUTPUT_VARIABLE}
        NAME            ${library_NAME}
        PKGNAME         ${library_PKGNAME}
        INCLUDES        ${library_INCLUDE_DIR}
        SOURCES         ${library_LIBRARIES}
    )

    set(${library_OUTPUT_VARIABLE} "${${library_OUTPUT_VARIABLE}}" PARENT_SCOPE)
endfunction()

function(_generate_bazel_library generated_list_var)
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
        message(FATAL_ERROR "${library_TARGET} is a non-existent target")
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

    if (library_TARGET IN_LIST ${generated_list_var})
        unset(${library_OUTPUT_VARIABLE} PARENT_SCOPE)
        return()
    endif()
    list(APPEND ${generated_list_var} ${library_TARGET})

    get_target_property(__imported ${library_TARGET} IMPORTED)
    if (__imported)
        generate_bazel_library_imported(
            OUTPUT_VARIABLE ${library_OUTPUT_VARIABLE}
            TARGET          ${library_TARGET}
            NAME            ${library_NAME}
            PKGNAME         ${library_PKGNAME}
        )
        set(${library_OUTPUT_VARIABLE} "${${library_OUTPUT_VARIABLE}}" PARENT_SCOPE)
        return()
    endif()

    # SOURCES
    get_target_property(library_SOURCE_DIR ${library_TARGET} SOURCE_DIR)
    if (NOT library_SOURCE_DIR)
        unset(library_SOURCE_DIR)
    endif()

    get_target_property(library_SOURCES ${library_TARGET} SOURCES)
    if (NOT library_SOURCES)
        unset(library_SOURCES)
    else()
        list_cmake_path(ABSOLUTE_PATH library_SOURCES BASE_DIRECTORY "${library_SOURCE_DIR}" NORMALIZE OUTPUT_VARIABLE)
    endif()

    unset(library_LINKOPTS)
    unset(library_DEPS)

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

        get_property(library_DIRECTORY_COPTS DIRECTORY "${library_SOURCE_DIR}" PROPERTY COMPILE_OPTIONS)
        if (library_DIRECTORY_COPTS)
            list(APPEND library_COPTS ${library_DIRECTORY_COPTS})
        endif()

        get_property(library_DIRECTORY_LINKOPTS DIRECTORY "${library_SOURCE_DIR}" PROPERTY LINK_OPTIONS)
        if (library_DIRECTORY_LINKOPTS)
            list(APPEND library_LINKOPTS ${library_DIRECTORY_LINKOPTS})
        endif()
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
        set(prop_PREFIX "INTERFACE_")
    else()
        unset(prop_PREFIX)
    endif()
    get_target_property(library_LINK_LIBRARIES ${library_TARGET} ${prop_PREFIX}LINK_LIBRARIES)
    if (NOT library_LINK_LIBRARIES)
        unset(library_LINK_LIBRARIES)
    endif()

    unset(bazel_library__item_deps)
    unset(bazel_library_deps)
    unset(${library_TARGET}_deps_INCLUDE_DIR)
    unset(${library_TARGET}_deps_LIBRARIES)

    foreach(item IN LISTS library_LINK_LIBRARIES)
        # TODO : avoid rechecking the samme library
        if (item MATCHES "(^-l|\\${CMAKE_SHARED_LIBRARY_SUFFIX}$|\\${CMAKE_STATIC_LIBRARY_SUFFIX}$)")
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
                set(bazel_library_deps TRUE)
                list(APPEND ${library_TARGET}_deps_LIBRARIES "${item_library}")
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
            ImportLibrary_Populate(${item} ${library_TARGET}_deps)
            set(bazel_library_deps TRUE)
        else()
            unset(item_LINKNAME)
            if (library_RULE STREQUAL "cc_object")
                set(item_LINKNAME ${item_PKGNAME}_link)
            endif()

            _generate_bazel_library(${generated_list_var}
                OUTPUT_VARIABLE bazel_library_item
                TARGET          ${item}
                NAME            ${item_NAME}
                PKGNAME         ${item_PKGNAME}
                RULE            ${library_RULE}
                LINKNAME        ${item_LINKNAME}
                ${library_LINKSHARED}
                ${library_LINKSTATIC}
                ${library_ALWAYSLINK}
            )

            if (bazel_library_item)
                if (library_RULE STREQUAL "cc_object")
                    list(APPEND library_SOURCES "@${item_NAME}//:${item_PKGNAME}")
                    list(APPEND library_DEPS "@${item_NAME}//:${item_PKGNAME}_link")
                else()
                    list(APPEND library_DEPS "@${item_NAME}//:${item_PKGNAME}")
                endif()

                list(APPEND bazel_library__item_deps "${bazel_library_item}")
            endif()
        endif()
    endforeach()

    if (bazel_library_deps)
        get_bazel_library(
            OUTPUT_VARIABLE bazel_library_deps
            NAME            ${library_PKGNAME}_${library_TARGET}_deps
            PKGNAME         deps
            INCLUDES        ${${library_TARGET}_deps_INCLUDE_DIR}
            SOURCES         ${${library_TARGET}_deps_LIBRARIES}
        )

        list(APPEND library_DEPS "@${library_PKGNAME}_${library_TARGET}_deps//:deps")
        list(APPEND bazel_library__item_deps "${bazel_library_deps}")
    endif()

    if (bazel_library__item_deps)
        string(REPLACE ";" ", " bazel_library_deps "${bazel_library__item_deps}")
    endif()

    get_bazel_library(
        OUTPUT_VARIABLE bazel_library
        NAME            ${library_NAME}
        PKGNAME         ${library_PKGNAME}
        RULE            ${library_RULE}
        LINKNAME        ${library_LINKNAME}
        INCLUDES        ${library_INCLUDES}
        LOCAL_INCLUDES  ${library_LOCAL_INCLUDES}
        SOURCES         ${library_SOURCES}
        COPTS           ${library_COPTS}
        LINKOPTS        ${library_LINKOPTS}
        DEFINES         ${library_DEFINES}
        LOCAL_DEFINES   ${library_LOCAL_DEFINES}
        DEPS            ${library_DEPS}
        ${library_LINKSHARED}
        ${library_LINKSTATIC}
        ${library_ALWAYSLINK}
    )

    if (bazel_library_deps)
        set(bazel_library "${bazel_library}, ${bazel_library_deps}")
    endif()

    set(${library_OUTPUT_VARIABLE} "${bazel_library}" PARENT_SCOPE)
    set(${generated_list_var} ${${generated_list_var}} PARENT_SCOPE)
endfunction()

function(generate_bazel_library)
    set(options)
    set(oneValueArgs
        OUTPUT_VARIABLE
    )
    set(multiValueArgs)
    cmake_parse_arguments(PARSE_ARGV 0 library
        "${options}" "${oneValueArgs}" "${multiValueArgs}"
    )
    unset(generated_list)
    _generate_bazel_library(generated_list ${ARGV})
    set(${library_OUTPUT_VARIABLE} "${${library_OUTPUT_VARIABLE}}" PARENT_SCOPE)
endfunction()