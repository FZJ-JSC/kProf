# --------------------------------------------------------------------------------------------------
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 besa developers
# --------------------------------------------------------------------------------------------------
# Check public headers by compiling generated surrogate translation units.
#
# Each public header is included from its own generated translation unit.
# The compiler language comes from the registered semantic source type; for
# manually maintained targets, it can come from a single enabled CMake language.
# Checks register a CTest build invocation, not a runtime executable. Discovery
# is deferred until the end of project configuration to see later include roots.
# A passing surrogate check is useful but does not guarantee every possible
# header combination or generator-expression context is valid.

include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/internal.cmake")

# --------------------------------------------------------------------------------------------------
# Public API
# --------------------------------------------------------------------------------------------------

# Register deferred checks that compile each public header independently.
#   besa_surrogate_check(TARGET <library> [EXPECT PASS|FAIL] [LABELS ...])
# CMake DEFER allows subsequent directory registrations to contribute headers.
# A generated CTest builds a surrogate target; EXPECT FAIL sets WILL_FAIL.
function(besa_surrogate_check)
  _besa_require_config_complete("besa_surrogate_check")
  cmake_parse_arguments(ARG "" "TARGET;EXPECT" "LABELS" ${ARGN})
  _besa_require_no_unparsed("besa_surrogate_check" "${ARG_UNPARSED_ARGUMENTS}")
  _besa_require_value("besa_surrogate_check" "TARGET" "${ARG_TARGET}")
  if(NOT ARG_EXPECT)
    set(ARG_EXPECT PASS)
  endif()
  if(NOT ARG_EXPECT STREQUAL "PASS" AND NOT ARG_EXPECT STREQUAL "FAIL")
    _besa_fatal("besa_surrogate_check" "EXPECT must be PASS or FAIL")
  endif()
  if(NOT ARG_LABELS)
    set(ARG_LABELS instrumentation surrogate)
  endif()
  cmake_language(EVAL CODE
    "cmake_language(DEFER DIRECTORY [[${PROJECT_SOURCE_DIR}]] CALL _besa_surrogate_check_impl [[${ARG_TARGET}]] [[${ARG_LABELS}]] [[${ARG_EXPECT}]])"
  )
endfunction()

# --------------------------------------------------------------------------------------------------
# Internal implementation
# --------------------------------------------------------------------------------------------------

# Generate a source file using the associated semantic language, not the
# header's extension. Preserve the header extension in the generated filename
# so foo.h and foo.hpp never overwrite each other.
function(_besa_surrogate_generate_source HEADER INCLUDE_ROOT DESTINATION LANGUAGE OUTPUT_VARIABLE)
  if(LANGUAGE STREQUAL "C")
    set(_extension c)
  elseif(LANGUAGE STREQUAL "CXX")
    set(_extension cpp)
  elseif(LANGUAGE STREQUAL "CUDA")
    set(_extension cu)
  elseif(LANGUAGE STREQUAL "HIP")
    set(_extension hip)
  else()
    _besa_fatal("besa_surrogate_check"
    "cannot generate a header compilation check for language '${LANGUAGE}'")
endif()
file(RELATIVE_PATH _relative "${INCLUDE_ROOT}" "${HEADER}")
set(_source "${DESTINATION}/${_relative}.${_extension}")
get_filename_component(_directory "${_source}" DIRECTORY)
file(MAKE_DIRECTORY "${_directory}")
# REUSE-IgnoreStart
file(WRITE "${_source}"
  "// --------------------------------------------------------------------------------------------------\n"
  "// SPDX-License-Identifier: Apache-2.0\n"
  "// SPDX-FileCopyrightText: 2026 ${PROJECT_NAME} developers\n"
  "// --------------------------------------------------------------------------------------------------\n"
  "#include <${_relative}>\n")
# REUSE-IgnoreEnd
set("${OUTPUT_VARIABLE}" "${_source}" PARENT_SCOPE)
endfunction()

