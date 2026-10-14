# --------------------------------------------------------------------------------------------------
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 besa developers
# --------------------------------------------------------------------------------------------------
# Declare atomic features and valid project configurations.
#
# Users declare features and optional Keyso spaces while configuration is open.
# besa_finalize_options() resolves the project cache selection, checks feature,
# devtool and test-mode constraints, publishes resolved values, and schedules
# project finalization. Target and test declarations follow finalization.
# The finalizer is a macro because CMake project-wide option visibility and
# language-enabling lifecycle depend on the caller scope.

include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/internal.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/keyso.cmake")

# --------------------------------------------------------------------------------------------------
# Public API
# --------------------------------------------------------------------------------------------------

# Declare an atomic feature and its singleton Keyso space before finalization.
#   besa_add_feature(<name>)
function(besa_add_feature NAME)
  _besa_require_config_open("besa_add_feature")
  if("${NAME}" STREQUAL "")
    _besa_fatal("besa_add_feature" "feature name is required")
  endif()
  if(ARGN)
    _besa_fatal("besa_add_feature" "expected exactly one feature name; got: ${NAME};${ARGN}")
  endif()
  _besa_keyso_validate_name("besa_add_feature" "${NAME}")
  _besa_append_unique(BESA_DECLARED_FEATURES "${NAME}" "besa_add_feature")
  _besa_keyso_canonicalize(_singleton "${NAME}")
  _besa_keyso_space_set("${NAME}" "${_singleton}")
endfunction()

# Set the named Keyso space of permitted concrete project configurations.
#   besa_set_feature_space(<space> [DEFAULT <singleton-space>])
# Without DEFAULT, the empty set is preferred if present.
function(besa_set_feature_space NAME)
  _besa_require_config_open("besa_set_feature_space")
  if("${NAME}" STREQUAL "")
    _besa_fatal("besa_set_feature_space" "feature-space name is required")
  endif()
  cmake_parse_arguments(ARG "" "DEFAULT" "" ${ARGN})
  _besa_require_no_unparsed("besa_set_feature_space" "${ARG_UNPARSED_ARGUMENTS}")
  _besa_keyso_space_get("${NAME}" _allowed)
  if(NOT _allowed)
    _besa_fatal("besa_set_feature_space" "feature space '${NAME}' is empty")
  endif()

  if(ARG_DEFAULT)
    _besa_keyso_space_get("${ARG_DEFAULT}" _defaults)
    list(LENGTH _defaults _count)
    if(NOT _count EQUAL 1)
      _besa_fatal("besa_set_feature_space" "DEFAULT '${ARG_DEFAULT}' must contain exactly one feature set")
    endif()
    list(GET _defaults 0 _default)
    if(NOT "${_default}" IN_LIST _allowed)
      _besa_fatal("besa_set_feature_space" "DEFAULT '${ARG_DEFAULT}' is not a member of '${NAME}'")
    endif()
  elseif("${_BESA_KEYSO_EMPTY}" IN_LIST _allowed)
    set(_default "${_BESA_KEYSO_EMPTY}")
  else()
    list(GET _allowed 0 _default)
  endif()

  set_property(GLOBAL PROPERTY BESA_PROJECT_FEATURE_SPACE "${NAME}")
  set_property(GLOBAL PROPERTY BESA_PROJECT_DEFAULT_FEATURE_SET "${_default}")
endfunction()

# Connect an ordinary project CACHE STRING to feature resolution.
#   besa_set_feature_variable(<cache-variable-name>)
function(besa_set_feature_variable VARIABLE)
  _besa_require_config_open("besa_set_feature_variable")
  if(NOT VARIABLE MATCHES "^[A-Za-z_][A-Za-z_0-9]*$")
    _besa_fatal("besa_set_feature_variable" "expected a CMake variable name")
  endif()
  set_property(GLOBAL PROPERTY BESA_FEATURE_VARIABLE "${VARIABLE}")
endfunction()

