# SPDX-FileCopyrightText: 2026 BESA developers
# SPDX-FileCopyrightText: 2026 kprof developers
#
# SPDX-License-Identifier: Apache-2.0
include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/internal.cmake")

# PROJECT_DEVTOOLS is the project-wide instrumentation/developer-tool selection.  The supported set
# is owned by BESA: projects choose from it but never redeclare BESA's capabilities.  Updating the
# vendored BESA modules can therefore make a new devtool available without changing project CMake.
set(_BESA_SUPPORTED_DEVTOOLS format linting coverage surrogate asan lsan ubsan)

# Parse the named callback contract used by project-defined devtool constraints.
#
# A callback should begin with:
#
#   besa_devtool_constraint_arguments_parse(PREFIX ARG ARGUMENTS ${ARGN})
#
# It reads ARG_DEVTOOLS and writes TRUE/FALSE to ${ARG_OUTPUT_VARIABLE} and an optional diagnostic to
# ${ARG_ERROR_VARIABLE}, both in PARENT_SCOPE.
function(besa_devtool_constraint_arguments_parse)
  cmake_parse_arguments(ARG "" "PREFIX" "ARGUMENTS" ${ARGN})
  _besa_require_no_unparsed(
    "besa_devtool_constraint_arguments_parse" "${ARG_UNPARSED_ARGUMENTS}"
  )
  _besa_require_value("besa_devtool_constraint_arguments_parse" "PREFIX" "${ARG_PREFIX}")

  cmake_parse_arguments(PARSED "" "OUTPUT_VARIABLE;ERROR_VARIABLE" "DEVTOOLS" ${ARG_ARGUMENTS})
  _besa_require_no_unparsed("devtool constraint callback" "${PARSED_UNPARSED_ARGUMENTS}")
  _besa_require_value(
    "devtool constraint callback" "OUTPUT_VARIABLE" "${PARSED_OUTPUT_VARIABLE}"
  )
  _besa_require_value(
    "devtool constraint callback" "ERROR_VARIABLE" "${PARSED_ERROR_VARIABLE}"
  )

  set("${ARG_PREFIX}_OUTPUT_VARIABLE" "${PARSED_OUTPUT_VARIABLE}" PARENT_SCOPE)
  set("${ARG_PREFIX}_ERROR_VARIABLE" "${PARSED_ERROR_VARIABLE}" PARENT_SCOPE)
  set("${ARG_PREFIX}_DEVTOOLS" "${PARSED_DEVTOOLS}" PARENT_SCOPE)
endfunction()

function(besa_register_devtool_constraint)
  _besa_require_config_open("besa_register_devtool_constraint")
  cmake_parse_arguments(ARG "" "FUNCTION" "" ${ARGN})
  _besa_require_no_unparsed("besa_register_devtool_constraint" "${ARG_UNPARSED_ARGUMENTS}")
  _besa_require_value("besa_register_devtool_constraint" "FUNCTION" "${ARG_FUNCTION}")
  if(NOT COMMAND "${ARG_FUNCTION}")
    _besa_fatal(
      "besa_register_devtool_constraint"
      "constraint function '${ARG_FUNCTION}' does not exist"
    )
  endif()
  _besa_append_unique(BESA_DEVTOOL_CONSTRAINTS "${ARG_FUNCTION}" "besa_register_devtool_constraint")
endfunction()

function(_besa_devtools_resolve OUTPUT_VARIABLE)
  if(NOT DEFINED PROJECT_DEVTOOLS)
    set(PROJECT_DEVTOOLS "none" CACHE STRING "List of project instrumentation/devtools")
  endif()

  set(_enabled)
  set(_seen)
  foreach(_devtool IN LISTS PROJECT_DEVTOOLS)
    if("${_devtool}" STREQUAL "")
      continue()
    endif()
    if("${_devtool}" IN_LIST _seen)
      _besa_fatal("besa_configure_complete" "devtool '${_devtool}' is specified more than once")
    endif()
    list(APPEND _seen "${_devtool}")
  endforeach()

  if("none" IN_LIST _seen)
    list(LENGTH _seen _count)
    if(NOT _count EQUAL 1)
      _besa_fatal("besa_configure_complete" "PROJECT_DEVTOOLS value 'none' is mutually exclusive")
    endif()
  else()
    foreach(_devtool IN LISTS _seen)
      if(NOT "${_devtool}" IN_LIST _BESA_SUPPORTED_DEVTOOLS)
        _besa_fatal(
          "besa_configure_complete"
          "unknown devtool '${_devtool}'. Allowed values are: ${_BESA_SUPPORTED_DEVTOOLS}"
        )
      endif()
      list(APPEND _enabled "${_devtool}")
    endforeach()
  endif()

  set_property(GLOBAL PROPERTY BESA_ENABLED_DEVTOOLS "${_enabled}")
  set(BESA_ENABLED_DEVTOOLS "${_enabled}" CACHE INTERNAL "Resolved BESA devtools")

  foreach(_devtool IN LISTS _BESA_SUPPORTED_DEVTOOLS)
    _besa_normalize_name("${_devtool}" _normalized)
    if("${_devtool}" IN_LIST _enabled)
      set(_value TRUE)
    else()
      set(_value FALSE)
    endif()
    set("PROJECT_DEVTOOLS_${_normalized}" "${_value}" CACHE INTERNAL "Resolved BESA devtool")
  endforeach()

  set("${OUTPUT_VARIABLE}" "${_enabled}" PARENT_SCOPE)
