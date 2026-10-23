# SPDX-FileCopyrightText: 2026 kprof developers
#
# SPDX-License-Identifier: Apache-2.0

from __future__ import annotations

import re
from pathlib import Path

import click
import yaml

ROOT = Path(__file__).resolve().parents[3]
CONFIG = ROOT / ".besgen.yml"

LANGUAGES = {
    "c": "C",
    "cpp": "CXX",
    "fortran": "Fortran",
    "cuda": "CUDA",
    "hip": "HIP",
}


def config() -> dict:
    return yaml.safe_load(CONFIG.read_text(encoding="utf-8"))


def save_config(data: dict) -> None:
    CONFIG.write_text(yaml.safe_dump(data, sort_keys=False), encoding="utf-8")


def append_unique(path: Path, text: str) -> None:
    current = path.read_text(encoding="utf-8") if path.exists() else ""
    if text not in current:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(current.rstrip() + "\n\n" + text + "\n", encoding="utf-8")


def add_spack_spec(spec: str) -> None:
    path = ROOT / "dev" / "spack.yaml"
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    specs = data.setdefault("spack", {}).setdefault("specs", [])
    if spec not in specs:
        specs.append(spec)
        path.write_text(yaml.safe_dump(data, sort_keys=False), encoding="utf-8")


def replace_cmake_languages(languages: list[str]) -> None:
    path = ROOT / "CMakeLists.txt"
    text = path.read_text(encoding="utf-8")
    rendered = " ".join(LANGUAGES[x] for x in languages) if languages else "NONE"
    text = re.sub(
        r"(project\([^\\n]*?LANGUAGES)\s+[^)]*",
        rf"\1 {rendered}",
        text,
        count=1,
    )
    path.write_text(text, encoding="utf-8")


@click.group()
def main() -> None:
    """Developer tooling for kprof."""


@main.group()
def language() -> None:
    """Manage implementation languages."""


@language.command("add")
@click.argument("name", type=click.Choice(list(LANGUAGES)))
def language_add(name: str) -> None:
    data = config()
    if data["template"] != "cmake":
        raise click.ClickException("language add is currently supported by the cmake template")
    languages = data.setdefault("languages", [])
    if name not in languages:
        languages.append(name)
        save_config(data)
        (ROOT / "src" / name).mkdir(parents=True, exist_ok=True)
        replace_cmake_languages(languages)


@main.group()
def project() -> None:
    """Manage shipped constituent projects."""


@project.command("add")
@click.argument("name")
def project_add(name: str) -> None:
    add_constituent("projects", name)


@main.group()
def showcase() -> None:
    """Manage shipped showcases."""


@showcase.command("add")
@click.argument("name")
def showcase_add(name: str) -> None:
    add_constituent("showcases", name)


def add_constituent(kind: str, name: str) -> None:
    data = config()
    base = ROOT / kind / name
    if data["template"] == "cmake":
        for lang in data.get("languages", []):
            (base / "src" / lang).mkdir(parents=True, exist_ok=True)
        (base / "tests/unit").mkdir(parents=True, exist_ok=True)
    elif data["template"] == "python":
        (base / "src").mkdir(parents=True, exist_ok=True)
        (base / "tests/unit").mkdir(parents=True, exist_ok=True)
    else:
        (base / "src").mkdir(parents=True, exist_ok=True)
        (base / "tests").mkdir(parents=True, exist_ok=True)


@main.group()
def feature() -> None:
    """Manage project features."""


@feature.command("add")
@click.argument("name")
def feature_add(name: str) -> None:
    data = config()
    if data["template"] != "cmake":
        raise click.ClickException(
            "feature editing for this template is not implemented yet"
        )
    append_unique(ROOT / "cmake/features.cmake", f'besa_add_feature("{name}")')


@main.group()
def dependency() -> None:
    """Manage external dependencies."""


