# How-to

This section collects task-oriented instructions for working with kprof.

## Select a C++ compiler

Pass the compiler to CMake when creating a fresh build directory:

```console
cmake -S . -B build -DCMAKE_CXX_COMPILER=clang++
```

The same approach works for GCC (`g++`) and NVHPC (`nvc++`).

## Reconfigure from scratch

Remove the build directory and configure it again:

```console
rm -rf build
cmake -S . -B build
```

## Build the documentation

From the repository root:

```console
uv run --project docs properdocs build --strict --config-file docs/properdocs.yml
```
