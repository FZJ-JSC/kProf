# --------------------------------------------------------------------------------------------------
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 besa developers
# --------------------------------------------------------------------------------------------------
# Discover runtime and compilation-only tests from semantic directories.
#
# CTest names are derived from test file paths. Selected feature spaces, test
# modes and devtools are read from the finalized BESA configuration. Test file
# suffixes control expected failure/disabled properties, while optional extra
# source directories support multi-file tests. All selection paths use the same
# internal predicate.

include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/internal.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/keyso.cmake")

# --------------------------------------------------------------------------------------------------
# Public API
# --------------------------------------------------------------------------------------------------

# Discover runnable tests beneath NAME using the .t.* file convention.
#   besa_test_add_directory(NAME <dir> [PREFIX <prefix>] [CONDITION <space>]
#                           [MODES ...] [DEVTOOLS ...] [TARGET_LIST ...]
#                           [LABELS ...] [CMDLINE ...] [COVERAGE_GROUP <group>])
function(besa_test_add_directory)
  _besa_require_config_complete("besa_test_add_directory")
  cmake_parse_arguments(
    ARG
    ""
    "NAME;PREFIX;COVERAGE_GROUP;CONDITION"
    "LABELS;CMDLINE;TARGET_LIST;MODES;DEVTOOLS"
    ${ARGN}
  )
  _besa_require_no_unparsed("besa_test_add_directory" "${ARG_UNPARSED_ARGUMENTS}")
  _besa_require_value("besa_test_add_directory" "NAME" "${ARG_NAME}")

  _besa_test_directory_selected("${ARG_CONDITION}" "${ARG_MODES}" "${ARG_DEVTOOLS}" _selected)
  if(NOT _selected)
    return()
  endif()

  set(_root "${CMAKE_CURRENT_SOURCE_DIR}/${ARG_NAME}")
  if(NOT IS_DIRECTORY "${_root}")
    _besa_fatal("besa_test_add_directory" "directory does not exist: ${_root}")
  endif()

  file(GLOB_RECURSE _sources LIST_DIRECTORIES FALSE RELATIVE "${_root}" CONFIGURE_DEPENDS "${_root}/*")
  foreach(_relative IN LISTS _sources)
    _besa_test_source_is_test("${_relative}" _is_test)
    if(NOT _is_test)
      continue()
    endif()

    _besa_test_target_name("${ARG_PREFIX}" "${_relative}" _target)
    set(_source "${_root}/${_relative}")
    besa_add_executable(
      NAME "${_target}"
      INSTALL FALSE
      SOURCES "${_source}"
      LINK_LIBRARIES ${ARG_TARGET_LIST}
    )

    # Optional multi-file companion directory.  For foo.t.cpp the companion path is foo/.
    string(REGEX REPLACE "\\.t\\.[^.]+$" "" _companion "${_relative}")
    if(IS_DIRECTORY "${_root}/${_companion}")
      file(GLOB_RECURSE _extra LIST_DIRECTORIES FALSE CONFIGURE_DEPENDS "${_root}/${_companion}/*")
      target_sources("${_target}" PRIVATE ${_extra})
    endif()

    add_test(NAME "${_target}" COMMAND $<TARGET_FILE:${_target}> ${ARG_CMDLINE})
    _besa_test_apply_properties("${_target}" "${ARG_LABELS}")

    if(BUILD_DEVTOOLS_COVERAGE AND ARG_COVERAGE_GROUP)
      _besa_coverage_register_test("${ARG_COVERAGE_GROUP}" "${_target}" "${_target}")
    endif()
  endforeach()
endfunction()

