# --------------------------------------------------------------------------------------------------
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 besa developers
# --------------------------------------------------------------------------------------------------
# Finite algebra of project feature spaces (Keyso).
#
# A concrete feature set is an unordered collection of enabled atomic features.
# A named feature space is a set of possible concrete feature sets, not a CMake
# namespace. Declare atomic features with besa_add_feature() before constructing
# spaces; construct spaces before besa_finalize_options().
#
# Notation used below (mathematical sets, NOT CMake argument syntax):
#   {}                  an empty concrete feature set: no features enabled
#   {mpi}               a singleton concrete set: only 'mpi' enabled
#   {{}, {mpi}, {gpu}}  a feature space with three possible concrete sets
#   (empty space)       no possible concrete sets; different from the member {}
#
# Keyso spaces have TWO different interpretations depending on the consumer:
#   - Configuration restrictions use EXACT membership: enabled == a space member.
#   - Feature conditions use SUBSET matching: a space member only has to be
#     contained in the enabled features. Additional enabled features are allowed.
#     In particular, any space containing {} matches EVERY condition, because
#     the empty set is a subset of every concrete feature set. Such a space is
#     useful for describing allowed configurations, but is not a useful filter
#     when interpreted as a condition.
#
# Example declarations (all must precede besa_finalize_options()):
#   besa_add_feature(host)
#   besa_add_feature(gpu)
#   besa_add_feature(mpi)
#   besa_keyso_one_of(backend host gpu)       # {{host}, {gpu}}
#   besa_keyso_zero_or_one(parallel mpi)      # {{}, {mpi}}
#   besa_keyso_create_feature_space(supported PRODUCT backend parallel)
#   # supported = {{host}, {gpu}, {host, mpi}, {gpu, mpi}}
#   besa_set_feature_space(supported)         # restrict full configurations
#
# Implementation detail: individual concrete sets are represented by sorted,
# deduplicated feature names joined with '|'. The special token '@' encodes {}.
# Named spaces are held in global properties; the encoding is not public API.

include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/internal.cmake")

set(_BESA_KEYSO_EMPTY "@")

# --------------------------------------------------------------------------------------------------
# Public API
# --------------------------------------------------------------------------------------------------

# Define ONE allowed concrete set containing ALL specified features.
#
#   besa_keyso_all_of(<space> <feature>...)
#
# Example:
#   besa_keyso_all_of(distributed_gpu mpi gpu)
#   # distributed_gpu = {{mpi, gpu}}
#
# The resulting feature space has one member (the two-feature set {mpi, gpu}),
# not two members. Exact membership rejects {mpi} or {mpi, gpu, host}; when used
# as a condition it matches {mpi, gpu, host} because both required features exist.
# At least one previously declared feature is required.
function(besa_keyso_all_of NAME)
  _besa_require_config_open("besa_keyso_all_of")
  _besa_keyso_validate_name("besa_keyso_all_of" "${NAME}")
  _besa_keyso_require_features("besa_keyso_all_of" ${ARGN})
  _besa_keyso_canonicalize(_token ${ARGN})
  _besa_keyso_space_set("${NAME}" "${_token}")
endfunction()

# Define one possible concrete set for EACH individual feature.
#
#   besa_keyso_one_of(<space> <feature>...)
#
# Example:
#   besa_keyso_one_of(backend host gpu)
#   # backend = {{host}, {gpu}}
#
# A singleton is a concrete set containing exactly one feature; it is not a
# feature space with one member. As a restriction, 'backend' permits {host} OR
# {gpu}, but not {} and not {host, gpu}. As a condition, it also matches the
# larger enabled set {host, gpu}, since one of its singleton members is a subset.
# At least one previously declared feature is required.
function(besa_keyso_one_of NAME)
  _besa_require_config_open("besa_keyso_one_of")
  _besa_keyso_validate_name("besa_keyso_one_of" "${NAME}")
  _besa_keyso_require_features("besa_keyso_one_of" ${ARGN})
  set(_sets)
  foreach(_feature IN LISTS ARGN)
    _besa_keyso_canonicalize(_token "${_feature}")
    list(APPEND _sets "${_token}")
  endforeach()
  _besa_keyso_space_set("${NAME}" ${_sets})
endfunction()

