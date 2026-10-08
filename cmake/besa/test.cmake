# SPDX-FileCopyrightText: 2026 BESA developers
# SPDX-FileCopyrightText: 2026 kprof developers
#
# SPDX-License-Identifier: Apache-2.0
include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/internal.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/keyso.cmake")

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

# Discover executable tests below a directory.  Files ending in `.t.<ext>` are expected to pass;
# `.fail.t.<ext>` are expected to fail; and `.disabled.t.<ext>` are built but disabled in CTest.
# Companion directories named after a test source with its `.t.<ext>` suffix removed are added as
# extra sources, preserving the useful multi-file test convention from the original BESA helpers.
function(besa_test_add_directory)
  _besa_require_config_complete("besa_test_add_directory")
  cmake_parse_arguments(
    ARG
    ""
    "NAME;PREFIX;COVERAGE_GROUP;CONDITION"
    "LABELS;CMDLINE;TARGET_LIST;MODES"
    ${ARGN}
  )
  _besa_require_no_unparsed("besa_test_add_directory" "${ARG_UNPARSED_ARGUMENTS}")
  _besa_require_value("besa_test_add_directory" "NAME" "${ARG_NAME}")

  if(ARG_CONDITION)
    get_property(_features GLOBAL PROPERTY BESA_ENABLED_FEATURES)
    _besa_keyso_matches("${ARG_CONDITION}" "${_features}" _selected)
    if(NOT _selected)
      return()
    endif()
  endif()
  besa_test_modes_check(OUTPUT_VARIABLE _mode_selected MODES ${ARG_MODES})
  if(NOT _mode_selected)
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
    if(ARG_LABELS)
      set_property(TEST "${_target}" PROPERTY LABELS "${ARG_LABELS}")
    endif()
    if(_target MATCHES "\\.fail\\.t$")
      set_tests_properties("${_target}" PROPERTIES WILL_FAIL TRUE)
    endif()
    if(_target MATCHES "\\.disabled(\\.fail)?\\.t$")
      set_tests_properties("${_target}" PROPERTIES DISABLED TRUE)
    endif()

    if(PROJECT_DEVTOOLS_COVERAGE AND ARG_COVERAGE_GROUP)
      _besa_coverage_register_test("${ARG_COVERAGE_GROUP}" "${_target}" "${_target}")
    endif()
  endforeach()
endfunction()

# Discover compile-only checks.  Every matching test becomes EXCLUDE_FROM_ALL and CTest invokes the
# build tool for that target.  `.fail.t.<ext>` therefore expresses a target which must fail to build.
function(besa_compile_test_add_directory)
  _besa_require_config_complete("besa_compile_test_add_directory")
  cmake_parse_arguments(ARG "" "NAME;PREFIX;CONDITION" "LABELS;TARGET_LIST;MODES" ${ARGN})
  _besa_require_no_unparsed("besa_compile_test_add_directory" "${ARG_UNPARSED_ARGUMENTS}")
  _besa_require_value("besa_compile_test_add_directory" "NAME" "${ARG_NAME}")

  if(ARG_CONDITION)
    get_property(_features GLOBAL PROPERTY BESA_ENABLED_FEATURES)
    _besa_keyso_matches("${ARG_CONDITION}" "${_features}" _selected)
    if(NOT _selected)
      return()
    endif()
  endif()
  besa_test_modes_check(OUTPUT_VARIABLE _mode_selected MODES ${ARG_MODES})
  if(NOT _mode_selected)
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
    if(ARG_LABELS)
      set_property(TEST "${_target}" PROPERTY LABELS "${ARG_LABELS}")
    endif()
    if(_target MATCHES "\\.fail\\.t$")
      set_tests_properties("${_target}" PROPERTIES WILL_FAIL TRUE)
    endif()
    if(_target MATCHES "\\.disabled(\\.fail)?\\.t$")
      set_tests_properties("${_target}" PROPERTIES DISABLED TRUE)
    endif()
  endforeach()
endfunction()