# Register compile-only tests discovered under a semantic directory.
#   besa_compile_test_add_directory(NAME <dir> [PREFIX <prefix>] ...)
function(besa_compile_test_add_directory)
  _besa_require_config_complete("besa_compile_test_add_directory")
  cmake_parse_arguments(ARG "" "NAME;PREFIX;CONDITION" "LABELS;TARGET_LIST;MODES;DEVTOOLS" ${ARGN})
  _besa_require_no_unparsed("besa_compile_test_add_directory" "${ARG_UNPARSED_ARGUMENTS}")
  _besa_require_value("besa_compile_test_add_directory" "NAME" "${ARG_NAME}")

  _besa_test_directory_selected("${ARG_CONDITION}" "${ARG_MODES}" "${ARG_DEVTOOLS}" _selected)
  if(NOT _selected)
    return()
  endif()

  set(_root "${CMAKE_CURRENT_SOURCE_DIR}/${ARG_NAME}")
  file(GLOB_RECURSE _sources LIST_DIRECTORIES FALSE RELATIVE "${_root}" CONFIGURE_DEPENDS "${_root}/*")
  foreach(_relative IN LISTS _sources)
    _besa_test_source_is_test("${_relative}" _is_test)
    if(NOT _is_test)
      continue()
    endif()
    _besa_test_target_name("${ARG_PREFIX}" "${_relative}" _target)
    add_executable("${_target}" EXCLUDE_FROM_ALL "${_root}/${_relative}")
    if(ARG_TARGET_LIST)
      target_link_libraries("${_target}" PRIVATE ${ARG_TARGET_LIST})
    endif()
    _besa_target_common("${_target}")
    add_test(
      NAME "${_target}"
      COMMAND "${CMAKE_COMMAND}" --build "${PROJECT_BINARY_DIR}" --target "${_target}" --config $<CONFIG>
    )
    _besa_test_apply_properties("${_target}" "${ARG_LABELS}")
  endforeach()
endfunction()

# --------------------------------------------------------------------------------------------------
# Internal implementation
# --------------------------------------------------------------------------------------------------

function(_besa_test_target_name PREFIX RELATIVE_SOURCE OUTPUT_VARIABLE)
  string(REGEX REPLACE "\\.[^.]+$" "" _name "${RELATIVE_SOURCE}")
  string(REPLACE "/" "." _name "${_name}")
  if(PREFIX)
    set(_name "${PREFIX}.${_name}")
  endif()
  set("${OUTPUT_VARIABLE}" "${_name}" PARENT_SCOPE)
endfunction()

function(_besa_test_source_is_test SOURCE OUTPUT_VARIABLE)
  if(SOURCE MATCHES "(^|/)?.*\\.t\\.(c|cc|cpp|cxx|cu)$")
    set("${OUTPUT_VARIABLE}" TRUE PARENT_SCOPE)
  else()
    set("${OUTPUT_VARIABLE}" FALSE PARENT_SCOPE)
  endif()
endfunction()

# Both executable and compile-only directories use the same feature, mode, and devtool
# selection rules. Keep the evaluation order: an inactive feature condition skips the
# remaining checks, while a selected directory still validates its mode/devtool names.
function(_besa_test_directory_selected CONDITION MODES DEVTOOLS OUTPUT_VARIABLE)
  if(CONDITION)
    get_property(_features GLOBAL PROPERTY BESA_ENABLED_FEATURES)
    _besa_keyso_matches("${CONDITION}" "${_features}" _selected)
    if(NOT _selected)
      set("${OUTPUT_VARIABLE}" FALSE PARENT_SCOPE)
      return()
    endif()
  endif()

  besa_test_modes_check(OUTPUT_VARIABLE _mode_selected MODES ${MODES})
  if(DEVTOOLS)
    besa_devtools_check(OUTPUT_VARIABLE _devtool_selected DEVTOOLS ${DEVTOOLS})
  else()
    set(_devtool_selected TRUE)
  endif()
  if(_mode_selected AND _devtool_selected)
    set("${OUTPUT_VARIABLE}" TRUE PARENT_SCOPE)
  else()
    set("${OUTPUT_VARIABLE}" FALSE PARENT_SCOPE)
  endif()
endfunction()

# The test-name suffix determines CTest expectations for both kinds of tests.
function(_besa_test_apply_properties TARGET_NAME LABELS)
  if(LABELS)
    set_property(TEST "${TARGET_NAME}" PROPERTY LABELS "${LABELS}")
  endif()
  if(TARGET_NAME MATCHES "\\.fail\\.t$")
    set_tests_properties("${TARGET_NAME}" PROPERTIES WILL_FAIL TRUE)
  endif()
  if(TARGET_NAME MATCHES "\\.disabled(\\.fail)?\\.t$")
    set_tests_properties("${TARGET_NAME}" PROPERTIES DISABLED TRUE)
  endif()
endfunction()
