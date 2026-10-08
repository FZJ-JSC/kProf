# SPDX-FileCopyrightText: 2026 BESA developers
# SPDX-FileCopyrightText: 2026 kprof developers
#
# SPDX-License-Identifier: Apache-2.0
include_guard(GLOBAL)

# Initialize the BESA workspace layout. By default the workspace is the parent of the build tree:
#
#   <workspace>/
#     <build>/            PROJECT_BINARY_DIR
#     codegen/            generator-owned prefixes
#     docs/               documentation outputs
#     configure_cache/    configure-time caches
#
# besa_configure_complete() calls this, so projects normally never call it directly.
function(besa_workspace_initialize)
  if(NOT DEFINED BESA_WORKSPACE OR "${BESA_WORKSPACE}" STREQUAL "")
    get_filename_component(_workspace "${PROJECT_BINARY_DIR}" DIRECTORY)
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
