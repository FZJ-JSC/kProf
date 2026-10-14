# --------------------------------------------------------------------------------------------------
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 besa developers
# --------------------------------------------------------------------------------------------------
# Composable compiler-warning policies selected by BUILD_WARNINGS.
#
# minimal, extra and everything form one increasing warning level; werror is
# independent and can be combined with one level. `none` disables all levels.
# The interface targets carry compiler-dependent usage requirements. Selection
# is resolved during option finalization and applied to local compiled targets.
# The option syntax, validation and published cache variables are unchanged.

include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/internal.cmake")

# Warning policies are BESA capabilities, not project-declared modes.  A project chooses zero or more
# policies through BUILD_WARNINGS, e.g. `extra;werror`.
set(_BESA_SUPPORTED_WARNINGS minimal extra everything werror)

add_library(besa.warning.minimal INTERFACE)
add_library(besa::warning.minimal ALIAS besa.warning.minimal)
target_compile_options(
  besa.warning.minimal INTERFACE
  $<$<COMPILE_LANG_AND_ID:C,GNU,Clang>:-Wall>
  $<$<COMPILE_LANG_AND_ID:CXX,GNU,Clang>:-Wall>
  $<$<COMPILE_LANG_AND_ID:CUDA,NVIDIA>:-Xcompiler=-Wall>
)

add_library(besa.warning.extra INTERFACE)
add_library(besa::warning.extra ALIAS besa.warning.extra)
# Only incremental options: extra includes minimal transitively.
target_link_libraries(besa.warning.extra INTERFACE besa::warning.minimal)
target_compile_options(
  besa.warning.extra INTERFACE
  $<$<COMPILE_LANG_AND_ID:C,GNU,Clang>:-Wextra;-Wpedantic;-Wdeprecated>
  $<$<COMPILE_LANG_AND_ID:CXX,GNU,Clang>:-Wextra;-Wpedantic;-Wdeprecated>
  $<$<COMPILE_LANG_AND_ID:CUDA,NVIDIA>:-Xcompiler=-Wextra,-Wpedantic>
)

add_library(besa.warning.werror INTERFACE)
add_library(besa::warning.werror ALIAS besa.warning.werror)
target_compile_options(
  besa.warning.werror INTERFACE
  $<$<COMPILE_LANG_AND_ID:C,GNU,Clang>:-Werror>
  $<$<COMPILE_LANG_AND_ID:CXX,GNU,Clang>:-Werror>
)

add_library(besa.warning.everything INTERFACE)
add_library(besa::warning.everything ALIAS besa.warning.everything)
# GCC everything adds no options beyond extra; Clang adds its full warning set.
target_link_libraries(besa.warning.everything INTERFACE besa::warning.extra)
target_compile_options(
  besa.warning.everything INTERFACE
  $<$<COMPILE_LANG_AND_ID:C,Clang>:-Weverything;-Wno-padded>
  $<$<COMPILE_LANG_AND_ID:CXX,Clang>:-Weverything;-Wno-c++98-compat;-Wno-c++98-compat-pedantic;-Wno-padded;-Wno-weak-vtables>
)

# --------------------------------------------------------------------------------------------------
# Internal implementation
# --------------------------------------------------------------------------------------------------

# Validate mutually exclusive warning levels and publish normalized policy
# booleans. `none` selects no target and cannot be mixed with other policies.
function(_besa_warnings_resolve OUTPUT_VARIABLE)
  if(NOT DEFINED BUILD_WARNINGS)
    if(DEFINED PROJECT_WARNINGS)
      set(BUILD_WARNINGS "${PROJECT_WARNINGS}")
      string(REPLACE "essential" "extra" BUILD_WARNINGS "${BUILD_WARNINGS}")
      string(REPLACE "error" "werror" BUILD_WARNINGS "${BUILD_WARNINGS}")
    else()
      set(BUILD_WARNINGS "minimal" CACHE STRING "Build warning policies")
    endif()
  endif()

  set(_enabled)
  set(_seen)
  foreach(_warning IN LISTS BUILD_WARNINGS)
    if("${_warning}" STREQUAL "")
      continue()
    endif()
    if("${_warning}" IN_LIST _seen)
      _besa_fatal("besa_configure_complete" "warning policy '${_warning}' is specified more than once")
    endif()
    list(APPEND _seen "${_warning}")
  endforeach()

  # Keep `none` as a convenient explicit spelling for builds which intentionally disable warning
  # policy, while the actual BESA capability list contains only real composable warning policies.
  if("none" IN_LIST _seen)
    list(LENGTH _seen _count)
    if(NOT _count EQUAL 1)
      _besa_fatal("besa_configure_complete" "BUILD_WARNINGS value 'none' is mutually exclusive")
    endif()
  else()
    set(_level_count 0)
    foreach(_level IN ITEMS minimal extra everything)
      if("${_level}" IN_LIST _seen)
        math(EXPR _level_count "${_level_count} + 1")
      endif()
    endforeach()
    if(_level_count GREATER 1)
      _besa_fatal("besa_finalize_options" "BUILD_WARNINGS selects more than one warning level")
    endif()
    foreach(_warning IN LISTS _seen)
      if(NOT "${_warning}" IN_LIST _BESA_SUPPORTED_WARNINGS)
        _besa_fatal(
          "besa_configure_complete"
          "unknown warning policy '${_warning}'. Allowed values are: ${_BESA_SUPPORTED_WARNINGS}"
        )
      endif()
      list(APPEND _enabled "${_warning}")
    endforeach()
  endif()

  set_property(GLOBAL PROPERTY BESA_ENABLED_WARNINGS "${_enabled}")
  set(BESA_ENABLED_WARNINGS "${_enabled}" CACHE INTERNAL "Resolved BESA warning policies")
  foreach(_warning IN LISTS _BESA_SUPPORTED_WARNINGS)
    _besa_normalize_name("${_warning}" _normalized)
    if("${_warning}" IN_LIST _enabled)
      set(_value TRUE)
    else()
      set(_value FALSE)
    endif()
    set("BUILD_WARNINGS_${_normalized}" "${_value}" CACHE INTERNAL "Resolved BESA warning policy")
  endforeach()

  set("${OUTPUT_VARIABLE}" "${_enabled}" PARENT_SCOPE)
endfunction()

function(_besa_target_apply_warning_policy TARGET_NAME)
  get_property(_warnings GLOBAL PROPERTY BESA_ENABLED_WARNINGS)
  foreach(_warning IN LISTS _warnings)
    target_link_libraries(
      "${TARGET_NAME}" PRIVATE $<BUILD_INTERFACE:besa::warning.${_warning}>
    )
  endforeach()
endfunction()
