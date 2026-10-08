# SPDX-FileCopyrightText: 2026 BESA developers
# SPDX-FileCopyrightText: 2026 kprof developers
#
# SPDX-License-Identifier: Apache-2.0
include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/internal.cmake")

# Test modes are project-defined names describing test workflows such as `ci-commit`, `ci-merge`, or
# a site-specific validation mode.  BESA deliberately assigns no special semantics to any mode name.
# Projects declare the available/default modes before besa_configure_complete(); TEST_MODES then acts
# as the same kind of explicit override set as PROJECT_FEATURES, including `~mode` to disable a
# default.  The same underlying mode may appear at most once in TEST_MODES.
function(besa_test_modes_add)
  _besa_require_config_open("besa_test_modes_add")
  cmake_parse_arguments(ARG "" "" "MODES" ${ARGN})
  _besa_require_no_unparsed("besa_test_modes_add" "${ARG_UNPARSED_ARGUMENTS}")
  if(NOT ARG_MODES)
    _besa_fatal("besa_test_modes_add" "MODES requires at least one test mode")
  endif()

  foreach(_mode IN LISTS ARG_MODES)
    if("${_mode}" MATCHES "^~")
      _besa_fatal("besa_test_modes_add" "declared test mode '${_mode}' must not use '~'")
    endif()
    _besa_append_unique(BESA_DECLARED_TEST_MODES "${_mode}" "besa_test_modes_add")
  endforeach()
endfunction()

function(besa_test_modes_default)
  _besa_require_config_open("besa_test_modes_default")
  cmake_parse_arguments(ARG "" "" "MODES" ${ARGN})
  _besa_require_no_unparsed("besa_test_modes_default" "${ARG_UNPARSED_ARGUMENTS}")

  get_property(_declared GLOBAL PROPERTY BESA_DECLARED_TEST_MODES)
  foreach(_mode IN LISTS ARG_MODES)
    if("${_mode}" MATCHES "^~")
      _besa_fatal("besa_test_modes_default" "default test mode '${_mode}' must not use '~'")
    endif()
    if(NOT "${_mode}" IN_LIST _declared)
      _besa_fatal("besa_test_modes_default" "unknown test mode '${_mode}'")
    endif()
    _besa_append_unique(BESA_DEFAULT_TEST_MODES "${_mode}" "besa_test_modes_default")
  endforeach()
endfunction()

# Parse the named callback contract used by project-defined test-mode constraints.
#
# A callback should begin with:
#
#   besa_test_mode_constraint_arguments_parse(PREFIX ARG ARGUMENTS ${ARGN})
#
# It reads ARG_MODES and writes TRUE/FALSE to ${ARG_OUTPUT_VARIABLE} and an optional human-readable
# diagnostic to ${ARG_ERROR_VARIABLE}, both in PARENT_SCOPE.
function(besa_test_mode_constraint_arguments_parse)
  cmake_parse_arguments(ARG "" "PREFIX" "ARGUMENTS" ${ARGN})
  _besa_require_no_unparsed(
    "besa_test_mode_constraint_arguments_parse" "${ARG_UNPARSED_ARGUMENTS}"
  )
  _besa_require_value("besa_test_mode_constraint_arguments_parse" "PREFIX" "${ARG_PREFIX}")

  cmake_parse_arguments(PARSED "" "OUTPUT_VARIABLE;ERROR_VARIABLE" "MODES" ${ARG_ARGUMENTS})
  _besa_require_no_unparsed("test-mode constraint callback" "${PARSED_UNPARSED_ARGUMENTS}")
  _besa_require_value(
    "test-mode constraint callback" "OUTPUT_VARIABLE" "${PARSED_OUTPUT_VARIABLE}"
  )
  _besa_require_value(
    "test-mode constraint callback" "ERROR_VARIABLE" "${PARSED_ERROR_VARIABLE}"
  )

  set("${ARG_PREFIX}_OUTPUT_VARIABLE" "${PARSED_OUTPUT_VARIABLE}" PARENT_SCOPE)
  set("${ARG_PREFIX}_ERROR_VARIABLE" "${PARSED_ERROR_VARIABLE}" PARENT_SCOPE)
  set("${ARG_PREFIX}_MODES" "${PARSED_MODES}" PARENT_SCOPE)
endfunction()

function(besa_register_test_mode_constraint)
  _besa_require_config_open("besa_register_test_mode_constraint")
  cmake_parse_arguments(ARG "" "FUNCTION" "" ${ARGN})
  _besa_require_no_unparsed("besa_register_test_mode_constraint" "${ARG_UNPARSED_ARGUMENTS}")
  _besa_require_value("besa_register_test_mode_constraint" "FUNCTION" "${ARG_FUNCTION}")
  if(NOT COMMAND "${ARG_FUNCTION}")
    _besa_fatal(
      "besa_register_test_mode_constraint"
      "constraint function '${ARG_FUNCTION}' does not exist"
    )
  endif()
  _besa_append_unique(
    BESA_TEST_MODE_CONSTRAINTS "${ARG_FUNCTION}" "besa_register_test_mode_constraint"
  )