# Declare two mutually incompatible atomic features.
#   besa_features_conflict(<first> <second>)
function(besa_features_conflict FIRST SECOND)
  _besa_require_config_open("besa_features_conflict")
  if(NOT ARGC EQUAL 2 OR FIRST STREQUAL SECOND)
    _besa_fatal("besa_features_conflict" "expected two distinct feature names")
  endif()
  get_property(_declared GLOBAL PROPERTY BESA_DECLARED_FEATURES)
  foreach(_feature IN ITEMS "${FIRST}" "${SECOND}")
    if(NOT "${_feature}" IN_LIST _declared)
      _besa_fatal("besa_features_conflict" "unknown feature '${_feature}'")
    endif()
  endforeach()
  set(_pair "${FIRST};${SECOND}")
  list(SORT _pair)
  string(JOIN "|" _record ${_pair})
  get_property(_conflicts GLOBAL PROPERTY BESA_FEATURE_CONFLICTS)
  if(NOT "${_record}" IN_LIST _conflicts)
    set_property(GLOBAL APPEND PROPERTY BESA_FEATURE_CONFLICTS "${_record}")
  endif()
endfunction()

# Resolve declared options, validate constraints and publish internal state.
#   besa_finalize_options()
# Must be called before sources/tests; schedules deferred project finalization.
macro(besa_finalize_options)
  cmake_parse_arguments(ARG "" "" "" ${ARGN})
  _besa_require_no_unparsed("besa_finalize_options" "${ARG_UNPARSED_ARGUMENTS}")
  _besa_require_config_open("besa_finalize_options")

  besa_workspace_initialize()
  if(COMMAND _besa_cpdocs_apply_feature_set)
    _besa_cpdocs_apply_feature_set()
  endif()
  _besa_resolve_features(_enabled_features)
  _besa_devtools_resolve(_enabled_devtools)
  _besa_resolve_test_modes(_enabled_test_modes)
  _besa_warnings_resolve(_enabled_warnings)
  _besa_run_devtool_constraints("${_enabled_devtools}")
  _besa_run_test_mode_constraints("${_enabled_test_modes}")

  set_property(GLOBAL PROPERTY BESA_ENABLED_FEATURES "${_enabled_features}")
  set(BESA_ENABLED_FEATURES "${_enabled_features}" CACHE INTERNAL "Resolved enabled BESA features")
  _besa_publish_feature_booleans("${_enabled_features}")
  _besa_publish_test_modes("${_enabled_test_modes}")
  _besa_version_resolve()

  # The compile database is the preferred C/C++ parser environment for cpdocs. Make it available
  # whenever the active generator supports it; projects do not need to opt in separately.
  set(CMAKE_EXPORT_COMPILE_COMMANDS ON CACHE BOOL "Export compile commands for tooling" FORCE)

  _besa_configuration_summary(
    "${_enabled_features}" "${_enabled_devtools}" "${_enabled_test_modes}" "${_enabled_warnings}"
  )
  set_property(GLOBAL PROPERTY BESA_CONFIGURATION_COMPLETE TRUE)

  cmake_language(EVAL CODE
    "cmake_language(DEFER DIRECTORY [[${PROJECT_SOURCE_DIR}]] CALL _besa_project_finalize)"
  )
endmacro()

# Alternate entry point forwarding to besa_finalize_options().
#   besa_configure_complete()
macro(besa_configure_complete)
  besa_finalize_options(${ARGN})
endmacro()

# --------------------------------------------------------------------------------------------------
# Internal implementation
# --------------------------------------------------------------------------------------------------

function(_besa_feature_set_is_valid ENABLED OUTPUT_VARIABLE)
  get_property(_conflicts GLOBAL PROPERTY BESA_FEATURE_CONFLICTS)
  foreach(_record IN LISTS _conflicts)
    string(REPLACE "|" ";" _pair "${_record}")
    list(GET _pair 0 _first)
    list(GET _pair 1 _second)
    if("${_first}" IN_LIST ENABLED AND "${_second}" IN_LIST ENABLED)
      set("${OUTPUT_VARIABLE}" FALSE PARENT_SCOPE)
      return()
    endif()
  endforeach()
  set("${OUTPUT_VARIABLE}" TRUE PARENT_SCOPE)
