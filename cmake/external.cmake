# --------------------------------------------------------------------------------------------------
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 kprof developers
# --------------------------------------------------------------------------------------------------
# External dependencies.

besa_dependency_add(NAME lyra)

if (BUILD_TESTING)
  besa_dependency_add(NAME Catch2 VERSION 3 KIND DEV)
endif()