endfunction()

function(_besa_resolve_test_modes OUTPUT_VARIABLE)
  get_property(_declared GLOBAL PROPERTY BESA_DECLARED_TEST_MODES)
  get_property(_defaults GLOBAL PROPERTY BESA_DEFAULT_TEST_MODES)

  if(NOT DEFINED TEST_MODES)
    set(TEST_MODES "" CACHE STRING "Explicit project test-mode overrides")
  endif()

  set(_enabled ${_defaults})
  set(_seen)
  foreach(_entry IN LISTS TEST_MODES)
    if("${_entry}" STREQUAL "")
      continue()
    endif()

    _besa_feature_base_name("${_entry}" _mode _negated)
    if("${_mode}" IN_LIST _seen)
      _besa_fatal(
        "besa_configure_complete"
        "test mode '${_mode}' is specified more than once in TEST_MODES"
      )
    endif()
    list(APPEND _seen "${_mode}")

    if(NOT "${_mode}" IN_LIST _declared)
      _besa_fatal(
        "besa_configure_complete"
        "unknown test mode '${_mode}'. Declared test modes are: ${_declared}"
      )
    endif()

    if(_negated)
      list(REMOVE_ITEM _enabled "${_mode}")
    elseif(NOT "${_mode}" IN_LIST _enabled)
      list(APPEND _enabled "${_mode}")
    endif()
  endforeach()

  set("${OUTPUT_VARIABLE}" "${_enabled}" PARENT_SCOPE)
endfunction()

function(_besa_run_test_mode_constraints ENABLED_MODES)
  get_property(_constraints GLOBAL PROPERTY BESA_TEST_MODE_CONSTRAINTS)
  foreach(_constraint IN LISTS _constraints)
    set(_valid FALSE)
    set(_error "")
    cmake_language(
      CALL "${_constraint}"
      OUTPUT_VARIABLE _valid
      ERROR_VARIABLE _error
      MODES ${ENABLED_MODES}
    )

    if(NOT _valid)
      if(_error)
        _besa_fatal("test-mode constraint '${_constraint}'" "${_error}")
      else()
        _besa_fatal(
          "test-mode constraint '${_constraint}'" "constraint rejected the test-mode set"
        )
      endif()
    endif()
  endforeach()
endfunction()

function(_besa_publish_test_modes ENABLED_MODES)
  set_property(GLOBAL PROPERTY BESA_ENABLED_TEST_MODES "${ENABLED_MODES}")
  set(BESA_ENABLED_TEST_MODES "${ENABLED_MODES}" CACHE INTERNAL "Resolved BESA test modes")

  get_property(_declared GLOBAL PROPERTY BESA_DECLARED_TEST_MODES)
  foreach(_mode IN LISTS _declared)
    _besa_normalize_name("${_mode}" _normalized)
    if("${_mode}" IN_LIST ENABLED_MODES)
      set(_value TRUE)
    else()
      set(_value FALSE)
    endif()
    set("PROJECT_TEST_MODE_${_normalized}" "${_value}" CACHE INTERNAL "Resolved BESA test mode")
  endforeach()
endfunction()

# Check whether a test/test-directory which supports MODES participates in the resolved test-mode
# configuration.  MODES uses ANY-OF semantics: one enabled supported mode is enough.  Omitting MODES
# means that the test supports every test mode, which is useful for universally applicable checks.
function(besa_test_modes_check)
  _besa_require_config_complete("besa_test_modes_check")
  cmake_parse_arguments(ARG "" "OUTPUT_VARIABLE" "MODES" ${ARGN})
  _besa_require_no_unparsed("besa_test_modes_check" "${ARG_UNPARSED_ARGUMENTS}")
  _besa_require_value("besa_test_modes_check" "OUTPUT_VARIABLE" "${ARG_OUTPUT_VARIABLE}")

  if(NOT ARG_MODES)
    set("${ARG_OUTPUT_VARIABLE}" TRUE PARENT_SCOPE)
    return()
  endif()

  get_property(_declared GLOBAL PROPERTY BESA_DECLARED_TEST_MODES)
  get_property(_enabled GLOBAL PROPERTY BESA_ENABLED_TEST_MODES)
  set(_seen)
  set(_selected FALSE)
  foreach(_mode IN LISTS ARG_MODES)
    if("${_mode}" MATCHES "^~")
      _besa_fatal(
        "besa_test_modes_check"
        "supported test mode '${_mode}' must not use '~'; negation is only for TEST_MODES overrides"
      )
    endif()
    if("${_mode}" IN_LIST _seen)
      _besa_fatal("besa_test_modes_check" "test mode '${_mode}' appears more than once")
    endif()
    list(APPEND _seen "${_mode}")
    if(NOT "${_mode}" IN_LIST _declared)
      _besa_fatal("besa_test_modes_check" "unknown test mode '${_mode}'")
    endif()
    if("${_mode}" IN_LIST _enabled)
      set(_selected TRUE)
    endif()
  endforeach()

  set("${ARG_OUTPUT_VARIABLE}" "${_selected}" PARENT_SCOPE)
endfunction()
