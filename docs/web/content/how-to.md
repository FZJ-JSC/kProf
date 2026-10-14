# How-to

This section collects task-oriented instructions for working with kprof.

## Install the development dependencies

Spack provides CMake (at least 4.3), Ninja and, with `+test`, Catch2:

```console
spack -e dev install
```

Activate the environment in a shell initialized for Spack (or use the
`spack-bash` shell in GitHub Actions):

```console
spack env activate dev
cmake --preset gcc-debug
cmake --build --preset gcc-debug --parallel
ctest --preset gcc-debug
```

## Reuse the CI Spack buildcache

The GitHub Actions compiler matrix installs GCC and Clang from their APT
repositories, and NVHPC from NVIDIA's APT repository. Spack installs only
the development dependencies (CMake, Ninja and Catch2), using the runner's
existing GCC to compile them when binaries are unavailable.

The Spack dependencies use a binary cache in GitHub Container Registry (GHCR)
as well as Spack's public cache. Each compiler/version job has its own OCI image:

```text
oci://ghcr.io/<owner>/<repository>-spack-<compiler>-<version>
```

For example, the GCC 16 job reads and writes
`oci://ghcr.io/<owner>/<repository>-spack-gcc-16`.
Spack checks the configured mirrors during installation and builds missing
dependencies from source. Successful development dependency installations are
published with an updated buildcache index. Pull requests only consume binaries;
they do not publish them. The jobs use `GITHUB_TOKEN` with `packages: write`
permission for publishing; no separate registry secret is required.

The compilers (including NVHPC) and the repository's CMake build output are
not Spack-installed packages and are **not** uploaded to this buildcache.

The CI buildcache uses unsigned Spack binaries and a padded install tree at
`/opt/spack`. Only consume this cache from repositories and maintainers you
trust. To pull a private GHCR package, the GitHub Actions token must have
access to that package; adjust the package's Actions permissions if necessary.

## Select a C++ compiler

All configure presets inherit C++20 (`CMAKE_CXX_STANDARD=20`), with the
standard required and compiler extensions disabled. The `ci` preset uses
Ninja, enables tests, and selects its compiler from the `CXX` environment
variable. For example:

```console
CXX=clang++ cmake --preset ci
cmake --build --preset ci --parallel
ctest --preset ci
```

Use the same `ci` preset with `CXX=g++` or `CXX=nvc++`. The development
presets (`gcc-debug`, `gcc-relwithdebinfo`, `clang-debug`, and
`clang-relwithdebinfo`) select their compilers directly.

## Reconfigure from scratch

Remove the build directory and configure it again:

```console
rm -rf build/ci
CXX=clang++ cmake --preset ci
```

## Build the documentation

From the repository root:

```console
uv run --project docs properdocs build --strict --config-file docs/properdocs.yml
```
