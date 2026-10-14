# --------------------------------------------------------------------------------------------------
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 kprof developers
# --------------------------------------------------------------------------------------------------

# Define the project library and attach its implementation directories.
besa_add_library(NAME libkprof INSTALL YES)

besa_add_directory(LIBRARY libkprof ROOT "${CMAKE_CURRENT_SOURCE_DIR}/cpp" TYPE cpp)
