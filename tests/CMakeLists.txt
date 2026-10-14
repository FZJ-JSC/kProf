# --------------------------------------------------------------------------------------------------
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 kprof developers
# --------------------------------------------------------------------------------------------------
find_package(Catch2 3 CONFIG REQUIRED)

# This library belongs only to the test suite; production sources are optional.
besa_add_library(NAME libtestkprof INSTALL NO)
target_link_libraries(libtestkprof PUBLIC kprof::libkprof Catch2::Catch2WithMain)

add_subdirectory(common)

besa_test_add_directory(
  NAME unit
  PREFIX kprof
  TARGET_LIST kprof::libtestkprof
  LABELS unit
)