# For BESA-managed include roots, select the language registered by the
# corresponding besa_add_directory(... TYPE ...). For manually maintained
# targets, use CMake's configured language only if there is one unambiguous
# compilable language. Do not inspect the header name to make the decision.
function(_besa_surrogate_header_language TARGET_NAME INCLUDE_ROOT OUTPUT_VARIABLE)
  get_target_property(_roots "${TARGET_NAME}" BESA_INTERNAL_HEADER_ROOTS)
  get_target_property(_languages "${TARGET_NAME}" BESA_INTERNAL_HEADER_LANGUAGES)
  if(_roots)
    list(LENGTH _roots _count)
    math(EXPR _last "${_count} - 1")
    foreach(_index RANGE 0 ${_last})
      list(GET _roots ${_index} _root)
      if(_root STREQUAL INCLUDE_ROOT)
        list(GET _languages ${_index} _language)
        set("${OUTPUT_VARIABLE}" "${_language}" PARENT_SCOPE)
        return()
      endif()
    endforeach()
  endif()

  get_target_property(_language "${TARGET_NAME}" LINKER_LANGUAGE)
  if(NOT _language)
    get_property(_enabled GLOBAL PROPERTY ENABLED_LANGUAGES)
    set(_supported)
    foreach(_candidate IN ITEMS C CXX CUDA HIP)
      if(_candidate IN_LIST _enabled)
        list(APPEND _supported "${_candidate}")
      endif()
    endforeach()
    list(LENGTH _supported _count)
    if(_count EQUAL 1)
      list(GET _supported 0 _language)
    else()
      _besa_fatal("besa_surrogate_check"
      "cannot determine the language for include root '${INCLUDE_ROOT}' of target '${TARGET_NAME}'; use besa_add_directory with a declared TYPE")
  endif()
endif()
set("${OUTPUT_VARIABLE}" "${_language}" PARENT_SCOPE)
endfunction()

# Read build-tree include directories from the target, ignoring opaque
# generator expressions and install-only include paths.
function(_besa_surrogate_collect_includes TARGET_NAME OUTPUT_VARIABLE)
  set(_directories)
  foreach(_property INCLUDE_DIRECTORIES INTERFACE_INCLUDE_DIRECTORIES)
    get_target_property(_values "${TARGET_NAME}" "${_property}")
    if(NOT _values OR _values STREQUAL "_values-NOTFOUND")
      continue()
    endif()
    foreach(_value IN LISTS _values)
      if(_value MATCHES "^\\$<BUILD_INTERFACE:(.*)>$")
        set(_value "${CMAKE_MATCH_1}")
      elseif(_value MATCHES "^\\$<")
        continue()
      endif()
      if(NOT IS_ABSOLUTE "${_value}")
        file(REAL_PATH "${_value}" _value BASE_DIRECTORY "${PROJECT_SOURCE_DIR}")
      endif()
      if(IS_DIRECTORY "${_value}")
        list(APPEND _directories "${_value}")
      endif()
    endforeach()
  endforeach()
  list(REMOVE_DUPLICATES _directories)
  set("${OUTPUT_VARIABLE}" "${_directories}" PARENT_SCOPE)
endfunction()

# At deferred configure time, discover public headers and register one
# compilation target plus a CTest invocation to build it.
function(_besa_surrogate_check_impl TARGET_NAME LABELS EXPECT)
  if(NOT TARGET "${TARGET_NAME}")
    _besa_fatal("besa_surrogate_check" "target '${TARGET_NAME}' no longer exists")
  endif()

  _besa_surrogate_collect_includes("${TARGET_NAME}" _includes)
  if(NOT _includes)
    return()
  endif()

  set(_surrogate_target "surrogate.${TARGET_NAME}.t")
  if(TARGET "${_surrogate_target}")
    return()
  endif()

  add_library("${_surrogate_target}" EXCLUDE_FROM_ALL)
  target_link_libraries("${_surrogate_target}" PRIVATE "${TARGET_NAME}")
  set(_destination "${PROJECT_BINARY_DIR}/surrogate/${TARGET_NAME}")

  foreach(_include IN LISTS _includes)
    _besa_surrogate_header_language("${TARGET_NAME}" "${_include}" _language)
    file(GLOB_RECURSE _headers LIST_DIRECTORIES FALSE CONFIGURE_DEPENDS "${_include}/*")
    foreach(_header IN LISTS _headers)
      _besa_surrogate_generate_source(
      "${_header}" "${_include}" "${_destination}" "${_language}" _source)
    target_sources("${_surrogate_target}" PRIVATE "${_source}")
  endforeach()
endforeach()

add_test(
  NAME "${_surrogate_target}"
  COMMAND "${CMAKE_COMMAND}" --build "${PROJECT_BINARY_DIR}"
  --target "${_surrogate_target}" --config $<CONFIG> --verbose
)
set_tests_properties("${_surrogate_target}" PROPERTIES LABELS "${LABELS}")
if(EXPECT STREQUAL "FAIL")
  set_tests_properties("${_surrogate_target}" PROPERTIES WILL_FAIL TRUE)
endif()
endfunction()
