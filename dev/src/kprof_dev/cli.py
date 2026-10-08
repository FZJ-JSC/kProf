# SPDX-FileCopyrightText: 2026 kprof developers
#
# SPDX-License-Identifier: Apache-2.0

from __future__ import annotations

from pathlib import Path
import re

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
