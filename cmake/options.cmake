# --------------------------------------------------------------------------------------------------
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 kprof developers
# --------------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------
# PROJECT OPTIONS
# --------------------------------------------------------------------------------------------------
set(PROJECT_FEATURE "none" CACHE STRING "Selected project features")
besa_set_feature_variable(PROJECT_FEATURE)
# Declare supported features with besa_add_feature(name); all combinations are valid by default.
# A C++ module/ directory is optional; only place compilable module sources in it.
# besa_features_conflict(mpi gpu)

# --------------------------------------------------------------------------------------------------
# BUILD OPTIONS
# --------------------------------------------------------------------------------------------------
set(BUILD_DEVTOOLS "none" CACHE STRING "Enabled development tools")
set(BUILD_WARNINGS "minimal" CACHE STRING "Warning policies (none, minimal, extra, everything, werror)")
option(BUILD_TESTING "Build Tests" OFF)
option(BUILD_DOC "Build Documentation" OFF)
option(BUILD_SOURCE "Build Source" ON)
set(TEST_MODE "commit" CACHE STRING "Test Mode")
besa_test_modes_add(MODES commit)

# --------------------------------------------------------------------------------------------------
# PACKAGING OPTIONS (The options meant for package maintainers)
# --------------------------------------------------------------------------------------------------
# Identifiers operate on an honor system. Coordinate IDs in dev/etc/pkg_builder_id.yml.
set(PKGBUILDER_ID "vanilla" CACHE STRING "ID for a Package Maintainer")
# Downstream package revision, independent of the upstream version.
set(PKGBUILDER_REVISION "1" CACHE STRING "Revision of Package Build")

# --------------------------------------------------------------------------------------------------
# RELEASE OPTIONS (Intended for Release Management)
# --------------------------------------------------------------------------------------------------
# dev uses the Git-based version; release, alpha, beta, and rc describe releases.
set(RELEASE_TYPE "dev" CACHE STRING "Type of Release")
set_property(CACHE RELEASE_TYPE PROPERTY STRINGS dev release alpha beta rc)
# For example, use 1 for the prerelease rc-1.
set(RELEASE_REVISION "1" CACHE STRING "Revision of Release")

# --------------------------------------------------------------------------------------------------
# OPTION METADATA
# --------------------------------------------------------------------------------------------------
besa_register_options(GROUP project VARIABLES PROJECT_FEATURE)
besa_register_options(GROUP build VARIABLES
  BUILD_DEVTOOLS BUILD_WARNINGS BUILD_TESTING BUILD_DOC BUILD_SOURCE TEST_MODE)
besa_register_options(GROUP packaging VARIABLES PKGBUILDER_ID PKGBUILDER_REVISION)
besa_register_options(GROUP release VARIABLES RELEASE_TYPE RELEASE_REVISION)

# Resolve features and cache options before any sources or tests are added.
besa_finalize_options()
