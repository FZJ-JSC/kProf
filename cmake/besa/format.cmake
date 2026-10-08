# SPDX-FileCopyrightText: 2026 BESA developers
# SPDX-FileCopyrightText: 2026 kprof developers
#
# SPDX-License-Identifier: Apache-2.0
include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/internal.cmake")

# Add a CTest check which verifies that source files are formatted by clang-format.  Formatting is a
# project instrumentation/devtool and is never attached as a compiler flag to third-party targets.
function(besa_add_clang_format)
  _besa_require_config_complete("besa_add_clang_format")
  cmake_parse_arguments(ARG "" "NAME" "LABELS" ${ARGN})
  _besa_require_no_unparsed("besa_add_clang_format" "${ARG_UNPARSED_ARGUMENTS}")
  _besa_require_value("besa_add_clang_format" "NAME" "${ARG_NAME}")

  find_program(BESA_CLANG_FORMAT clang-format REQUIRED)
  add_test(
    NAME "${ARG_NAME}"
    COMMAND "${CMAKE_COMMAND}"
      "-DCLANG_FORMAT=${BESA_CLANG_FORMAT}"
      "-DSOURCE_DIR=${PROJECT_SOURCE_DIR}"
      -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/format/clang-format.cmake"
    WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
  )
  if(ARG_LABELS)
    set_property(TEST "${ARG_NAME}" PROPERTY LABELS "${ARG_LABELS}")
  endif()
endfunction()