# Define all choices of ZERO or ONE of the specified features.
#
#   besa_keyso_zero_or_one(<space> <feature>...)
#
# Example:
#   besa_keyso_zero_or_one(parallel mpi openmp)
#   # parallel = {{}, {mpi}, {openmp}}
#
# Here {} is ONE valid concrete configuration: neither mpi nor openmp enabled.
# {mpi} and {openmp} are singleton configurations, each enabling exactly one.
# The space contains THREE members; it is not an empty space. As an EXACT
# restriction, {mpi, openmp} is invalid: it enables two alternatives.
#
# IMPORTANT: As a feature CONDITION, 'parallel' matches every enabled set,
# including {mpi, openmp}, because {} is a subset of every set. Use this
# constructor to describe allowed configurations or as a PRODUCT operand,
# NOT to test that at most one of these features is currently enabled.
# At least one previously declared feature is required.
function(besa_keyso_zero_or_one NAME)
  _besa_require_config_open("besa_keyso_zero_or_one")
  _besa_keyso_validate_name("besa_keyso_zero_or_one" "${NAME}")
  _besa_keyso_require_features("besa_keyso_zero_or_one" ${ARGN})
  set(_sets "${_BESA_KEYSO_EMPTY}")
  foreach(_feature IN LISTS ARGN)
    _besa_keyso_canonicalize(_token "${_feature}")
    list(APPEND _sets "${_token}")
  endforeach()
  _besa_keyso_space_set("${NAME}" ${_sets})
endfunction()

# Define all NONEMPTY combinations of the specified features.
#
#   besa_keyso_any_of(<space> <feature>...)
#
# Example:
#   besa_keyso_any_of(instrumentation tracing profiling)
#   # instrumentation = {{tracing}, {profiling}, {tracing, profiling}}
#
# This is the power set minus {}. As an exact restriction it requires at least
# one of the listed features and allows any combination of them, but no other
# features unless combined with other spaces (e.g. via PRODUCT). As a condition
# it matches whenever one or more listed features is enabled, even alongside
# additional features. At least one previously declared feature is required.
function(besa_keyso_any_of NAME)
  _besa_require_config_open("besa_keyso_any_of")
  _besa_keyso_validate_name("besa_keyso_any_of" "${NAME}")
  _besa_keyso_require_features("besa_keyso_any_of" ${ARGN})
  set(_sets "${_BESA_KEYSO_EMPTY}")
  foreach(_feature IN LISTS ARGN)
    set(_expanded ${_sets})
    _besa_keyso_canonicalize(_single "${_feature}")
    foreach(_existing IN LISTS _sets)
      _besa_keyso_union_tokens("${_existing}" "${_single}" _merged)
      list(APPEND _expanded "${_merged}")
    endforeach()
    set(_sets ${_expanded})
    list(REMOVE_DUPLICATES _sets)
  endforeach()
  list(REMOVE_ITEM _sets "${_BESA_KEYSO_EMPTY}")
  _besa_keyso_space_set("${NAME}" ${_sets})
endfunction()