@dependency.command("add")
@click.option("--cmake")
@click.option("--python", "python_name")
@click.option("--cargo")
@click.option("--spack", required=True, help="Spack spec; preserved verbatim.")
@click.option("--version", help="Build-system dependency version constraint.")
@click.option("--condition", help="Project feature condition.")
def dependency_add(
    cmake: str | None,
    python_name: str | None,
    cargo: str | None,
    spack: str,
    version: str | None,
    condition: str | None,
) -> None:
    data = config()
    choices = [("cmake", cmake), ("python", python_name), ("cargo", cargo)]
    choices = [(kind, value) for kind, value in choices if value]
    if len(choices) != 1:
        raise click.UsageError("exactly one of --cmake, --python, or --cargo is required")

    backend, name = choices[0]
    expected = {"cmake": "cmake", "python": "python", "cargo": "cargo"}[data["template"]]
    if backend != expected:
        raise click.UsageError(f"{data['template']} projects require --{expected}")

    add_spack_spec(spack)

    if backend == "cmake":
        args = [f"NAME {name}"]
        if version:
            args.append(f'VERSION "{version}"')
        if condition:
            args.append(f'CONDITION "{condition}"')
        append_unique(
            ROOT / "cmake/external.cmake",
            "besa_dependency_add(\n  " + "\n  ".join(args) + "\n)",
        )
    else:
        raise click.ClickException(
            "dependency TOML editing for this template is not implemented yet"
        )


@main.group()
@click.option("--backend", type=click.Choice(["docker", "native"]), default="docker", show_default=True)
@click.option("--volume", help="Persistent Rocky Spack Docker volume.")
@click.option("--image", help="Override the Rocky Linux image.")
@click.option("--cache-image", help="Override the shared GHCR buildcache image.")
@click.pass_context
def deps(ctx: click.Context, backend: str, volume: str | None, image: str | None, cache_image: str | None) -> None:
    """Install, build, publish, or restore development dependencies."""
    ctx.ensure_object(dict)
    ctx.obj.update(backend=backend, volume=volume, image=image, cache_image=cache_image)


def _deps_action(ctx: click.Context, action: str, selector: str) -> None:
    import subprocess

    from . import toolchains

    try:
        toolchains.execute(f"deps-{action}", compilers=(selector,), **ctx.obj)
    except (RuntimeError, ValueError, OSError, subprocess.CalledProcessError) as error:
        raise click.ClickException(str(error)) from error


@deps.command("build")
@click.option("--compiler", "selector", required=True, help="Exact compiler selector (GCC:14, GCC:15, Clang:22, NVHPC:26.9, ...).")
@click.pass_context
def deps_build(ctx: click.Context, selector: str) -> None:
    """Concretize and build the development DAG on the desktop."""
    _deps_action(ctx, "build", selector)


@deps.command("install")
@click.option("--compiler", "selector", required=True, help="Exact compiler selector (GCC:14, GCC:15, Clang:22, NVHPC:26.9, ...).")
@click.pass_context
def deps_install(ctx: click.Context, selector: str) -> None:
    """Use cached binaries, building missing development dependencies."""
    _deps_action(ctx, "install", selector)


@deps.command("push")
@click.option("--compiler", "selector", required=True, help="Exact compiler selector (GCC:14, GCC:15, Clang:22, NVHPC:26.9, ...).")
@click.pass_context
def deps_push(ctx: click.Context, selector: str) -> None:
    """Publish development dependencies to the shared OCI buildcache."""
    _deps_action(ctx, "push", selector)


@deps.command("restore")
@click.option("--compiler", "selector", required=True, help="Exact compiler selector (GCC:14, GCC:15, Clang:22, NVHPC:26.9, ...).")
@click.pass_context
def deps_restore(ctx: click.Context, selector: str) -> None:
    """Restore locked development dependencies from binaries only."""
    _deps_action(ctx, "restore", selector)


