# SPDX-FileCopyrightText: 2026 BESA developers
# SPDX-FileCopyrightText: 2026 kprof developers
#
# SPDX-License-Identifier: Apache-2.0
include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/internal.cmake")

# Warning policies are BESA capabilities, not project-declared modes.  A project chooses zero or more
# policies through PROJECT_WARNINGS.  The policies are intentionally composable: for example,
# `essential;error` enables the normal warning set and separately promotes diagnostics to errors.
set(_BESA_SUPPORTED_WARNINGS essential error everything)

add_library(besa.warning.essential INTERFACE)
add_library(besa::warning.essential ALIAS besa.warning.essential)
target_compile_options(
  besa.warning.essential INTERFACE
  $<$<COMPILE_LANG_AND_ID:C,GNU,Clang>:-Wall;-Wextra;-Wpedantic;-Wdeprecated>
  $<$<COMPILE_LANG_AND_ID:CXX,GNU,Clang>:-Wall;-Wextra;-Wpedantic;-Wdeprecated>
  $<$<COMPILE_LANG_AND_ID:CUDA,NVIDIA>:-Xcompiler=-Wall,-Wextra,-Wpedantic>
)

add_library(besa.warning.error INTERFACE)
add_library(besa::warning.error ALIAS besa.warning.error)
target_compile_options(
  besa.warning.error INTERFACE
  $<$<COMPILE_LANG_AND_ID:C,GNU,Clang>:-Werror>
  $<$<COMPILE_LANG_AND_ID:CXX,GNU,Clang>:-Werror>
)

add_library(besa.warning.everything INTERFACE)
add_library(besa::warning.everything ALIAS besa.warning.everything)
target_compile_options(
  besa.warning.everything INTERFACE
  $<$<COMPILE_LANG_AND_ID:C,GNU>:-Wall;-Wextra;-Wpedantic;-Wdeprecated>
  $<$<COMPILE_LANG_AND_ID:CXX,GNU>:-Wall;-Wextra;-Wpedantic;-Wdeprecated>
  $<$<COMPILE_LANG_AND_ID:C,Clang>:-Weverything;-Wno-padded>
  $<$<COMPILE_LANG_AND_ID:CXX,Clang>:-Weverything;-Wno-c++98-compat;-Wno-c++98-compat-pedantic;-Wno-padded;-Wno-weak-vtables>
)

function(_besa_warnings_resolve OUTPUT_VARIABLE)
  if(NOT DEFINED PROJECT_WARNINGS)
    set(PROJECT_WARNINGS "essential" CACHE STRING "BESA warning policies enabled for this build")
  endif()

  set(_enabled)
  set(_seen)
  foreach(_warning IN LISTS PROJECT_WARNINGS)
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
      _besa_fatal("besa_configure_complete" "PROJECT_WARNINGS value 'none' is mutually exclusive")
    endif()
  else()
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
    set("PROJECT_WARNINGS_${_normalized}" "${_value}" CACHE INTERNAL "Resolved BESA warning policy")
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