# Construct a named feature space from other named feature spaces.
#
#   besa_keyso_create_feature_space(
#     <name> UNION|INTERSECTION|SETMINUS|PRODUCT <space>...
#   )
#
# Operations are on WHOLE concrete sets (members of a space):
#   UNION         all members from every operand (duplicates removed)
#   INTERSECTION  only members present in every operand
#   SETMINUS      members in the first operand minus all subsequent operands
#   PRODUCT       for each choice of one member per operand, combine the
#                 selected feature sets by union (duplicates removed)
#
# Example (assumes host, gpu, mpi, openmp have been declared):
#   besa_keyso_one_of(backend host gpu)
#   besa_keyso_zero_or_one(parallel mpi openmp)
#   besa_keyso_create_feature_space(supported PRODUCT backend parallel)
#   # supported = {{host}, {host, mpi}, {host, openmp},
#   #              {gpu},  {gpu, mpi},  {gpu, openmp}}
#
# Example of ordinary set algebra:
#   besa_keyso_one_of(left host gpu)          # {{host}, {gpu}}
#   besa_keyso_one_of(right gpu mpi)          # {{gpu}, {mpi}}
#   besa_keyso_create_feature_space(u UNION left right)        # {{host}, {gpu}, {mpi}}
#   besa_keyso_create_feature_space(i INTERSECTION left right) # {{gpu}}
#   besa_keyso_create_feature_space(d SETMINUS left right)     # {{host}}
#
# PRODUCT does NOT merely concatenate the operand spaces: it computes unions
# of each selected pair of concrete sets. A space with no possible members
# produces no results under PRODUCT. Declare operands before composing them.
function(besa_keyso_create_feature_space NAME OPERATION)
  _besa_require_config_open("besa_keyso_create_feature_space")
  if("${NAME}" STREQUAL "" OR "${OPERATION}" STREQUAL "")
    _besa_fatal(
      "besa_keyso_create_feature_space"
      "usage: besa_keyso_create_feature_space(<name> <operation> <feature-space>...)"
    )
  endif()
  set(_inputs ${ARGN})
  if(NOT _inputs)
    _besa_fatal("besa_keyso_create_feature_space" "at least one input feature space is required")
  endif()
  string(TOUPPER "${OPERATION}" _operation)

  if(_operation STREQUAL "UNION")
    set(_result)
    foreach(_input IN LISTS _inputs)
      _besa_keyso_space_get("${_input}" _space)
      list(APPEND _result ${_space})
    endforeach()

  elseif(_operation STREQUAL "INTERSECTION")
    list(GET _inputs 0 _first)
    _besa_keyso_space_get("${_first}" _result)
    list(REMOVE_AT _inputs 0)
    foreach(_input IN LISTS _inputs)
      _besa_keyso_space_get("${_input}" _space)
      set(_next)
      foreach(_token IN LISTS _result)
        if("${_token}" IN_LIST _space)
          list(APPEND _next "${_token}")
        endif()
      endforeach()
      set(_result ${_next})
    endforeach()

  elseif(_operation STREQUAL "SETMINUS")
    list(GET _inputs 0 _first)
    _besa_keyso_space_get("${_first}" _result)
    list(REMOVE_AT _inputs 0)
    foreach(_input IN LISTS _inputs)
      _besa_keyso_space_get("${_input}" _space)
      foreach(_token IN LISTS _space)
        list(REMOVE_ITEM _result "${_token}")
      endforeach()
    endforeach()

  elseif(_operation STREQUAL "PRODUCT")
    set(_result "${_BESA_KEYSO_EMPTY}")
    foreach(_input IN LISTS _inputs)
      _besa_keyso_space_get("${_input}" _space)
      set(_next)
      foreach(_left IN LISTS _result)
        foreach(_right IN LISTS _space)
          _besa_keyso_union_tokens("${_left}" "${_right}" _merged)
          list(APPEND _next "${_merged}")
        endforeach()
      endforeach()
      set(_result ${_next})
      list(REMOVE_DUPLICATES _result)
    endforeach()

  else()
    _besa_fatal(
      "besa_keyso_create_feature_space"
      "operation must be UNION, INTERSECTION, SETMINUS, or PRODUCT; got '${OPERATION}'"
    )
  endif()

  _besa_keyso_space_set("${NAME}" ${_result})
endfunction()

# --------------------------------------------------------------------------------------------------
# Internal implementation
# --------------------------------------------------------------------------------------------------

function(_besa_keyso_validate_name FUNCTION_NAME NAME)
  if(NOT "${NAME}" MATCHES "^[A-Za-z0-9][A-Za-z0-9_.+-]*$")
    _besa_fatal("${FUNCTION_NAME}" "name '${NAME}' must use letters, digits, '.', '_', '+', or '-'")
  endif()
endfunction()

# Canonicalize a concrete feature set: deduplicate, sort, join with `|`.
# Empty sets use _BESA_KEYSO_EMPTY so they survive CMake list operations.
function(_besa_keyso_canonicalize OUTPUT_VARIABLE)
  set(_features ${ARGN})
  list(REMOVE_ITEM _features "")
  list(REMOVE_DUPLICATES _features)
  list(SORT _features)
  if(_features)
    string(JOIN "|" _token ${_features})
  else()
    set(_token "${_BESA_KEYSO_EMPTY}")
  endif()
  set("${OUTPUT_VARIABLE}" "${_token}" PARENT_SCOPE)
endfunction()