@main.group()
@click.option("--backend", type=click.Choice(["docker", "native"]), default="docker", show_default=True)
@click.option("--volume", help="Persistent Docker volume (defaults to dev/etc/toolchains.toml).")
@click.option("--image", help="Override the Rocky container image.")
@click.option("--cache-image", help="Override the GHCR compiler buildcache image.")
@click.pass_context
def compiler(ctx: click.Context, backend: str, volume: str | None, image: str | None, cache_image: str | None) -> None:
    """Provision x86-64-v3 compilers with Spack (build, restore, publish)."""
    ctx.ensure_object(dict)
    ctx.obj.update(backend=backend, volume=volume, image=image, cache_image=cache_image)


def _compiler_action(ctx: click.Context, action: str, selectors: tuple[str, ...] = ()) -> None:
    import subprocess

    from . import toolchains

    try:
        toolchains.execute(action, compilers=selectors, **ctx.obj)
    except (RuntimeError, ValueError, OSError, subprocess.CalledProcessError) as error:
        raise click.ClickException(str(error)) from error


@compiler.command("bootstrap")
@click.pass_context
def compiler_bootstrap(ctx: click.Context) -> None:
    """Prepare a Rocky Linux 10 container with pinned Spack repositories."""
    _compiler_action(ctx, "bootstrap")


@compiler.command("system-install")
@click.argument("selector", metavar="GCC:14|GCC:15|Clang:21|NVHPC:26.5|NVHPC:26.9")
@click.pass_context
def compiler_system_install(ctx: click.Context, selector: str) -> None:
    """Install an OS/RPM compiler inside a Rocky container (CI)."""
    _compiler_action(ctx, "system-install", (selector,))


@compiler.command("build")
@click.option("--compiler", "selectors", multiple=True, help="Build just these compiler roots (otherwise all).")
@click.pass_context
def compiler_build(ctx: click.Context, selectors: tuple[str, ...]) -> None:
    """Build compiler toolchains from source, updating the lockfile."""
    _compiler_action(ctx, "build", selectors)


@compiler.command("restore")
@click.option("--compiler", "selectors", multiple=True, help="Restore only selected compiler roots.")
@click.pass_context
def compiler_restore(ctx: click.Context, selectors: tuple[str, ...]) -> None:
    """Cache-only restore; never compile any package."""
    _compiler_action(ctx, "restore", selectors)


@compiler.command("install")
@click.argument("selector", metavar="GCC:15|GCC:16|Clang:22")
@click.pass_context
def compiler_install(ctx: click.Context, selector: str) -> None:
    """Restore one cached compiler and print/export its C++ executable."""
    _compiler_action(ctx, "install", (selector,))


@compiler.command("push")
@click.option("--compiler", "selectors", multiple=True, help="Publish only selected compiler roots.")
@click.pass_context
def compiler_push(ctx: click.Context, selectors: tuple[str, ...]) -> None:
    """Publish installed compilers and dependencies to the OCI buildcache."""
    _compiler_action(ctx, "push", selectors)


@compiler.command("inspect")
@click.pass_context
def compiler_inspect(ctx: click.Context) -> None:
    """Inspect the mirror and installed/remote compiler specifications."""
    _compiler_action(ctx, "inspect")


@compiler.command("sync")
@click.option("--check", is_flag=True, help="Fail when spack.yaml differs from dev/etc configuration.")
def compiler_sync(check: bool) -> None:
    """Generate the compiler Spack manifest from dev/etc/toolchains.toml."""
    from .toolchains import sync

    try:
        sync(check=check)
    except (RuntimeError, ValueError) as error:
        raise click.ClickException(str(error)) from error


@compiler.command("get")
@click.argument("key", metavar="SECTION.KEY")
def compiler_get(key: str) -> None:
    """Print one configuration value (useful in scripts and CI)."""
    from .toolchains import get

    try:
        click.echo(get(key))
    except (ValueError, KeyError) as error:
        raise click.ClickException(str(error)) from error


@compiler.command("set-packages-version")
@click.argument("ref", metavar="vYYYY.MM.PATCH")
def compiler_set_packages_version(ref: str) -> None:
    """Set the pinned spack-packages release for CI and desktop."""
    from .toolchains import set_packages_version

    try:
        set_packages_version(ref)
    except (ValueError, RuntimeError) as error:
        raise click.ClickException(str(error)) from error
