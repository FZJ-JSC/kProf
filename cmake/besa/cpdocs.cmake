# --------------------------------------------------------------------------------------------------
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 besa developers
# --------------------------------------------------------------------------------------------------
# Build metadata consumed by the cpdocs API documentation provider.
#
# During configuration BESA records active feature-set information and emits
# the metadata needed for versioned API documentation. The manifest describes
# the semantic units from manifest.cmake. Generation runs at finalization;
# project-facing documentation build targets are defined in userdocs.cmake.

include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/internal.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/keyso.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/manifest.cmake")

# cpdocs passes one concrete feature set back to BESA. Feature sets are deliberately unnamed: the
# selected object contains only the concrete features needed to reproduce that configuration.

# --------------------------------------------------------------------------------------------------
# Internal implementation
# --------------------------------------------------------------------------------------------------

function(_besa_cpdocs_apply_feature_set)
  if(NOT DEFINED BESA_CPDOCS_FEATURE_SET OR "${BESA_CPDOCS_FEATURE_SET}" STREQUAL "")
    return()
  endif()
  if(NOT EXISTS "${BESA_CPDOCS_FEATURE_SET}")
    _besa_fatal("BESA_CPDOCS_FEATURE_SET" "file does not exist: ${BESA_CPDOCS_FEATURE_SET}")
  endif()

  file(READ "${BESA_CPDOCS_FEATURE_SET}" _json)
  string(JSON _version GET "${_json}" cpdocs-feature-set)
  if(NOT _version EQUAL 1)
    _besa_fatal("BESA_CPDOCS_FEATURE_SET" "unsupported cpdocs-feature-set ${_version}")
  endif()

  string(JSON _count LENGTH "${_json}" features)
  set(_selected)
  if(_count GREATER 0)
    math(EXPR _last "${_count} - 1")
    foreach(_index RANGE 0 ${_last})
      string(JSON _feature GET "${_json}" features ${_index})
      list(APPEND _selected "${_feature}")
    endforeach()
  endif()

  get_property(_variable GLOBAL PROPERTY BESA_FEATURE_VARIABLE)
  if(NOT _variable)
    set(_variable PROJECT_FEATURES)
  endif()
  if(NOT _selected)
    set(_selected none)
  endif()
  set(${_variable} "${_selected}" CACHE STRING "cpdocs selected BESA feature set" FORCE)
  set(${_variable} "${_selected}" PARENT_SCOPE)
endfunction()

function(_besa_cpdocs_write_feature_sets OUTPUT_FILE)
  get_property(_space GLOBAL PROPERTY BESA_PROJECT_FEATURE_SPACE)
  if(_space)
    _besa_keyso_space_get("${_space}" _sets)
  else()
    # Enumerate the implicit Cartesian product for documentation only.
    # Ordinary project configuration never expands this potentially large space.
    get_property(_features GLOBAL PROPERTY BESA_DECLARED_FEATURES)
    set(_sets "${_BESA_KEYSO_EMPTY}")
    foreach(_feature IN LISTS _features)
      set(_new_sets "${_sets}")
      foreach(_token IN LISTS _sets)
        _besa_keyso_decode("${_token}" _members)
        list(APPEND _members "${_feature}")
        _besa_keyso_canonicalize(_member_token ${_members})
        list(APPEND _new_sets "${_member_token}")
      endforeach()
      set(_sets "${_new_sets}")
    endforeach()
  endif()

  set(_objects)
  foreach(_token IN LISTS _sets)
    _besa_keyso_decode("${_token}" _features)
    _besa_feature_set_is_valid("${_features}" _valid)
    if(NOT _valid)
      continue()
    endif()
    _besa_json_array(_features_json ${_features})
    list(APPEND _objects "{\"features\": ${_features_json}}")
  endforeach()
  string(JOIN ",\n    " _objects_json ${_objects})

  _besa_json_string("${PROJECT_NAME}" _project_name_json)
  _besa_json_string("${PROJECT_VERSION}" _project_version_json)

  get_filename_component(_directory "${OUTPUT_FILE}" DIRECTORY)
  file(MAKE_DIRECTORY "${_directory}")
  file(WRITE "${OUTPUT_FILE}"
    "{\n"
    "  \"cpdocs-feature-sets\": 1,\n"
    "  \"generator\": \"besa\",\n"
    "  \"project\": {\n"
    "    \"name\": ${_project_name_json},\n"
    "    \"version\": ${_project_version_json}\n"
    "  },\n"
    "  \"feature-sets\": [\n    ${_objects_json}\n  ]\n"
    "}\n"
  )
endfunction()

# A manifest describes exactly one concrete build. The selected feature set is already known to
# cpdocs, so it is intentionally not duplicated here.
function(_besa_cpdocs_write_manifest OUTPUT_FILE)
  _besa_manifest_units_json(_units_json)
  _besa_manifest_options_json(_options_json)
  get_filename_component(_directory "${OUTPUT_FILE}" DIRECTORY)
  file(MAKE_DIRECTORY "${_directory}")
  file(WRITE "${OUTPUT_FILE}"
    "{\n"
    "  \"cpdocs-manifest\": 1,\n"
    "  \"options\": ${_options_json},\n"
    "  \"units\": [\n    ${_units_json}\n  ]\n"
    "}\n"
  )
endfunction()

function(_besa_cpdocs_finalize)
  if(DEFINED BESA_CPDOCS_FEATURE_SETS_OUTPUT AND NOT "${BESA_CPDOCS_FEATURE_SETS_OUTPUT}" STREQUAL "")
    _besa_cpdocs_write_feature_sets("${BESA_CPDOCS_FEATURE_SETS_OUTPUT}")
  endif()
  if(DEFINED BESA_CPDOCS_MANIFEST_OUTPUT AND NOT "${BESA_CPDOCS_MANIFEST_OUTPUT}" STREQUAL "")
    _besa_cpdocs_write_manifest("${BESA_CPDOCS_MANIFEST_OUTPUT}")

    # The manifest is complete after configuration, but generated API inputs may still need their
    # build-time generators. cpdocs invokes this target before extraction for exactly that step.
    if(NOT TARGET besa.cpdocs)
      add_custom_target(besa.cpdocs)
      get_property(_codegen_targets GLOBAL PROPERTY BESA_INTERNAL_CODEGEN_TARGETS)
      if(_codegen_targets)
        list(REMOVE_DUPLICATES _codegen_targets)
        add_dependencies(besa.cpdocs ${_codegen_targets})
      endif()
    endif()
  endif()
endfunction()
