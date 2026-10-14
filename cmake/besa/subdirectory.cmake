# --------------------------------------------------------------------------------------------------
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 besa developers
# --------------------------------------------------------------------------------------------------
# Attach semantic directory trees to user-selected build targets.
#
# Public APIs create source units from ROOT/DIRECTORY with lib/, include/, and
# optional module/ or mod/ subtrees. Built-in types enable C, C++, CUDA, HIP
# or Fortran; generated types invoke registered callbacks and then lower the
# resulting source tree in the same way. Generated-output ownership belongs to
# codegen.cmake; this module owns type registration, selection and attachment.
# The public entry points are macros where enable_language() must execute in
# the calling CMake directory scope, not inside a function scope.

include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/internal.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/keyso.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/manifest.cmake")

# --------------------------------------------------------------------------------------------------
# Public API
# --------------------------------------------------------------------------------------------------

# Register a generated source-directory type before option finalization.
#   besa_register_subdirectory_type(<type> GENERATED FUNCTION <callback> RESOLVES_TO <builtin>)
# The callback receives SOURCE_DIR, BUILD_DIR, OUTPUT_DIR and OUTPUT_TARGET_VARIABLE.
# The resolved built-in type determines language activation and source discovery.
function(besa_register_subdirectory_type TYPE)
  _besa_require_config_open("besa_register_subdirectory_type")
  if("${TYPE}" STREQUAL "")
    _besa_fatal("besa_register_subdirectory_type" "type name is required")
  endif()
  cmake_parse_arguments(ARG "GENERATED" "FUNCTION;RESOLVES_TO" "" ${ARGN})
  _besa_require_no_unparsed("besa_register_subdirectory_type" "${ARG_UNPARSED_ARGUMENTS}")
  foreach(_required FUNCTION RESOLVES_TO)
    _besa_require_value("besa_register_subdirectory_type" "${_required}" "${ARG_${_required}}")
  endforeach()
  _besa_subdir_initialize_types()
  _besa_subdir_type_get("${TYPE}" KIND _existing)
  if(_existing)
    _besa_fatal("besa_register_subdirectory_type" "TYPE '${TYPE}' is already registered")
  endif()
  _besa_subdir_type_get("${ARG_RESOLVES_TO}" KIND _resolved_kind)
  if(NOT _resolved_kind STREQUAL "builtin")
    _besa_fatal("besa_register_subdirectory_type" "RESOLVES_TO must name a built-in type")
  endif()
  if(NOT COMMAND "${ARG_FUNCTION}")
    _besa_fatal("besa_register_subdirectory_type" "FUNCTION '${ARG_FUNCTION}' does not exist")
  endif()
  if(NOT ARG_GENERATED)
    _besa_fatal("besa_register_subdirectory_type" "custom subdirectory types must currently be GENERATED")
  endif()

  _besa_subdir_type_set("${TYPE}" KIND custom)
  _besa_subdir_type_set("${TYPE}" FUNCTION "${ARG_FUNCTION}")
  _besa_subdir_type_set("${TYPE}" RESOLVES_TO "${ARG_RESOLVES_TO}")
  _besa_subdir_type_set("${TYPE}" GENERATED TRUE)
  set_property(GLOBAL APPEND PROPERTY BESA_SUBDIR_TYPES "${TYPE}")
endfunction()

