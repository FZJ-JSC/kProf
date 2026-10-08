# SPDX-FileCopyrightText: 2026 kprof developers
#
# SPDX-License-Identifier: Apache-2.0

cmake_minimum_required(VERSION 3.25)
project(kprof VERSION 0.1.0 LANGUAGES NONE)

include(CTest)
include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/besa/besaConfig.cmake")
include(cmake/features.cmake)
include(cmake/external.cmake)

besa_configure_complete()

besa_add_subdirectory(DIRECTORY src/cpp TYPE cpp)

if(BUILD_TESTING)
  besa_test_add_directory(
    NAME tests/unit
    PREFIX kprof
    TARGET_LIST kprof::libkprof
    LABELS unit
  )
endif()
