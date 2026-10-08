# SPDX-FileCopyrightText: 2026 BESA developers
# SPDX-FileCopyrightText: 2026 kprof developers
#
# SPDX-License-Identifier: Apache-2.0

include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/internal.cmake")

# Register explicit cpdocs targets for API-only development and CI.
function(besa_add_cpdocs_docs)
  _besa_require_config_complete("besa_add_cpdocs_docs")
  include(GNUInstallDirs)

  cmake_parse_arguments(
    ARG
    "NO_INSTALL"
    "NAME;CONFIG;OUTPUT_DIRECTORY;VERSIONS_NAME;VERSIONS_OUTPUT_DIRECTORY;INSTALL_DIRECTORY;VERSIONS_INSTALL_DIRECTORY"
    ""
    ${ARGN}
  )
  _besa_require_no_unparsed("besa_add_cpdocs_docs" "${ARG_UNPARSED_ARGUMENTS}")
  _besa_require_value("besa_add_cpdocs_docs" "NAME" "${ARG_NAME}")
  _besa_require_value("besa_add_cpdocs_docs" "CONFIG" "${ARG_CONFIG}")

  if(NOT ARG_OUTPUT_DIRECTORY)
    set(ARG_OUTPUT_DIRECTORY "${BESA_DOCS_DIRECTORY}/api/current")
  endif()
  if(NOT ARG_VERSIONS_NAME)
    set(ARG_VERSIONS_NAME "${ARG_NAME}.versions")
  endif()
  if(NOT ARG_VERSIONS_OUTPUT_DIRECTORY)
    set(ARG_VERSIONS_OUTPUT_DIRECTORY "${BESA_DOCS_DIRECTORY}/api/versions")
  endif()

  get_filename_component(
    _besa_cpdocs_config
    "${ARG_CONFIG}"
    ABSOLUTE
    BASE_DIR "${PROJECT_SOURCE_DIR}"
  )
  if(NOT EXISTS "${_besa_cpdocs_config}")
    message(FATAL_ERROR "besa_add_cpdocs_docs: CONFIG does not exist: ${_besa_cpdocs_config}")
  endif()

  find_program(_besa_cpdocs NAMES cpdocs REQUIRED)
  set(_besa_cpdocs_work "${BESA_DOCS_DIRECTORY}/work/cpdocs")

  add_custom_target(
    "${ARG_NAME}"
    COMMAND "${CMAKE_COMMAND}" -E rm -rf "${ARG_OUTPUT_DIRECTORY}"
    COMMAND
      "${_besa_cpdocs}" --config "${_besa_cpdocs_config}" build
      --output-directory "${ARG_OUTPUT_DIRECTORY}"
      --work-directory "${_besa_cpdocs_work}/current"
      --version main
    WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
    COMMENT "Generating semantic API documentation with cpdocs"
    VERBATIM
  )
  add_custom_target(
    "${ARG_VERSIONS_NAME}"
    COMMAND "${CMAKE_COMMAND}" -E rm -rf "${ARG_VERSIONS_OUTPUT_DIRECTORY}"
    COMMAND
      "${_besa_cpdocs}" --config "${_besa_cpdocs_config}" versions
      --output-directory "${ARG_VERSIONS_OUTPUT_DIRECTORY}"
      --work-directory "${_besa_cpdocs_work}/versions"
    WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
    COMMENT "Generating versioned semantic API documentation with cpdocs"
    VERBATIM
  )

  if(NOT ARG_NO_INSTALL)
    if(NOT ARG_INSTALL_DIRECTORY)
      set(ARG_INSTALL_DIRECTORY "${CMAKE_INSTALL_DOCDIR}/api/current")
    endif()
    if(NOT ARG_VERSIONS_INSTALL_DIRECTORY)
      set(ARG_VERSIONS_INSTALL_DIRECTORY "${CMAKE_INSTALL_DOCDIR}/api")
    endif()
    install(DIRECTORY "${ARG_OUTPUT_DIRECTORY}/" DESTINATION "${ARG_INSTALL_DIRECTORY}" OPTIONAL)
    install(
      DIRECTORY "${ARG_VERSIONS_OUTPUT_DIRECTORY}/"
      DESTINATION "${ARG_VERSIONS_INSTALL_DIRECTORY}"
      OPTIONAL
    )
  endif()
endfunction()

# Register the complete user-documentation site. ProperDocs invokes cpdocs ProperDocs, so there is no
# second site build and no assembly phase. NAME is the deployable site target; NAME.api and
# NAME.api.versions remain convenient explicit cpdocs targets.
function(besa_add_user_docs)
  _besa_require_config_complete("besa_add_user_docs")
  include(GNUInstallDirs)

  cmake_parse_arguments(
    ARG
    ""
    "NAME;PROPERDOCS_CONFIG;CPDOCS_CONFIG;OUTPUT_DIRECTORY;INSTALL_DIRECTORY"
    ""
    ${ARGN}
  )
  _besa_require_no_unparsed("besa_add_user_docs" "${ARG_UNPARSED_ARGUMENTS}")
  _besa_require_value("besa_add_user_docs" "NAME" "${ARG_NAME}")
  _besa_require_value("besa_add_user_docs" "PROPERDOCS_CONFIG" "${ARG_PROPERDOCS_CONFIG}")
  _besa_require_value("besa_add_user_docs" "CPDOCS_CONFIG" "${ARG_CPDOCS_CONFIG}")

  if(NOT ARG_OUTPUT_DIRECTORY)
    set(ARG_OUTPUT_DIRECTORY "${BESA_DOCS_DIRECTORY}/site")
  endif()
  if(NOT ARG_INSTALL_DIRECTORY)
    set(ARG_INSTALL_DIRECTORY "${CMAKE_INSTALL_DOCDIR}")
  endif()

  get_filename_component(
    _besa_properdocs_config
    "${ARG_PROPERDOCS_CONFIG}"
    ABSOLUTE
    BASE_DIR "${PROJECT_SOURCE_DIR}"
  )
  if(NOT EXISTS "${_besa_properdocs_config}")
    message(FATAL_ERROR "besa_add_user_docs: PROPERDOCS_CONFIG does not exist: ${_besa_properdocs_config}")
  endif()

  find_program(_besa_properdocs NAMES properdocs REQUIRED)

  besa_add_cpdocs_docs(
    NAME "${ARG_NAME}.api"
    CONFIG "${ARG_CPDOCS_CONFIG}"
    OUTPUT_DIRECTORY "${BESA_DOCS_DIRECTORY}/api/current"
    VERSIONS_OUTPUT_DIRECTORY "${BESA_DOCS_DIRECTORY}/api/versions"
    NO_INSTALL
  )

  add_custom_target(
    "${ARG_NAME}"
    COMMAND
      "${_besa_properdocs}" build
      --config-file "${_besa_properdocs_config}"
      --site-dir "${ARG_OUTPUT_DIRECTORY}"
    WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
    COMMENT "Generating the ProperDocs site with the cpdocs API reference"
    VERBATIM
  )

  install(
    DIRECTORY "${ARG_OUTPUT_DIRECTORY}/"
    DESTINATION "${ARG_INSTALL_DIRECTORY}"
    OPTIONAL
  )
endfunction()
