# SPDX-FileCopyrightText: 2026 BESA developers
# SPDX-FileCopyrightText: 2026 kprof developers
#
# SPDX-License-Identifier: Apache-2.0
include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/internal.cmake")

function(besa_add_clang_tidy)
  _besa_require_config_complete("besa_add_clang_tidy")
  cmake_parse_arguments(ARG "" "NAME" "LABELS;ARGUMENTS" ${ARGN})
  _besa_require_no_unparsed("besa_add_clang_tidy" "${ARG_UNPARSED_ARGUMENTS}")
  _besa_require_value("besa_add_clang_tidy" "NAME" "${ARG_NAME}")

  if(NOT CMAKE_EXPORT_COMPILE_COMMANDS)
    _besa_fatal(
      "besa_add_clang_tidy"
      "CMAKE_EXPORT_COMPILE_COMMANDS must be ON when linting is enabled"
    )
  endif()

  find_program(BESA_RUN_CLANG_TIDY run-clang-tidy REQUIRED)
  find_program(BESA_CLANG_TIDY clang-tidy REQUIRED)

  set(_command
    "${BESA_RUN_CLANG_TIDY}"
    -clang-tidy-binary "${BESA_CLANG_TIDY}"
    -p "${PROJECT_BINARY_DIR}"
  )
  list(APPEND _command ${ARG_ARGUMENTS})

  add_test(NAME "${ARG_NAME}" COMMAND ${_command} WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}")
  if(ARG_LABELS)
    set_property(TEST "${ARG_NAME}" PROPERTY LABELS "${ARG_LABELS}")
  endif()
endfunction()
