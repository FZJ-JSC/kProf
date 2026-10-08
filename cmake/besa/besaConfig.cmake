# SPDX-FileCopyrightText: 2026 BESA developers
# SPDX-FileCopyrightText: 2026 kprof developers
#
# SPDX-License-Identifier: Apache-2.0
include_guard(GLOBAL)
set(CMAKE_FIND_PACKAGE_PREFER_CONFIG TRUE)

include("${CMAKE_CURRENT_LIST_DIR}/internal.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/workspace.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/codegen.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/keyso.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/warning.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/format.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/tidy.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/surrogate.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/devtools.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/testmode.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/version.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/package.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/target.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/dependency.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/manifest.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/cpdocs.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/subdirectory.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/test.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/userdocs.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/finalize.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/feature.cmake")