# Decode the private set token into a CMake list of feature names.
function(_besa_keyso_decode TOKEN OUTPUT_VARIABLE)
  if("${TOKEN}" STREQUAL "${_BESA_KEYSO_EMPTY}")
    set(_features)
  else()
    string(REPLACE "|" ";" _features "${TOKEN}")
  endif()
  set("${OUTPUT_VARIABLE}" "${_features}" PARENT_SCOPE)
endfunction()

function(_besa_keyso_space_property NAME OUTPUT_VARIABLE)
  _besa_normalize_name("${NAME}" _normalized)
  set("${OUTPUT_VARIABLE}" "BESA_FEATURE_SPACE_${_normalized}" PARENT_SCOPE)
endfunction()

# Store sorted, unique concrete-set tokens under a named global property.
function(_besa_keyso_space_set NAME)
  _besa_keyso_validate_name("besa keyso" "${NAME}")
  set(_sets ${ARGN})
  list(REMOVE_DUPLICATES _sets)
  list(SORT _sets)
  _besa_keyso_space_property("${NAME}" _property)
  set_property(GLOBAL PROPERTY "${_property}" "${_sets}")
  get_property(_names GLOBAL PROPERTY BESA_FEATURE_SPACE_NAMES)
  if(NOT "${NAME}" IN_LIST _names)
    set_property(GLOBAL APPEND PROPERTY BESA_FEATURE_SPACE_NAMES "${NAME}")
  endif()
endfunction()

# Read a named space or fail when it has not been registered.
function(_besa_keyso_space_get NAME OUTPUT_VARIABLE)
  _besa_keyso_space_property("${NAME}" _property)
  get_property(_is_set GLOBAL PROPERTY "${_property}" SET)
  if(NOT _is_set)
    _besa_fatal("besa keyso" "unknown feature space '${NAME}'")
  endif()
  get_property(_sets GLOBAL PROPERTY "${_property}")
  set("${OUTPUT_VARIABLE}" "${_sets}" PARENT_SCOPE)
endfunction()

# Merge two concrete-set tokens, preserving canonical representation.
function(_besa_keyso_union_tokens LEFT RIGHT OUTPUT_VARIABLE)
  _besa_keyso_decode("${LEFT}" _left)
  _besa_keyso_decode("${RIGHT}" _right)
  _besa_keyso_canonicalize(_merged ${_left} ${_right})
  set("${OUTPUT_VARIABLE}" "${_merged}" PARENT_SCOPE)
endfunction()

# Check exact membership: the entire concrete set must be a member.
function(_besa_keyso_exact_contains NAME FEATURES OUTPUT_VARIABLE)
  _besa_keyso_space_get("${NAME}" _sets)
  _besa_keyso_canonicalize(_needle ${FEATURES})
  if("${_needle}" IN_LIST _sets)
    set("${OUTPUT_VARIABLE}" TRUE PARENT_SCOPE)
  else()
    set("${OUTPUT_VARIABLE}" FALSE PARENT_SCOPE)
  endif()
endfunction()

# Perform condition matching: any member subset of enabled features matches.
# This differs from exact membership used by project feature-space resolution.
function(_besa_keyso_matches NAME FEATURES OUTPUT_VARIABLE)
  _besa_keyso_space_get("${NAME}" _sets)
  foreach(_token IN LISTS _sets)
    _besa_keyso_decode("${_token}" _required)
    set(_match TRUE)
    foreach(_feature IN LISTS _required)
      if(NOT "${_feature}" IN_LIST FEATURES)
        set(_match FALSE)
        break()
      endif()
    endforeach()
    if(_match)
      set("${OUTPUT_VARIABLE}" TRUE PARENT_SCOPE)
      return()
    endif()
  endforeach()
  set("${OUTPUT_VARIABLE}" FALSE PARENT_SCOPE)
endfunction()

# Reject undeclared atomic feature names in space constructors.
function(_besa_keyso_require_features FUNCTION_NAME)
  if(NOT ARGN)
    _besa_fatal("${FUNCTION_NAME}" "at least one feature is required")
  endif()
  get_property(_declared GLOBAL PROPERTY BESA_DECLARED_FEATURES)
  foreach(_feature IN LISTS ARGN)
    if(NOT "${_feature}" IN_LIST _declared)
      _besa_fatal("${FUNCTION_NAME}" "unknown feature '${_feature}'")
    endif()
  endforeach()
endfunction()
