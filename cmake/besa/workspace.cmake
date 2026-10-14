# --------------------------------------------------------------------------------------------------
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 besa developers
# --------------------------------------------------------------------------------------------------
# Manage BESA-owned working files in one build-tree namespace.
#
# Generated source, documentation for multiple configurations or versions,
# and persistent configure-time caches should not be mixed with source files
# or ordinary CMake build products. By default BESA organizes them under:
#
#   <build>/besa/codegen/           generated source and header trees
#   <build>/besa/docs/              current and versioned documentation
#   <build>/besa/configure_cache/   configure-time reusable artifacts
#
# BESA_WORKSPACE may override this root. All derived locations are published
# as internal cache variables for other BESA modules to consume. Initialization
# is normally performed by besa_finalize_options(); projects need not call it.

include_guard(GLOBAL)

# Initialize BESA-owned paths strictly within the build tree by default:
#
#   <build>/besa/
#     codegen/            generator-owned prefixes
#     docs/               documentation outputs
#     configure_cache/    configure-time caches
#
# besa_finalize_options() calls this, so projects normally never call it directly.

# --------------------------------------------------------------------------------------------------
# Public API
# --------------------------------------------------------------------------------------------------

# Initialize the workspace paths and create codegen/, docs/, and configure_cache/.
# Usually called by besa_finalize_options(); BESA_WORKSPACE overrides the root.
function(besa_workspace_initialize)
  if(NOT DEFINED BESA_WORKSPACE OR "${BESA_WORKSPACE}" STREQUAL "")
    set(_workspace "${PROJECT_BINARY_DIR}/besa")
    set(BESA_WORKSPACE "${_workspace}" CACHE PATH "BESA workspace root")
  endif()
  get_filename_component(_workspace "${BESA_WORKSPACE}" ABSOLUTE)
  set(BESA_BUILD_DIRECTORY "${PROJECT_BINARY_DIR}" CACHE INTERNAL "BESA build directory")
  set(
    BESA_CODEGEN_DIRECTORY "${_workspace}/codegen"
    CACHE INTERNAL "BESA code-generation directory"
  )
  set(BESA_DOCS_DIRECTORY "${_workspace}/docs" CACHE INTERNAL "BESA documentation directory")
  set(
    BESA_CONFIGURE_CACHE_DIRECTORY "${_workspace}/configure_cache"
    CACHE INTERNAL "BESA configure cache"
  )
  file(MAKE_DIRECTORY
    "${BESA_CODEGEN_DIRECTORY}"
    "${BESA_DOCS_DIRECTORY}"
    "${BESA_CONFIGURE_CACHE_DIRECTORY}"
  )
endfunction()
