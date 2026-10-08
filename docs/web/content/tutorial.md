# Tutorial

This tutorial takes you through a first local build and test of kprof.

## Configure

From the repository root, create a build directory with CMake:

```console
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
```

## Build

```console
cmake --build build --parallel
```

## Run the tests

```console
ctest --test-dir build --output-on-failure
```

You now have a configured, built, and tested local checkout. Continue with the how-to guides for individual development tasks or the reference for API details.
