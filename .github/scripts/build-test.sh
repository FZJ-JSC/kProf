#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 kprof developers
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

: "${KPROF_CXX:?KPROF_CXX is required}"

# GCC Toolset provides its own C++ runtime and linker search paths.
if [[ -n "${KPROF_TOOLSET_ENV:-}" ]]; then
  if [[ ! -f "$KPROF_TOOLSET_ENV" ]]; then
    echo "Missing GCC toolset environment: $KPROF_TOOLSET_ENV" >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  source "$KPROF_TOOLSET_ENV"
fi

# The shared bootstrap installs Spack but does not create an action-specific
# spack-bash shell. Activate Spack in this process before loading dependencies.
# shellcheck source=/dev/null
source "${SPACK_ROOT:?Run kprof-dev compiler bootstrap first}/share/spack/setup-env.sh"

# Spack supplies only the development dependencies (CMake, Ninja, Lyra, etc.).
spack env activate "${KPROF_DEPS_ENV:?Install compiler-specific dependencies first}"
export CXX="$KPROF_CXX"
export CC="${KPROF_CC:?Select a matching C compiler first}"
"$CXX" --version
cmake --version
cmake --preset ci
cmake --build --preset ci --parallel
ctest --preset ci --no-tests=error
