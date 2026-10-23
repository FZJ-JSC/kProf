<!-- SPDX-FileCopyrightText: 2026 kprof developers -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

# Reusable Rocky Linux compilers

`kprof-dev compiler` is the developer interface for compiler provisioning. It
builds Spack-managed compilers in **Rocky Linux 10**, with the target fixed to
**`x86_64_v3`**. Compilers are built once on a desktop, pushed as individual
Spack buildcache artifacts to GHCR, and restored in CI. No conda or external
GCC/LLVM compiler repositories are used.

## Configuration

Edit [`dev/etc/toolchains.toml`](../etc/toolchains.toml) to change:

- Rocky container image and persistent desktop Docker volume
- Spack version (`v1.2.2`) and `spack-packages` version (`v2026.10.0`)
- GHCR OCI buildcache image and its Spack mirror name
- Compiler root specs, selector names, and installed C++ executable paths

The version pin and bootstrap RPM list are used by **both** the local container
and `kprof-dev compiler --backend native bootstrap` in GitHub Actions.
The Spack environment is generated from this file and checked in along with
its concrete lockfile:

```sh
kprof-dev compiler sync
kprof-dev compiler sync --check
```

The GCC 16 bootstrap-comparison workaround (GCC PR125598) is already included
in `spack-packages` v2026.10.0. We do not maintain a separate GCC recipe patch.

## Desktop: build and publish once

Run from the repository on an x86-64-v3-capable Linux machine with Docker.
Install the Python development CLI using your preferred Python environment
(e.g., `uv run --project dev kprof-dev ...`). Provisioning is performed by
`kprof-dev compiler` rather than `.github/scripts` shell wrappers.

```sh
# Source compilation is explicit and never invoked by CI.
kprof-dev compiler build

# Commit dev/compilers/spack.yaml and dev/compilers/spack.lock after building.
export GHCR_USER='<github-username>'
export GHCR_TOKEN='<token-with-write-packages>'
kprof-dev compiler push
```

The build runs in an ephemeral Rocky 10 container. The named Docker volume
persists `/opt/spack`, the installed compiler store. With a prebuilt image,
pinned Spack sources live separately in `/opt/kprof`, so the image cannot
be shadowed by an older Docker volume. Bare-Rocky fallback containers still
retain their Spack checkouts in the persistent volume. The container returns ownership of the bind-mounted
`dev/compilers` files to the invoking desktop user's UID/GID on exit, including
failed builds, so `spack.lock` and `.spack-env` remain manageable without a
manual `sudo chown` or `chmod`. The persistent volume remains managed by root
inside Docker. This volume **is not uploaded**. Only Spack binaries and dependencies
are published to the GHCR OCI buildcache. Builds and installation use a fixed
prefix so relocation and reproducible hashes can work across machines.

## Desktop: restore a fresh volume

```sh
export GHCR_USER='<github-username>'  # only needed for authenticated pulls
export GHCR_TOKEN='<token-with-read-packages>'
kprof-dev compiler --volume kprof-spack-recovered restore
kprof-dev compiler --volume kprof-spack-recovered inspect
```

`restore` checks that the generated manifest is current and the committed
`spack.lock` exists, then installs **only from binary buildcaches**. It fails
instead of compiling if any binary package is missing. Reusing the same volume
allows subsequent commands to skip already installed packages. The compiler
store is portable between compatible Rocky 10 `x86_64_v3` hosts, not between
arbitrary Linux distributions or Spack DAGs.

For selective operations and overrides:

```sh
kprof-dev compiler build --compiler GCC:16
kprof-dev compiler restore --compiler Clang:22
kprof-dev compiler install GCC:15
kprof-dev compiler --cache-image ghcr.io/me/kprof-spack-compilers-rocky10-v3 push
kprof-dev compiler get spack.packages_version
kprof-dev compiler set-packages-version v2026.10.0
```

Use `kprof-dev compiler --help` for `--backend native`, `--volume`, `--image`,
and `--cache-image` options. `build` updates the lockfile; remember to push the
built roots and commit the resulting lockfile before using CI. A partial
`build --compiler` should be followed by a matching partial `push --compiler`.

The Rocky/Spack bootstrap and system RPM installation are also subcommands:

```sh
kprof-dev compiler bootstrap
kprof-dev compiler --backend native system-install GCC:14
```

`build`, `restore`, `push`, and `inspect` automatically bootstrap Spack inside
the desktop Docker container. CI runs that same bootstrap under `--backend native`
(after only the minimum packages necessary for checkout) instead of invoking
`spack/setup-spack` and its own compiler-configuration script. Both paths install
GCC 14 with C, C++, and Fortran and register it as the Spack dependency compiler.
`system-install` is intended for an existing Rocky container, so it requires
`--backend native`. GitHub Actions uses
`uv run --project dev --no-dev kprof-dev compiler ...` for all compiler-management
commands, including system RPM installation and cache restoration, and runs
`install` for GCC 15, GCC 16, or Clang 22. **No compiler is built in CI.** GCC 14
remains the Rocky bootstrap compiler, and NVHPC uses NVIDIA's RPM SDK.

