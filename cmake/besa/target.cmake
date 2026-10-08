# SPDX-FileCopyrightText: 2026 BESA developers
# SPDX-FileCopyrightText: 2026 kprof developers
#
# SPDX-License-Identifier: Apache-2.0
include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/internal.cmake")

function(_besa_register_install_target TARGET_NAME)
  get_property(_targets GLOBAL PROPERTY BESA_INSTALL_TARGETS)
  if(NOT "${TARGET_NAME}" IN_LIST _targets)
    set_property(GLOBAL APPEND PROPERTY BESA_INSTALL_TARGETS "${TARGET_NAME}")
  endif()
endfunction()

function(_besa_target_common TARGET_NAME)
  _besa_devtools_activate()
  # ``projectdocs`` is a BESA/Doxygen alias used in C++ documentation comments. Clang otherwise
  # diagnoses it as an unknown documentation command when -Wdocumentation is enabled (for example
  # by the ``everything`` warning policy). Register only the custom command instead of suppressing
  # unknown-command diagnostics globally, so misspelled standard Doxygen commands still warn.
  target_compile_options(
    "${TARGET_NAME}" PRIVATE
    $<$<COMPILE_LANG_AND_ID:CXX,Clang,AppleClang>:-fcomment-block-commands=projectdocs>
  )

  _besa_target_apply_warning_policy("${TARGET_NAME}")
  _besa_target_apply_devtools("${TARGET_NAME}")
endfunction()

# Create a project library using BESA's standard target policy.  A leading `lib` belongs to the
# logical CMake target name but is stripped from OUTPUT_NAME, so `libvorlage` produces the natural
# file name libvorlage.so/libvorlage.a while retaining an unambiguous target name.
function(besa_add_library)
  _besa_require_config_complete("besa_add_library")
  cmake_parse_arguments(
    ARG
    ""
    "NAME;TYPE;INSTALL"
    "SOURCES;HEADERS;PUBLIC_INCLUDE_DIRECTORIES;PRIVATE_INCLUDE_DIRECTORIES;LINK_LIBRARIES"
    ${ARGN}
  )
  _besa_require_no_unparsed("besa_add_library" "${ARG_UNPARSED_ARGUMENTS}")
  _besa_require_value("besa_add_library" "NAME" "${ARG_NAME}")

  if(NOT ARG_TYPE)
    set(ARG_TYPE "")
  endif()
  if(NOT DEFINED ARG_INSTALL OR ARG_INSTALL STREQUAL "")
    set(ARG_INSTALL TRUE)
  endif()

  if(ARG_TYPE)
    add_library("${ARG_NAME}" "${ARG_TYPE}")
  else()
    add_library("${ARG_NAME}")
  endif()

  if(ARG_NAME MATCHES "^lib(.+)$")
    set_target_properties("${ARG_NAME}" PROPERTIES OUTPUT_NAME "${CMAKE_MATCH_1}")
  endif()

  if(NOT TARGET "${PROJECT_NAME}::${ARG_NAME}")
    add_library("${PROJECT_NAME}::${ARG_NAME}" ALIAS "${ARG_NAME}")
  endif()

  if(ARG_SOURCES)
    target_sources("${ARG_NAME}" PRIVATE ${ARG_SOURCES})
  endif()
  if(ARG_PUBLIC_INCLUDE_DIRECTORIES)
    target_include_directories(
      "${ARG_NAME}" PUBLIC
      $<BUILD_INTERFACE:${ARG_PUBLIC_INCLUDE_DIRECTORIES}>
      $<INSTALL_INTERFACE:include>
    )
  endif()
  if(ARG_PRIVATE_INCLUDE_DIRECTORIES)
    target_include_directories("${ARG_NAME}" PRIVATE ${ARG_PRIVATE_INCLUDE_DIRECTORIES})
  endif()
  if(ARG_HEADERS)
    # BASE_DIRS is supplied by besa_add_subdirectory; direct callers can still attach headers as
    # ordinary sources when they do not use a conventional public include tree.
    target_sources("${ARG_NAME}" PRIVATE ${ARG_HEADERS})
  endif()
  if(ARG_LINK_LIBRARIES)
    target_link_libraries("${ARG_NAME}" PRIVATE ${ARG_LINK_LIBRARIES})
  endif()

  _besa_target_common("${ARG_NAME}")

  if(ARG_INSTALL)
    _besa_register_install_target("${ARG_NAME}")
  endif()
  if(BUILD_TESTING AND PROJECT_DEVTOOLS_SURROGATE)
    besa_surrogate_check(TARGET "${ARG_NAME}" LABELS instrumentation surrogate)
  endif()
endfunction()

function(besa_add_executable)
  _besa_require_config_complete("besa_add_executable")
  cmake_parse_arguments(ARG "" "NAME;INSTALL" "SOURCES;LINK_LIBRARIES" ${ARGN})
  _besa_require_no_unparsed("besa_add_executable" "${ARG_UNPARSED_ARGUMENTS}")
  _besa_require_value("besa_add_executable" "NAME" "${ARG_NAME}")
  if(NOT DEFINED ARG_INSTALL OR ARG_INSTALL STREQUAL "")
    set(ARG_INSTALL TRUE)
  endif()

  add_executable("${ARG_NAME}" ${ARG_SOURCES})
  if(ARG_LINK_LIBRARIES)
    target_link_libraries("${ARG_NAME}" PRIVATE ${ARG_LINK_LIBRARIES})
  endif()
  _besa_target_common("${ARG_NAME}")
  if(ARG_INSTALL)
    _besa_register_install_target("${ARG_NAME}")
  endif()
endfunction()