endfunction()

function(_besa_run_devtool_constraints ENABLED_DEVTOOLS)
  get_property(_constraints GLOBAL PROPERTY BESA_DEVTOOL_CONSTRAINTS)
  foreach(_constraint IN LISTS _constraints)
    set(_valid FALSE)
    set(_error "")
    cmake_language(
      CALL "${_constraint}"
      OUTPUT_VARIABLE _valid
      ERROR_VARIABLE _error
      DEVTOOLS ${ENABLED_DEVTOOLS}
    )

    if(NOT _valid)
      if(_error)
        _besa_fatal("devtool constraint '${_constraint}'" "${_error}")
      else()
        _besa_fatal("devtool constraint '${_constraint}'" "constraint rejected the devtool set")
      endif()
    endif()
  endforeach()
endfunction()

# Create compiler/link policy targets only after all configuration constraints have succeeded and
# toolchain-* languages have been enabled.  This keeps rejected configurations side-effect free.
function(_besa_devtools_activate)
  get_property(_activated GLOBAL PROPERTY BESA_DEVTOOLS_ACTIVATED)
  if(_activated)
    return()
  endif()
  if(PROJECT_DEVTOOLS_ASAN)
    include("${CMAKE_CURRENT_FUNCTION_LIST_DIR}/asan.cmake")
  endif()
  if(PROJECT_DEVTOOLS_LSAN)
    include("${CMAKE_CURRENT_FUNCTION_LIST_DIR}/lsan.cmake")
  endif()
  if(PROJECT_DEVTOOLS_UBSAN)
    include("${CMAKE_CURRENT_FUNCTION_LIST_DIR}/ubsan.cmake")
  endif()
  if(PROJECT_DEVTOOLS_COVERAGE)
    include("${CMAKE_CURRENT_FUNCTION_LIST_DIR}/coverage.cmake")
  endif()
  set_property(GLOBAL PROPERTY BESA_DEVTOOLS_ACTIVATED TRUE)
endfunction()

function(_besa_target_apply_devtools TARGET_NAME)
  if(PROJECT_DEVTOOLS_ASAN)
    target_link_libraries("${TARGET_NAME}" PRIVATE $<BUILD_INTERFACE:besa::asan>)
  endif()
  if(PROJECT_DEVTOOLS_LSAN)
    target_link_libraries("${TARGET_NAME}" PRIVATE $<BUILD_INTERFACE:besa::lsan>)
  endif()
  if(PROJECT_DEVTOOLS_UBSAN)
    target_link_libraries("${TARGET_NAME}" PRIVATE $<BUILD_INTERFACE:besa::ubsan>)
  endif()
  if(PROJECT_DEVTOOLS_COVERAGE)
    target_link_libraries("${TARGET_NAME}" PRIVATE $<BUILD_INTERFACE:besa::coverage>)
  endif()
endfunction()

function(_besa_devtools_finalize)
  if(NOT BUILD_TESTING)
    return()
  endif()

  if(PROJECT_DEVTOOLS_FORMAT)
    besa_add_clang_format(NAME instrumentation.format.t LABELS instrumentation format)
  endif()

  if(PROJECT_DEVTOOLS_LINTING)
    besa_add_clang_tidy(NAME instrumentation.linting.t LABELS instrumentation linting)
  endif()

  if(PROJECT_DEVTOOLS_COVERAGE)
    _besa_coverage_finalize()
  endif()
endfunction()