After changing any compiler spec or the package-repository version, run `sync`,
rebuild and republish on the desktop, and commit the refreshed `spack.lock`.
Avoid using an old lockfile against new recipes or claiming a cache hit based
on CPU target alone; Spack hashes also depend on the full dependency graph.

## Compiler-specific development dependencies (cache on miss)

Each compiler matrix entry concretizes **its own development graph** from
`dev/spack.yaml`, including CMake, Ninja, Lyra, and Catch2. GCC 15/16 and
Clang 22 require their selected compiler for every language provider. NVHPC
has a deliberate exception described below. Compiler options, package
variants, and target remain part of the concrete Spack hash.

The CLI generates a separate, ignored environment and lockfile in
`dev/.spack-matrix/<compiler>/`; the obsolete host-generated `dev/spack.lock`
is deliberately no longer used. The pinned Spack and package repository
versions and the manifest are version-controlled. The concrete lockfile for
an individual compiler is **preserved when its generated manifest is unchanged**
(and regenerated when configuration changes), then checked for Rocky Linux 10,
`x86_64_v3`, and the applicable language providers before installation/upload.

**NVHPC exception:** CMake, Ninja, their compiled host-side dependencies
(e.g. zstd, diffutils, zlib-ng), and the external Rocky Python interpreter
may use system GCC 14. They are executed as separate build tools; they do
not supply libraries linked into kProf. Catch2, which kProf links, is
explicitly required to use NVHPC for C++; the lockfile validator follows
link edges from `kprof-dev` and rejects a GCC-built linked dependency.
This rule is specific to the NVHPC matrix configurations and does not allow
arbitrary GCC/NVHPC ABI mixing. The kProf build itself always uses the
selected NVHPC C/C++ compilers.

For example, after installing the selected compiler:

```sh
uv run --project dev kprof-dev deps install --compiler GCC:15
uv run --project dev kprof-dev deps push --compiler GCC:15
```

On CI, dependency installation uses the Spack binary mirror first, builds
missing packages from source, and publishes the **selected compiler's** DAG
on trusted pushes. Each compiler writes to its own GHCR dependency image,
such as `ghcr.io/fzj-jsc/kprof-spack-compilers-rocky10-v3-deps-gcc-15`,
to avoid races among matrix jobs. Pull requests can build missing dependencies,
but are not authorized to publish to the cache. No compiler is ever built in CI;
compiler restoration remains `--cache-only`.

`kprof-dev deps restore --compiler GCC:15` is still available to test strict
binary-only recovery after creating the matching local environment. The
`kprof-dev deps build --compiler GCC:15` subcommand explicitly bypasses the
cache if a fresh source build is wanted.

The compiler cache itself must be complete: if CI reports
`gcc-runtime@14.3.1/qottf2m no binary available`, rebuild/publish the
compiler environment on desktop and verify it in a fresh Docker volume. The
matrix must not work around this with a compiler source build.

## Prebuilt bootstrap image (optional rollout)

The Dockerfile at `dev/containers/rocky10/Dockerfile` uses the **same**
`toolchains.toml` and stdlib CLI as the runtime bootstrap to bake RPMs,
GCC 14, Spack, and spack-packages into an image. The image does **not**
contain compiler binaries or compiler-specific development dependencies.
Its Spack sources live under `/opt/kprof`, separately from the `/opt/spack`
store volume. A marker instructs subsequent bootstrap steps to verify
those pins rather than repeat the DNF transaction and Git clones.

Publish the image first (the workflow `bootstrap-image.yml` can do this on
`main`, or use the equivalent desktop command):

```sh
docker build -f dev/containers/rocky10/Dockerfile \
  -t ghcr.io/fzj-jsc/kprof-bootstrap-rocky10:rocky10-v1 .
docker push ghcr.io/fzj-jsc/kprof-bootstrap-rocky10:rocky10-v1
```

After the image is available to the repository's CI runner, set repository
variable `KPROF_BOOTSTRAP_IMAGE` to that tag (prefer a pinned digest for
long-lived reproducibility). The CI workflow falls back to bare Rocky
Linux 10 while the image is unpublished. Desktop users can opt in with
`kprof-dev compiler --image ghcr.io/fzj-jsc/kprof-bootstrap-rocky10:rocky10-v1 ...`.

**Compiler cache recovery after starting from scratch:**

```sh
# The first command may rebuild all 3 compiler roots and dependencies.
uv run --project dev kprof-dev compiler build
# Push is refused unless every non-external node in the selected locked DAG,
# including GCC 14's separate gcc-runtime package, is installed.
uv run --project dev kprof-dev compiler push
# Prove that the GHCR cache is complete without locally built artifacts.
uv run --project dev kprof-dev compiler --volume kprof-compiler-verify-new restore
```

Use the **same desktop volume** for `build` and `push`, and a **new** volume for
`restore`. Commit `dev/compilers/spack.lock` if concretization changed it.
Never replace the compiler `--cache-only` policy with source builds in CI.
