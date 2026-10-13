# SPDX-FileCopyrightText: 2026 kprof developers
#
# SPDX-License-Identifier: Apache-2.0

cmake_minimum_required(VERSION 3.25)
project(kprof VERSION 0.1.0 LANGUAGES NONE)


include(CTest)
include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/besa/besaConfig.cmake")
include(cmake/features.cmake)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED TRUE)

include(cmake/external.cmake)
include(cmake/clangd.cmake)



besa_configure_complete()

besa_add_subdirectory(DIRECTORY src/cpp TYPE cpp)



if(BUILD_TESTING)

  # Catch2 for unit tests
  find_package(Catch2 3 QUIET)
  if(NOT Catch2_FOUND)
    message(STATUS "Catch2 not found on system, fetching copy.")
    include(FetchContent)
    FetchContent_Declare(
      Catch2
      GIT_REPOSITORY https://github.com/catchorg/Catch2.git
      GIT_TAG v3.16.1
      GIT_SHALLOW TRUE
    )
    FetchContent_MakeAvailable(Catch2)
  endif()

  besa_test_add_directory(
    NAME tests/unit
    PREFIX kprof
    TARGET_LIST kprof::libkprof Catch2::Catch2WithMain
    CMDLINE "--reporter" "compact"
    LABELS unit
  )
endif()