# Add a semantic unit without the library-only validation of besa_add_directory.
#   besa_add_subdirectory(DIRECTORY <path> TYPE <type> [LIBRARY <target>]
#                         [CONDITION <feature-space>] [ARGS ...])
# The bin type creates standalone executables and leaves source-language
# inference to CMake. Other types require LIBRARY and use TYPE to enable a
# language; file extensions do not determine semantic types.
# A generated type invokes its registered callback before source discovery.
macro(besa_add_subdirectory)
  _besa_require_config_complete("besa_add_subdirectory")
  cmake_parse_arguments(BESA_SUBDIR "" "DIRECTORY;TYPE;CONDITION;LIBRARY" "ARGS" ${ARGN})
  _besa_require_no_unparsed("besa_add_subdirectory" "${BESA_SUBDIR_UNPARSED_ARGUMENTS}")
  _besa_require_value("besa_add_subdirectory" "DIRECTORY" "${BESA_SUBDIR_DIRECTORY}")
  _besa_require_value("besa_add_subdirectory" "TYPE" "${BESA_SUBDIR_TYPE}")
  _besa_subdir_initialize_types()
  _besa_subdir_type_get("${BESA_SUBDIR_TYPE}" KIND _besa_kind)
  if(NOT _besa_kind)
    _besa_fatal("besa_add_subdirectory" "unknown TYPE '${BESA_SUBDIR_TYPE}'")
  endif()

  set(_besa_selected TRUE)
  if(BESA_SUBDIR_CONDITION)
    get_property(_besa_features GLOBAL PROPERTY BESA_ENABLED_FEATURES)
    _besa_keyso_matches("${BESA_SUBDIR_CONDITION}" "${_besa_features}" _besa_selected)
  endif()

  if(_besa_selected)
    if(NOT BESA_SUBDIR_TYPE STREQUAL "bin")
      if(NOT BESA_SUBDIR_LIBRARY OR NOT TARGET "${BESA_SUBDIR_LIBRARY}")
        _besa_fatal("besa_add_subdirectory" "LIBRARY must name an existing target; call besa_add_library first")
      endif()
    endif()
    get_filename_component(_besa_source "${BESA_SUBDIR_DIRECTORY}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
    if(NOT IS_DIRECTORY "${_besa_source}")
      _besa_fatal("besa_add_subdirectory" "DIRECTORY does not exist: ${_besa_source}")
    endif()
    file(RELATIVE_PATH _besa_relative "${PROJECT_SOURCE_DIR}" "${_besa_source}")
    string(REGEX REPLACE "[^A-Za-z0-9_.-]" "_" _besa_unit_key "${_besa_relative}")
    set(_besa_build "${PROJECT_BINARY_DIR}/besa/subdirectories/${_besa_unit_key}")
    file(MAKE_DIRECTORY "${_besa_build}")
    if(_besa_kind STREQUAL "builtin")
      _besa_manifest_register_unit(ID "${_besa_relative}" TYPE "${BESA_SUBDIR_TYPE}" ROOT "${_besa_source}")
      _besa_subdir_enable_type_languages("${BESA_SUBDIR_TYPE}")
      _besa_subdir_lower("${_besa_source}" "${BESA_SUBDIR_TYPE}" FALSE "${BESA_SUBDIR_LIBRARY}")

    else()
      _besa_subdir_type_get("${BESA_SUBDIR_TYPE}" FUNCTION _besa_function)
      _besa_subdir_type_get("${BESA_SUBDIR_TYPE}" RESOLVES_TO _besa_resolved)
      _besa_subdir_type_get("${BESA_SUBDIR_TYPE}" GENERATED _besa_generated)
      if(NOT _besa_generated)
        _besa_fatal("besa_add_subdirectory" "custom TYPE '${BESA_SUBDIR_TYPE}' is not generated")
      endif()
      if(NOT DEFINED BESA_CODEGEN_DIRECTORY OR "${BESA_CODEGEN_DIRECTORY}" STREQUAL "")
        besa_workspace_initialize()
      endif()
      set(_besa_output "${BESA_CODEGEN_DIRECTORY}/${_besa_unit_key}")
      foreach(_besa_directory IN ITEMS include lib)
        file(MAKE_DIRECTORY "${_besa_output}/${_besa_directory}")
      endforeach()
      if(_besa_resolved STREQUAL "fortran")
        file(MAKE_DIRECTORY "${_besa_output}/mod")
      endif()

      set(_besa_target "")
      cmake_language(
        CALL "${_besa_function}"
        SOURCE_DIR "${_besa_source}"
        BUILD_DIR "${_besa_build}"
        OUTPUT_DIR "${_besa_output}"
        OUTPUT_TARGET_VARIABLE _besa_target
        ${BESA_SUBDIR_ARGS}
      )
      if(_besa_target)
        _besa_codegen_register_target("${_besa_unit_key}" "${_besa_target}")
      endif()
      _besa_manifest_register_unit(
        ID "${_besa_relative}" TYPE "${_besa_resolved}" ROOT "${_besa_output}"
        SOURCE_TYPE "${BESA_SUBDIR_TYPE}" GENERATED
      )
      _besa_subdir_enable_type_languages("${_besa_resolved}")
      _besa_subdir_lower("${_besa_output}" "${_besa_resolved}" TRUE "${BESA_SUBDIR_LIBRARY}")
      if(_besa_target AND NOT BESA_SUBDIR_TYPE STREQUAL "bin")
        add_dependencies("${BESA_SUBDIR_LIBRARY}" "${_besa_target}")
      endif()
    endif()
  endif()
  unset(BESA_SUBDIR_LIBRARY)
  unset(BESA_SUBDIR_DIRECTORY)
  unset(BESA_SUBDIR_TYPE)
  unset(BESA_SUBDIR_CONDITION)
  unset(BESA_SUBDIR_ARGS)
endmacro()

# Attach a semantic ROOT directory to a previously created library.
#   besa_add_directory(LIBRARY <target> ROOT <path> TYPE <type>
#                      [CONDITION <feature-space>] [ARGS ...])
# Each call adds lib/ implementations, public include/ headers, and optional
# C++ module/ or Fortran mod/ files. Calls can target different libraries.
# CONDITION is matched against the finalized feature configuration.
macro(besa_add_directory)
  _besa_require_config_complete("besa_add_directory")
  cmake_parse_arguments(BESA_DIRECTORY "" "LIBRARY;ROOT;TYPE;CONDITION" "ARGS" ${ARGN})
  _besa_require_no_unparsed("besa_add_directory" "${BESA_DIRECTORY_UNPARSED_ARGUMENTS}")
  foreach(_required LIBRARY ROOT TYPE)
    _besa_require_value("besa_add_directory" "${_required}" "${BESA_DIRECTORY_${_required}}")
  endforeach()
  if(NOT TARGET "${BESA_DIRECTORY_LIBRARY}")
    _besa_fatal("besa_add_directory" "LIBRARY target '${BESA_DIRECTORY_LIBRARY}' does not exist; call besa_add_library first")
  endif()
  get_target_property(_besa_directory_aliased "${BESA_DIRECTORY_LIBRARY}" ALIASED_TARGET)
  get_target_property(_besa_directory_imported "${BESA_DIRECTORY_LIBRARY}" IMPORTED)
  if(_besa_directory_aliased OR _besa_directory_imported)
    _besa_fatal("besa_add_directory" "LIBRARY must be a writable local target")
  endif()
  get_target_property(_besa_directory_type "${BESA_DIRECTORY_LIBRARY}" TYPE)
  if(NOT _besa_directory_type MATCHES "^(STATIC_LIBRARY|SHARED_LIBRARY|MODULE_LIBRARY|OBJECT_LIBRARY|INTERFACE_LIBRARY)$")
    _besa_fatal("besa_add_directory" "LIBRARY must name a library target")
  endif()
  _besa_subdir_initialize_types()
  _besa_subdir_type_get("${BESA_DIRECTORY_TYPE}" KIND _besa_directory_kind)
  if(NOT _besa_directory_kind OR BESA_DIRECTORY_TYPE STREQUAL "bin")
    _besa_fatal("besa_add_directory" "TYPE must name a library-capable semantic type")
  endif()

  set(_besa_directory_arguments
    DIRECTORY "${BESA_DIRECTORY_ROOT}"
    TYPE "${BESA_DIRECTORY_TYPE}"
    LIBRARY "${BESA_DIRECTORY_LIBRARY}"
  )
  if(BESA_DIRECTORY_CONDITION)
    list(APPEND _besa_directory_arguments CONDITION "${BESA_DIRECTORY_CONDITION}")
  endif()
  if(BESA_DIRECTORY_ARGS)
    list(APPEND _besa_directory_arguments ARGS ${BESA_DIRECTORY_ARGS})
  endif()
  besa_add_subdirectory(${_besa_directory_arguments})
  unset(_besa_directory_arguments)
  unset(_besa_directory_aliased)
  unset(_besa_directory_imported)
  unset(_besa_directory_kind)
  unset(_besa_directory_type)
  unset(BESA_DIRECTORY_LIBRARY)
  unset(BESA_DIRECTORY_ROOT)
  unset(BESA_DIRECTORY_TYPE)
  unset(BESA_DIRECTORY_CONDITION)
  unset(BESA_DIRECTORY_ARGS)
endmacro()

# --------------------------------------------------------------------------------------------------
# Internal implementation
# --------------------------------------------------------------------------------------------------

function(_besa_subdir_type_property TYPE FIELD OUTPUT_VARIABLE)
  _besa_normalize_name("${TYPE}" _type)
  set("${OUTPUT_VARIABLE}" "BESA_SUBDIR_TYPE_${_type}_${FIELD}" PARENT_SCOPE)
endfunction()

# Store a named type-registry field in a global property.
# Built-in and generated types use the same representation.
function(_besa_subdir_type_set TYPE FIELD VALUE)
  _besa_subdir_type_property("${TYPE}" "${FIELD}" _property)
  set_property(GLOBAL PROPERTY "${_property}" "${VALUE}")
endfunction()

function(_besa_subdir_register_builtin TYPE LANGUAGE)
  _besa_subdir_type_set("${TYPE}" KIND builtin)
  _besa_subdir_type_set("${TYPE}" LANGUAGE "${LANGUAGE}")
  set_property(GLOBAL APPEND PROPERTY BESA_SUBDIR_TYPES "${TYPE}")
endfunction()

function(_besa_subdir_type_get TYPE FIELD OUTPUT_VARIABLE)
  _besa_subdir_type_property("${TYPE}" "${FIELD}" _property)
  get_property(_set GLOBAL PROPERTY "${_property}" SET)
  if(NOT _set)
    set("${OUTPUT_VARIABLE}" "" PARENT_SCOPE)
    return()
  endif()
  get_property(_value GLOBAL PROPERTY "${_property}")
  set("${OUTPUT_VARIABLE}" "${_value}" PARENT_SCOPE)
endfunction()

function(_besa_subdir_initialize_types)
  get_property(_done GLOBAL PROPERTY BESA_SUBDIR_TYPES_INITIALIZED)
  if(_done)
    return()
  endif()
  _besa_subdir_register_builtin(c C)
  _besa_subdir_register_builtin(cpp CXX)
  _besa_subdir_register_builtin(cuda CUDA)
  _besa_subdir_register_builtin(hip HIP)
  _besa_subdir_register_builtin(fortran Fortran)
  _besa_subdir_register_builtin(bin "")
  set_property(GLOBAL PROPERTY BESA_SUBDIR_TYPES_INITIALIZED TRUE)
endfunction()

macro(_besa_subdir_enable_language TYPE)
  if(NOT "${TYPE}" STREQUAL "bin")
    _besa_subdir_type_get("${TYPE}" LANGUAGE _besa_language)
    if(_besa_language)
      get_property(_besa_enabled_languages GLOBAL PROPERTY ENABLED_LANGUAGES)
      if(NOT "${_besa_language}" IN_LIST _besa_enabled_languages)
        enable_language("${_besa_language}")
      endif()
    endif()
  endif()
endmacro()

# Only the explicitly declared semantic type may activate a language.
# Executables have no semantic language type: CMake infers their language from
# the source files and the languages enabled by the project/other units.
macro(_besa_subdir_enable_type_languages TYPE)
  if(NOT "${TYPE}" STREQUAL "bin")
    _besa_subdir_enable_language("${TYPE}")
  endif()
endmacro()

# All files in implementation trees are sources. Assign the semantic language
# explicitly so even an unconventional extension is passed to that compiler,
# rather than silently classified by CMake as a noncompiled attachment.
function(_besa_subdir_assign_source_language SOURCES LANGUAGE)
  if(SOURCES)
    set_source_files_properties(${SOURCES} PROPERTIES LANGUAGE "${LANGUAGE}")
  endif()
endfunction()

# Discover the lib/, include/, mod/ and module/ trees beneath ROOT.
# PRIVATE compiled sources and PUBLIC/INTERFACE header file sets use the
# supplied LIBRARY, which may differ from the project default.
function(_besa_subdir_lower_library LIBRARY ROOT TYPE GENERATED)
  if(NOT LIBRARY OR NOT TARGET "${LIBRARY}")
    _besa_fatal("besa_add_subdirectory" "LIBRARY must name an existing target; call besa_add_library first")
  endif()
  set(_library "${LIBRARY}")
  file(GLOB_RECURSE _headers LIST_DIRECTORIES FALSE CONFIGURE_DEPENDS "${ROOT}/include/*")
  file(GLOB_RECURSE _sources LIST_DIRECTORIES FALSE CONFIGURE_DEPENDS "${ROOT}/lib/*")
  if(TYPE STREQUAL "cpp")
    file(GLOB_RECURSE _cpp_modules LIST_DIRECTORIES FALSE CONFIGURE_DEPENDS "${ROOT}/module/*")
  endif()
  if(TYPE STREQUAL "fortran")
    file(GLOB_RECURSE _modules LIST_DIRECTORIES FALSE CONFIGURE_DEPENDS "${ROOT}/mod/*")
  else()
    set(_modules)
  endif()

  if(_headers OR _sources OR _modules OR _cpp_modules)
    get_target_property(_library_type "${_library}" TYPE)
    if(_library_type STREQUAL "INTERFACE_LIBRARY")
      if(_sources OR _modules OR _cpp_modules)
        _besa_fatal("besa_add_directory" "INTERFACE library '${_library}' cannot contain compiled sources")
      endif()
      set(_visibility INTERFACE)
    else()
      set(_visibility PUBLIC)
      _besa_subdir_type_get("${TYPE}" LANGUAGE _source_language)
      _besa_subdir_assign_source_language("${_sources}" "${_source_language}")
      _besa_subdir_assign_source_language("${_modules}" "${_source_language}")
      if(_sources OR _modules)
        target_sources("${_library}" PRIVATE ${_sources} ${_modules})
      endif()
    endif()
    if(_cpp_modules)
      # CMake CXX_MODULES file sets remain subject to the toolchain/preset
      # standard. BESA never adds target_compile_features() here.
      _besa_subdir_assign_source_language("${_cpp_modules}" CXX)
      target_sources("${_library}" PUBLIC FILE_SET CXX_MODULES BASE_DIRS "${ROOT}/module" FILES ${_cpp_modules})
    endif()
    if(_headers)
      target_sources("${_library}" ${_visibility} FILE_SET HEADERS BASE_DIRS "${ROOT}/include" FILES ${_headers})
    endif()
    if(IS_DIRECTORY "${ROOT}/include" OR GENERATED)
      # Used by deferred surrogate checks: headers inherit the declared
      # semantic language of their source tree, never their suffix.
      _besa_subdir_type_get("${TYPE}" LANGUAGE _header_language)
      set_property(TARGET "${_library}" APPEND PROPERTY
        BESA_INTERNAL_HEADER_ROOTS "${ROOT}/include")
      set_property(TARGET "${_library}" APPEND PROPERTY
        BESA_INTERNAL_HEADER_LANGUAGES "${_header_language}")
      target_include_directories(
        "${_library}" ${_visibility}
        $<BUILD_INTERFACE:${ROOT}/include>
        $<INSTALL_INTERFACE:include>
      )
    endif()
    if(GENERATED AND TARGET codegen)
      add_dependencies("${_library}" codegen)
    endif()
  endif()
endfunction()

function(_besa_subdir_lower_bin ROOT)
  # Every regular file in bin/ declares an executable. Do not filter by
  # extension, guess a language, or link to a conventional project library.
  file(GLOB _sources LIST_DIRECTORIES FALSE CONFIGURE_DEPENDS "${ROOT}/*")
  foreach(_source IN LISTS _sources)
    get_filename_component(_target "${_source}" NAME_WE)
    besa_add_executable(NAME "${_target}" SOURCES "${_source}")
  endforeach()
endfunction()

function(_besa_subdir_lower ROOT TYPE GENERATED LIBRARY)
  if(TYPE STREQUAL "bin")
    _besa_subdir_lower_bin("${ROOT}")
  else()
    _besa_subdir_lower_library("${LIBRARY}" "${ROOT}" "${TYPE}" "${GENERATED}")
  endif()
endfunction()

# Initialize built-in source types when the module is loaded.
_besa_subdir_initialize_types()
