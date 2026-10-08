# Reference

The generated C++ API documentation is available directly from the reference section:

<a href="api/">Open reference/api</a>

## Build and test commands

| Task | Command |
| --- | --- |
| Configure | `cmake -S . -B build` |
| Build | `cmake --build build --parallel` |
| Test | `ctest --test-dir build --output-on-failure` |
| Build docs | `uv run --project docs properdocs build --strict --config-file docs/properdocs.yml` |