endfunction()

function(_besa_resolve_features OUTPUT_VARIABLE)
  get_property(_declared GLOBAL PROPERTY BESA_DECLARED_FEATURES)
  get_property(_space GLOBAL PROPERTY BESA_PROJECT_FEATURE_SPACE)
  get_property(_default GLOBAL PROPERTY BESA_PROJECT_DEFAULT_FEATURE_SET)
  get_property(_variable GLOBAL PROPERTY BESA_FEATURE_VARIABLE)

  if(_variable AND DEFINED ${_variable})
    set(_enabled "${${_variable}}")
  elseif(DEFINED PROJECT_FEATURES)
    # Keep existing Keyso-based projects working unchanged.
    set(_enabled "${PROJECT_FEATURES}")
  elseif(NOT "${_default}" STREQUAL "")
    _besa_keyso_decode("${_default}" _enabled)
  else()
    set(_enabled)
  endif()
  list(REMOVE_ITEM _enabled "" "none")
  list(REMOVE_DUPLICATES _enabled)
  list(SORT _enabled)

  foreach(_feature IN LISTS _enabled)
    if(NOT "${_feature}" IN_LIST _declared)
      _besa_fatal("besa_finalize_options" "unknown feature '${_feature}'. Declared features are: ${_declared}")
    endif()
  endforeach()
  if(_space)
    _besa_keyso_exact_contains("${_space}" "${_enabled}" _allowed)
    if(NOT _allowed)
      string(JOIN ", " _display ${_enabled})
      _besa_fatal("besa_finalize_options" "feature set '${_display}' is not allowed by project feature space '${_space}'")
    endif()
  endif()
  _besa_feature_set_is_valid("${_enabled}" _conflict_free)
  if(NOT _conflict_free)
    _besa_fatal("besa_finalize_options" "selected features '${_enabled}' contain a declared conflict")
  endif()
  set("${OUTPUT_VARIABLE}" "${_enabled}" PARENT_SCOPE)
endfunction()

function(_besa_publish_feature_booleans ENABLED_FEATURES)
  get_property(_declared GLOBAL PROPERTY BESA_DECLARED_FEATURES)
  foreach(_feature IN LISTS _declared)
    _besa_normalize_name("${_feature}" _normalized)
    if("${_feature}" IN_LIST ENABLED_FEATURES)
      set(_value TRUE)
    else()
      set(_value FALSE)
    endif()
    set("PROJECT_FEATURE_${_normalized}" "${_value}" CACHE INTERNAL "Resolved BESA feature")
  endforeach()
endfunction()

function(_besa_configuration_summary LIST_FEATURES LIST_DEVTOOLS LIST_TEST_MODES LIST_WARNINGS)
  foreach(_name IN ITEMS FEATURES DEVTOOLS TEST_MODES WARNINGS)
    set(_value "${LIST_${_name}}")
    if("${_value}" STREQUAL "")
      set(_display_${_name} "none")
    else()
      string(JOIN ", " _display_${_name} ${_value})
    endif()
  endforeach()

  if(BUILD_TESTING)
    set(_build_testing ON)
  else()
    set(_build_testing OFF)
  endif()
  string(TOLOWER "${PROJECT_NAME}" _project_lower)
  message(STATUS "${_project_lower} configuration:")
  message(STATUS "  Features          : ${_display_FEATURES}")
  message(STATUS "  Devtools          : ${_display_DEVTOOLS}")
  message(STATUS "  Warning policy    : ${_display_WARNINGS}")
  message(STATUS "  Test modes        : ${_display_TEST_MODES}")
  message(STATUS "  Build testing     : ${_build_testing}")
  message(STATUS "  Release type      : ${RELEASE_TYPE}")
  message(STATUS "  Release revision  : ${RELEASE_REVISION}")
  message(STATUS "  Package builder   : ${PKGBUILDER_ID}")
  message(STATUS "  Package revision  : ${PKGBUILDER_REVISION}")
  message(STATUS "  Version           : ${PROJECT_SEMVER}")
endfunction()
