# SPDX-FileCopyrightText: 2026 BESA developers
# SPDX-FileCopyrightText: 2026 kprof developers
#
# SPDX-License-Identifier: Apache-2.0
include_guard(GLOBAL)

# Internal helpers.  Public BESA functions always use named arguments; small internal helpers may
# use positional arguments because they are implementation details and are never part of a project
# build description.

function(_besa_fatal FUNCTION_NAME TEXT)
  message(FATAL_ERROR "${FUNCTION_NAME}: ${TEXT}")
endfunction()

function(_besa_require_no_unparsed FUNCTION_NAME UNPARSED)
  if(UNPARSED)
    _besa_fatal("${FUNCTION_NAME}" "unknown arguments: ${UNPARSED}")
  endif()
endfunction()

function(_besa_require_value FUNCTION_NAME ARGUMENT_NAME ARGUMENT_VALUE)
  if("${ARGUMENT_VALUE}" STREQUAL "")
    _besa_fatal("${FUNCTION_NAME}" "${ARGUMENT_NAME} is required")
  endif()
endfunction()

function(_besa_require_config_open FUNCTION_NAME)
  get_property(_complete GLOBAL PROPERTY BESA_CONFIGURATION_COMPLETE)
  if(_complete)
    _besa_fatal(
      "${FUNCTION_NAME}"
      "configuration has already been frozen by besa_configure_complete()"
    )
  endif()
endfunction()

function(_besa_require_config_complete FUNCTION_NAME)
  get_property(_complete GLOBAL PROPERTY BESA_CONFIGURATION_COMPLETE)
  if(NOT _complete)
    _besa_fatal(
      "${FUNCTION_NAME}"
      "besa_configure_complete() must be called before this function"
    )
  endif()
endfunction()

function(_besa_normalize_name INPUT OUTPUT_VARIABLE)
  string(TOUPPER "${INPUT}" _value)
  string(REGEX REPLACE "[^A-Z0-9_]" "_" _value "${_value}")
  set("${OUTPUT_VARIABLE}" "${_value}" PARENT_SCOPE)
endfunction()

function(_besa_feature_base_name FEATURE OUTPUT_VARIABLE OUTPUT_NEGATED)
  if("${FEATURE}" MATCHES "^~(.+)$")
    set("${OUTPUT_VARIABLE}" "${CMAKE_MATCH_1}" PARENT_SCOPE)
    set("${OUTPUT_NEGATED}" TRUE PARENT_SCOPE)
  else()
    set("${OUTPUT_VARIABLE}" "${FEATURE}" PARENT_SCOPE)
    set("${OUTPUT_NEGATED}" FALSE PARENT_SCOPE)
  endif()
endfunction()

function(_besa_append_unique GLOBAL_PROPERTY VALUE FUNCTION_NAME)
  get_property(_values GLOBAL PROPERTY "${GLOBAL_PROPERTY}")
  if("${VALUE}" IN_LIST _values)
    _besa_fatal("${FUNCTION_NAME}" "duplicate value '${VALUE}'")
  endif()
  set_property(GLOBAL APPEND PROPERTY "${GLOBAL_PROPERTY}" "${VALUE}")
endfunction()

function(_besa_bool_string VALUE OUTPUT_VARIABLE)
  if(VALUE)
    set("${OUTPUT_VARIABLE}" TRUE PARENT_SCOPE)
  else()
    set("${OUTPUT_VARIABLE}" FALSE PARENT_SCOPE)
  endif()
endfunction()
