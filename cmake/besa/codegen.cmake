# SPDX-FileCopyrightText: 2026 BESA developers
# SPDX-FileCopyrightText: 2026 kprof developers
#
# SPDX-License-Identifier: Apache-2.0
include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/workspace.cmake")
if(POLICY CMP0171)
  cmake_policy(SET CMP0171 NEW)
endif()

function(_besa_codegen_initialize)
  if(CMAKE_VERSION VERSION_LESS 3.31 AND NOT TARGET codegen)
    add_custom_target(codegen)
  endif()
endfunction()

function(_besa_codegen_register_target NAME TARGET_NAME)
  if(POLICY CMP0171)
    cmake_policy(SET CMP0171 NEW)
  endif()
  if(NOT TARGET "${TARGET_NAME}")
    _besa_fatal("generated subdirectory '${NAME}'" "unknown generator target '${TARGET_NAME}'")
  endif()
  set_property(GLOBAL APPEND PROPERTY BESA_INTERNAL_CODEGEN_TARGETS "${TARGET_NAME}")
  _besa_codegen_initialize()
  if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.31)
    set(_stamp "${PROJECT_BINARY_DIR}/besa/codegen/${NAME}.stamp")
    get_filename_component(_directory "${_stamp}" DIRECTORY)
    file(MAKE_DIRECTORY "${_directory}")
    add_custom_command(
      OUTPUT "${_stamp}"
      COMMAND "${CMAKE_COMMAND}" -E touch "${_stamp}"
      DEPENDS "${TARGET_NAME}"
      CODEGEN
      VERBATIM
    )
  else()
    add_dependencies(codegen "${TARGET_NAME}")
  endif()
endfunction()

function(_besa_codegen_include NAME OUTPUT_VARIABLE)
  if(NOT DEFINED BESA_CODEGEN_DIRECTORY OR "${BESA_CODEGEN_DIRECTORY}" STREQUAL "")
    besa_workspace_initialize()
  endif()
  set(_include "${BESA_CODEGEN_DIRECTORY}/${NAME}/include")
  file(MAKE_DIRECTORY "${_include}")
  set_property(GLOBAL APPEND PROPERTY BESA_INTERNAL_GENERATED_INCLUDE_ROOTS "${_include}")
  set("${OUTPUT_VARIABLE}" "${_include}" PARENT_SCOPE)
endfunction()

function(_besa_codegen_finalize)
  get_property(_roots GLOBAL PROPERTY BESA_INTERNAL_GENERATED_INCLUDE_ROOTS)
  if(NOT _roots OR NOT TARGET "lib${PROJECT_NAME}")
    return()
  endif()
  include(GNUInstallDirs)
  list(REMOVE_DUPLICATES _roots)
  foreach(_root IN LISTS _roots)
    file(GLOB_RECURSE _headers LIST_DIRECTORIES FALSE CONFIGURE_DEPENDS "${_root}/*")
    if(_headers)
      target_sources("lib${PROJECT_NAME}" PUBLIC FILE_SET HEADERS BASE_DIRS "${_root}" FILES ${_headers})
    endif()
    target_include_directories(
      "lib${PROJECT_NAME}" PUBLIC
      $<BUILD_INTERFACE:${_root}>
      $<INSTALL_INTERFACE:include>
    )
    install(DIRECTORY "${_root}/" DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}" OPTIONAL)
  endforeach()
endfunction()
