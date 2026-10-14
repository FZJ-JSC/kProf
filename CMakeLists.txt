# --------------------------------------------------------------------------------------------------
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 kprof developers
# --------------------------------------------------------------------------------------------------
cmake_minimum_required(VERSION 4.3)
project(kprof VERSION 0.1.0)

# The vendored BESA package is made discoverable without using CMAKE_MODULE_PATH.
list(PREPEND CMAKE_PREFIX_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/besa")
find_package(besa CONFIG REQUIRED)

include(cmake/options.cmake)
include(cmake/external.cmake)
include(CTest)

if(BUILD_SOURCE)
  add_subdirectory(src)
endif()

if(BUILD_TESTING)
  add_subdirectory(tests)
endif()
