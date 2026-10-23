# SPDX-FileCopyrightText: 2026 kprof developers
# SPDX-License-Identifier: Apache-2.0
"""No Docker/Spack dependency: test the management command's contract."""

import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from kprof_dev import toolchains


class ToolchainTests(unittest.TestCase):
    def test_manifest_is_synced(self):
        toolchains.sync(check=True)

    def test_compiler_manifest_disables_views(self):
        manifest = toolchains.manifest_content(toolchains.settings())
        self.assertIn("  view: false\n", manifest)

    def test_refs_are_centralized(self):
        self.assertEqual(toolchains.get("spack.packages_version"), "v2026.10.0")
        self.assertEqual(toolchains.get("platform.target"), "x86_64_v3")
        self.assertEqual(toolchains.compiler_for(toolchains.settings(), "gcc:16")["cxx"], "bin/g++")

    def test_restore_is_cache_only(self):
        calls = []
        with (
            patch.object(toolchains, "verify_platform"),
            patch.object(toolchains, "configure_spack"),
            patch.object(toolchains, "sync"),
            patch.object(toolchains, "ensure_lock"),
            patch.object(toolchains, "run_command", side_effect=lambda *a: calls.append(a)),
        ):
            toolchains.native("restore", compilers=("GCC:16",))
        self.assertTrue(any("--cache-only" in cmd for cmd in calls))
        self.assertTrue(any("--only-concrete" in cmd for cmd in calls))
        self.assertFalse(any("--no-cache" in cmd or "concretize" in cmd for cmd in calls))
        self.assertTrue(any("gcc@16.1.0 target=x86_64_v3" in cmd for cmd in calls))

    def test_matrix_environment_is_ignored_not_host_lock(self):
        ignore = (toolchains.ROOT / ".gitignore").read_text()
        self.assertIn("dev/.spack-matrix/", ignore)
        self.assertFalse((toolchains.ROOT / "dev/spack.lock").exists())

    def test_development_manifest_pins_portable_target(self):
        content = (toolchains.ROOT / "dev/spack.yaml").read_text()
        self.assertIn("target: [x86_64_v3]", content)

    def test_compiler_selectors_are_required_for_deps(self):
        with self.assertRaisesRegex(ValueError, "exactly one"):
            toolchains.execute("deps-install", backend="native")
        with self.assertRaisesRegex(ValueError, "exactly one"):
            toolchains.execute("deps-install", compilers=("GCC:14", "GCC:15"), backend="native")

    def test_development_install_prefers_cache_but_can_build(self):
        commands = []
        with (
            patch.object(toolchains, "verify_platform"),
            patch.object(toolchains, "configure_spack"),
            patch.object(toolchains, "dependency_compiler", return_value=("gcc@=15.3.0", Path("/usr/bin/g++"))),
            patch.object(toolchains, "prepare_deps_environment", return_value=Path("/tmp/gcc-15")),
            patch.object(toolchains, "validate_deps_lock"),
            patch.object(Path, "is_file", return_value=True),
            patch.object(toolchains.os, "access", return_value=True),
            patch.object(toolchains, "run_command", side_effect=lambda *a: commands.append(a)),
        ):
            toolchains.native_deps("install", selector="GCC:15")
        self.assertTrue(any("concretize" in cmd for cmd in commands))
        self.assertTrue(any("install" in cmd and "--only-concrete" in cmd for cmd in commands))
        self.assertFalse(any("--cache-only" in cmd or "--no-cache" in cmd for cmd in commands))

    def test_development_build_and_push_are_explicit(self):
        commands = []
        with (
            patch.object(toolchains, "verify_platform"),
            patch.object(toolchains, "configure_spack"),
            patch.object(toolchains, "dependency_compiler", return_value=("gcc@=15.3.0", Path("/usr/bin/g++"))),
            patch.object(toolchains, "prepare_deps_environment", return_value=Path("/tmp/gcc-15")),
            patch.object(toolchains, "validate_deps_lock"),
            patch.object(Path, "is_file", return_value=True),
            patch.object(toolchains.os, "access", return_value=True),
            patch.object(toolchains, "run_command", side_effect=lambda *a: commands.append(a)),
            patch.dict(toolchains.os.environ, {"GHCR_USER": "user", "GHCR_TOKEN": "token"}),
        ):
            toolchains.native_deps("build", selector="GCC:15")
            self.assertTrue(any("--no-cache" in cmd for cmd in commands))
            commands.clear()
            toolchains.native_deps("push", selector="GCC:15")
            pushes = [cmd for cmd in commands if "buildcache" in cmd and "push" in cmd]
            self.assertEqual(len(pushes), 1)
            self.assertIn("--allow-missing", pushes[0])
            self.assertIn("--update-index", pushes[0])
            self.assertNotIn("--without-build-dependencies", pushes[0])

    def test_per_compiler_lockfile_handles_string_or_dict_target(self):
        import json
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            lock = {
                "spack": {"version": "1.2.2"}, "roots": [{"hash": "root"}],
                "concrete_specs": {
                    "root": {"name": "kprof-dev", "version": "1.1", "arch": {
                        "platform_os": "rocky10", "target": "x86_64_v3",
                    }, "dependencies": [{"name": "gcc", "hash": "compiler", "parameters": {
                        "virtuals": ["c", "cxx"]}}]},
                    "compiler": {"name": "gcc", "version": "15.3.0", "arch": {
                        "platform_os": "rocky10", "target": {"name": "x86_64_v3"},
                    }},
                },
            }
            (directory / "spack.lock").write_text(json.dumps(lock))
            toolchains.validate_deps_lock(directory, "gcc@=15.3.0", toolchains.settings())
            lock["concrete_specs"]["compiler"]["version"] = "14.3.1"
            (directory / "spack.lock").write_text(json.dumps(lock))
            with self.assertRaisesRegex(RuntimeError, "Mixed compiler"):
                toolchains.validate_deps_lock(directory, "gcc@=15.3.0", toolchains.settings())
            lock["concrete_specs"]["compiler"]["version"] = "15.3.0"
            lock["concrete_specs"]["root"]["arch"]["platform_os"] = "arch"
            (directory / "spack.lock").write_text(json.dumps(lock))
            with self.assertRaisesRegex(RuntimeError, "Wrong OS"):
                toolchains.validate_deps_lock(directory, "gcc@=15.3.0", toolchains.settings())

    def test_nvhpc_host_tools_use_system_gcc_but_catch2_uses_nvhpc(self):
        commands = []
        completed = type("Completed", (), {"stdout": "3.12.15\n"})()
        with tempfile.TemporaryDirectory() as temporary:
            with (
                patch.object(toolchains, "DEPS_MATRIX_DIR", Path(temporary)),
                patch.object(toolchains, "dependency_compiler",
                             return_value=("gcc@=14.3.1", Path("/usr/bin/g++"))),
                patch.object(toolchains.subprocess, "run", return_value=completed),
                patch.object(toolchains, "run_command", side_effect=lambda *args: commands.append(args)),
            ):
                env = toolchains.prepare_deps_environment("NVHPC:26.9", "nvhpc@=26.9")
                self.assertTrue((env / "spack.yaml").is_file())
                self.assertTrue((env / "share/spack").is_symlink())
                self.assertEqual(env.name, "nvhpc-26-9")
            import yaml
            packages = yaml.safe_load((env / "spack.yaml").read_text())["spack"]["packages"]
            for language in ("c", "cxx", "fortran"):
                self.assertEqual(packages[language]["prefer"], ["gcc@=14.3.1"])
                self.assertNotIn("require", packages[language])
            self.assertEqual(packages["catch2"]["require"], ["%cxx=nvhpc@=26.9"])
            self.assertEqual(commands, [])  # deterministic manifest; no Spack mutations

    def test_nvhpc_uses_external_system_python_only(self):
        import yaml
        completed = type("Completed", (), {"stdout": "3.12.15\n"})()
        with tempfile.TemporaryDirectory() as temporary:
            with (
                patch.object(toolchains, "DEPS_MATRIX_DIR", Path(temporary)),
                patch.object(toolchains, "dependency_compiler",
                             return_value=("gcc@=14.3.1", Path("/usr/bin/g++"))),
                patch.object(toolchains.subprocess, "run", return_value=completed),
            ):
                env = toolchains.prepare_deps_environment("NVHPC:26.9", "nvhpc@=26.9")
                packages = yaml.safe_load((env / "spack.yaml").read_text())["spack"]["packages"]
                self.assertEqual(packages["python"]["externals"], [
                    {"spec": "python@=3.12.15", "prefix": "/usr"},
                ])
                self.assertFalse(packages["python"]["buildable"])
                gcc_env = toolchains.prepare_deps_environment("GCC:15", "gcc@=15.3.0")
                packages = yaml.safe_load((gcc_env / "spack.yaml").read_text())["spack"]["packages"]
                self.assertNotIn("python", packages)

    def test_nvhpc_lock_rejects_compiler_mixing_across_abi_boundary(self):
        import json
        arch = {"platform_os": "rocky10", "target": "x86_64_v3"}
        # A compiled Catch2 library is linked into kProf; CMake, Ninja and
        # zstd are build/run tools and execute as separate host processes.
        def edge(name, hash_, types, virtuals=()):
            return {"name": name, "hash": hash_, "parameters": {
                "deptypes": list(types), "virtuals": list(virtuals),
            }}
        lock = {
            "spack": {"version": "1.2.2"}, "roots": [{"hash": "root"}],
            "concrete_specs": {
                "root": {"name": "kprof-dev", "version": "1.1", "arch": arch,
                         "dependencies": [edge("catch2", "catch", ("link", "run")),
                                          edge("cmake", "cmake", ("build", "run"))]},
                "catch": {"name": "catch2", "version": "3.8.0", "arch": arch,
                          "dependencies": [edge("nvhpc", "nvhpc", ("build",), ("cxx",))]},
                "cmake": {"name": "cmake", "version": "4.3.0", "arch": arch,
                          "dependencies": [edge("gcc", "gcc", ("build",), ("cxx",)),
                                           edge("zstd", "zstd", ("link", "run"))]},
                "zstd": {"name": "zstd", "version": "1.5.7", "arch": arch,
                         "dependencies": [edge("gcc", "gcc", ("build",), ("c",))]},
                "gcc": {"name": "gcc", "version": "14.3.1", "arch": arch,
                        "external": True},
                "nvhpc": {"name": "nvhpc", "version": "26.5", "arch": arch,
                          "external": True},
            },
        }
        with tempfile.TemporaryDirectory() as temporary:
            env = Path(temporary)
            with patch.object(toolchains, "dependency_compiler",
                              return_value=("gcc@=14.3.1", Path("/usr/bin/g++"))):
                def check():
                    (env / "spack.lock").write_text(json.dumps(lock))
                    toolchains.validate_deps_lock(env, "nvhpc@=26.5", toolchains.settings())

                check()
                lock["concrete_specs"]["catch"]["dependencies"][0]["hash"] = "gcc"
                with self.assertRaisesRegex(RuntimeError, "expected nvhpc"):
                    check()
                lock["concrete_specs"]["catch"]["dependencies"][0]["hash"] = "nvhpc"
                lock["concrete_specs"]["zstd"]["dependencies"][0]["hash"] = "nvhpc"
                with self.assertRaisesRegex(RuntimeError, "expected gcc"):
                    check()

    def test_per_compiler_lock_is_reused_until_manifest_changes(self):
        import yaml
        with tempfile.TemporaryDirectory() as temporary:
            with patch.object(toolchains, "DEPS_MATRIX_DIR", Path(temporary)):
                env = toolchains.prepare_deps_environment("GCC:15", "gcc@=15.3.0")
                lock = env / "spack.lock"
                lock.write_text('{"test": true}')
                first = (env / "spack.yaml").read_text()
                self.assertEqual(yaml.safe_load(first)["spack"]["packages"]["c"]["require"],
                                 ["gcc@=15.3.0"])
                toolchains.prepare_deps_environment("GCC:15", "gcc@=15.3.0")
                self.assertEqual(lock.read_text(), '{"test": true}')
                toolchains.prepare_deps_environment("GCC:15", "gcc@=16.1.0")
                self.assertFalse(lock.exists())

    def test_compiler_runtime_is_part_of_required_cache_closure(self):
        import json
        lock = json.loads(toolchains.LOCKFILE.read_text())
        selected = toolchains.compiler_closure(
            lock, (toolchains.compiler_for(toolchains.settings(), "GCC:15")["spec"],)
        )
        self.assertTrue(any(node["name"] == "gcc-runtime" and key.startswith("qottf2m")
                            for key, node in selected.items()))
        self.assertFalse(any(node["name"] == "glibc" for node in selected.values()))
        self.assertFalse(any(node["name"] == "gcc" and node["version"] == "16.1.0"
                             for node in selected.values()))

    def test_compiler_push_rejects_missing_transitive_binary_before_upload(self):
        import json
        data = toolchains.settings()
        roots = (toolchains.compiler_for(data, "GCC:15")["spec"],)
        graph = toolchains.validate_compiler_lock(data, roots)
        runtime = next(hash_ for hash_, node in graph.items() if node["name"] == "gcc-runtime")
        existing = "\n".join(k for k in graph if k != runtime)
        completed = type("Completed", (), {"stdout": existing})()
        with patch.object(toolchains.subprocess, "run", return_value=completed):
            with self.assertRaisesRegex(RuntimeError, "gcc-runtime@14.3.1/qottf2m"):
                toolchains.require_installed_compiler_graph(data, roots)

    def test_compiler_push_requires_complete_locked_graph(self):
        commands = []
        with (
            patch.object(toolchains, "verify_platform"),
            patch.object(toolchains, "configure_spack"),
            patch.object(toolchains, "sync"),
            patch.object(toolchains, "require_installed_compiler_graph") as complete,
            patch.object(toolchains, "run_command", side_effect=lambda *a: commands.append(a)),
            patch.dict(toolchains.os.environ, {"GHCR_USER": "user", "GHCR_TOKEN": "token"}),
        ):
            toolchains.native("push", compilers=("GCC:15",))
        complete.assert_called_once()
        self.assertIn("--with-build-dependencies", commands[-1])
        self.assertIn("--update-index", commands[-1])

    def test_ci_installs_and_publishes_each_dependency_graph(self):
        workflow = (toolchains.ROOT / ".github/workflows/test.yml").read_text()
        self.assertIn("kprof-dev deps --backend native install --compiler", workflow)
        self.assertIn("kprof-dev deps --backend native push --compiler", workflow)
        self.assertIn("needs: scripts", workflow)
        self.assertNotIn("needs: [scripts, dependencies]", workflow)
        self.assertNotIn("  dependencies:\n", workflow)
        self.assertIn("packages: write", workflow)
        self.assertIn("github.event_name != 'pull_request'", workflow)
        self.assertNotIn("spack-deps.sh install", workflow)

    def test_deps_cli_actions_exposed(self):
        from click.testing import CliRunner
        from kprof_dev.cli import main
        result = CliRunner().invoke(main, ["deps", "--help"])
        self.assertEqual(result.exit_code, 0, result.output)
        for action in ("build", "install", "push", "restore"):
            self.assertIn(action, result.output)
        result = CliRunner().invoke(main, ["deps", "install", "--help"])
        self.assertIn("--compiler", result.output)
        result = CliRunner().invoke(main, ["deps", "install"])
        self.assertNotEqual(result.exit_code, 0)

    def test_internal_desktop_entrypoint_accepts_dependency_selector(self):
        """Docker invokes the stdlib entrypoint, not the Click command."""
        with patch.object(toolchains, "execute") as execute:
            status = toolchains.main([
                "--backend", "native", "deps-install", "--compiler", "GCC:15",
            ])
        self.assertEqual(status, 0)
        execute.assert_called_once_with(
            "deps-install", backend="native", compilers=("GCC:15",),
            volume=None, image=None, cache_image=None,
        )

    def test_docker_volume_override_and_no_compiler_build(self):
        calls = []
        with patch.object(toolchains, "run_command", side_effect=lambda *a: calls.append(a)):
            toolchains.execute("restore", volume="another-volume")
        self.assertEqual(len(calls), 1)
        cmd = calls[0]
        self.assertIn("type=volume,source=another-volume,target=/opt/spack", cmd)
        self.assertIn("SPACK_DISABLE_LOCAL_CONFIG=1", cmd)
        self.assertIn("restore", cmd)
        self.assertIn(f"KPROF_HOST_UID={toolchains.os.getuid()}", cmd)
        self.assertIn(f"KPROF_HOST_GID={toolchains.os.getgid()}", cmd)
        self.assertNotIn("build", cmd)

    def test_updating_package_repo_pin(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "toolchains.toml"
            path.write_text(toolchains.SETTINGS_FILE.read_text(encoding="utf-8"), encoding="utf-8")
            with patch.object(toolchains, "SETTINGS_FILE", path):
                toolchains.set_packages_version("v2026.11.0")
                self.assertEqual(toolchains.get("spack.packages_version"), "v2026.11.0")
                with self.assertRaises(ValueError):
                    toolchains.set_packages_version("master")

    def test_system_compiler_configuration(self):
        data = toolchains.settings()
        self.assertEqual(toolchains.system_compiler_for(data, "GCC:14")["cxx"], "/usr/bin/g++")
        self.assertEqual(
            toolchains.system_compiler_for(data, "NVHPC:26.9")["packages"], ["nvhpc-26-9"]
        )
        with self.assertRaisesRegex(ValueError, "Unknown system compiler"):
            toolchains.system_compiler_for(data, "GCC:16")

    def test_bootstrap_uses_pins_and_registers_repo(self):
        commands = []
        with tempfile.TemporaryDirectory() as directory:
            path_file = Path(directory) / "GITHUB_PATH"
            env_file = Path(directory) / "GITHUB_ENV"

            def fake_process(args, **kwargs):
                stdout = "14.3.1\n" if args[0] == "/usr/bin/gcc" else ""
                return type("Result", (), {"stdout": stdout})()

            with (
                patch.object(toolchains, "run_command", side_effect=lambda *cmd: commands.append(cmd)),
                patch.object(toolchains, "_checkout_tag") as checkout,
                patch.object(toolchains.subprocess, "run", side_effect=fake_process),
                patch.dict(toolchains.os.environ, {
                    "PATH": "/usr/bin", "GITHUB_PATH": str(path_file),
                    "GITHUB_ENV": str(env_file),
                }),
            ):
                toolchains.bootstrap_spack(toolchains.settings())
            self.assertEqual(path_file.read_text(), "/opt/spack/spack-src/bin\n")
            self.assertEqual(env_file.read_text(), "SPACK_ROOT=/opt/spack/spack-src\n")
        self.assertEqual(checkout.call_count, 2)
        self.assertEqual(checkout.call_args_list[0].args[-1], "v1.2.2")
        self.assertEqual(checkout.call_args_list[1].args[-1], "v2026.10.0")
        self.assertEqual(commands[0][:3], ("dnf", "install", "-y"))
        self.assertIn("gcc-gfortran", commands[0])
        self.assertTrue(any(cmd[:3] == ("spack", "repo", "add") for cmd in commands))
        self.assertTrue(any(cmd[:3] == ("spack", "compiler", "find") for cmd in commands))
        for language in ("c", "cxx", "fortran"):
            self.assertTrue(any(f"packages:{language}:prefer::[gcc@14.3.1]" in cmd for cmd in commands))

    def test_ci_uses_the_shared_bootstrap_without_spack_setup_action(self):
        workflow = (toolchains.ROOT / ".github/workflows/test.yml").read_text()
        self.assertIn("kprof-dev compiler --backend native bootstrap", workflow)
        self.assertNotIn("spack/setup-spack@", workflow)
        self.assertNotIn("configure-spack.sh", workflow)
        self.assertNotIn("shell: spack-bash", workflow)

    def test_nvhpc_installer_sets_compiler_for_ci(self):
        commands = []
        with tempfile.TemporaryDirectory() as directory:
            env_file = Path(directory) / "GITHUB_ENV"
            with (
                patch.object(toolchains, "run_command", side_effect=lambda *cmd: commands.append(cmd)),
                patch.object(Path, "is_file", return_value=True),
                patch.object(toolchains.os, "access", return_value=True),
                patch.dict(toolchains.os.environ, {"GITHUB_ENV": str(env_file)}),
            ):
                toolchains.install_system_compiler(toolchains.settings(), "NVHPC:26.5")
            self.assertIn(("dnf", "install", "-y", "nvhpc-26-5"), commands)
            self.assertTrue(any(cmd[:2] == ("curl", "-fsSL") for cmd in commands))
            self.assertIn("KPROF_CXX=/opt/nvidia/hpc_sdk/Linux_x86_64/26.5/compilers/bin/nvc++", env_file.read_text())

    def test_container_executes_internal_python_not_shell_wrappers(self):
        commands = []
        with patch.object(toolchains, "run_command", side_effect=lambda *cmd: commands.append(cmd)):
            toolchains.execute("bootstrap", volume="my-toolchain-volume")
        self.assertEqual(len(commands), 1)
        cmd = commands[0]
        self.assertIn("dev/src/kprof_dev/toolchains.py", cmd)
        self.assertIn("KPROF_DESKTOP_BOOTSTRAP=1", cmd)
        self.assertNotIn(".github/scripts/bootstrap-rocky-spack.sh", cmd)
        self.assertEqual(cmd[-1], "bootstrap")

    def test_image_bootstrap_uses_immutable_source_path(self):
        commands = []
        with tempfile.TemporaryDirectory() as directory:
            path_file = Path(directory) / "GITHUB_PATH"

            def fake_process(args, **kwargs):
                stdout = "14.3.1\n" if args[0] == "/usr/bin/gcc" else ""
                return type("Result", (), {"stdout": stdout})()

            with (
                patch.object(toolchains, "run_command", side_effect=lambda *a: commands.append(a)),
                patch.object(toolchains, "_checkout_tag") as checkout,
                patch.object(toolchains.subprocess, "run", side_effect=fake_process),
                patch.dict(toolchains.os.environ, {
                    "PATH": "/usr/bin", "GITHUB_PATH": str(path_file),
                    "KPROF_BUILD_BOOTSTRAP_IMAGE": "1",
                }),
            ):
                toolchains.bootstrap_spack(toolchains.settings())
            self.assertEqual(checkout.call_args_list[0].args[0], Path("/opt/kprof/spack-src"))
            self.assertEqual(checkout.call_args_list[1].args[0], Path("/opt/kprof/spack-packages"))
            self.assertEqual(path_file.read_text(), "/opt/kprof/spack-src/bin\n")
            self.assertEqual(commands[0][:3], ("dnf", "install", "-y"))

    def test_ci_can_opt_in_to_prebuilt_image_without_breaking_bare_rocky(self):
        workflow = (toolchains.ROOT / ".github/workflows/test.yml").read_text()
        self.assertIn("vars.KPROF_BOOTSTRAP_IMAGE || 'rockylinux/rockylinux:10'", workflow)
        self.assertIn("--group dev pytest -q dev/tests", workflow)
        self.assertNotIn("python -m unittest discover", workflow)
        image = toolchains.ROOT / "dev/containers/rocky10/Dockerfile"
        content = image.read_text()
        self.assertIn("KPROF_BUILD_BOOTSTRAP_IMAGE=1", content)
        reuse = (toolchains.ROOT / ".github/workflows/reuse.yml").read_text()
        self.assertNotIn("python3 coreutils", reuse)

    def test_build_compiler_graph_from_source_and_check_closure(self):
        commands = []
        with (
            patch.object(toolchains, "verify_platform"),
            patch.object(toolchains, "configure_spack"),
            patch.object(toolchains, "sync"),
            patch.object(toolchains, "validate_compiler_lock"),
            patch.object(toolchains, "require_installed_compiler_graph") as complete,
            patch.object(toolchains, "run_command", side_effect=lambda *a: commands.append(a)),
        ):
            toolchains.native("build", compilers=("GCC:16",))
        self.assertTrue(any("concretize" in command for command in commands))
        self.assertTrue(any("install" in command and "--no-cache" in command
                            and "--only-concrete" in command for command in commands))
        complete.assert_called_once()

    def test_system_install_requires_native_backend(self):
        with self.assertRaisesRegex(ValueError, "must run with --backend native"):
            toolchains.execute("system-install", compilers=("GCC:14",))

    def test_workspace_ownership_cleanup_on_success_and_failure(self):
        commands = []
        with (
            patch.object(toolchains, "run_command", side_effect=lambda *cmd: commands.append(cmd)),
            patch.object(Path, "is_dir", return_value=True),
            patch.object(Path, "exists", return_value=True),
            patch.dict(toolchains.os.environ, {"KPROF_HOST_UID": "123", "KPROF_HOST_GID": "456"}),
        ):
            toolchains.restore_workspace_ownership()
        self.assertEqual(commands[0][:3], ("chown", "-hR", "123:456"))
        self.assertEqual(commands[1][:3], ("chmod", "-R", "u+rwX"))
        self.assertTrue(any("/workspace/dev/.spack-matrix" in cmd for cmd in commands))
        self.assertTrue(any("/workspace/dev/.spack-env" in cmd for cmd in commands))

    def test_internal_entrypoint_cleans_up_when_spack_fails(self):
        with (
            patch.object(toolchains, "execute", side_effect=RuntimeError("failed")),
            patch.object(toolchains, "restore_workspace_ownership") as restore,
        ):
            status = toolchains.main(["--backend", "native", "build"])
        self.assertEqual(status, 1)
        restore.assert_called_once_with()

    def test_cli_exposes_compiler_subcommands(self):
        from click.testing import CliRunner
        from kprof_dev.cli import main

        result = CliRunner().invoke(main, ["compiler", "--help"])
        self.assertEqual(result.exit_code, 0, result.output)
        self.assertIn("bootstrap", result.output)
        self.assertIn("system-install", result.output)
        self.assertIn("restore", result.output)

    def test_unknown_compiler_rejected(self):
        with self.assertRaisesRegex(ValueError, "Unknown compiler"):
            toolchains.compiler_for(toolchains.settings(), "GCC:99")


if __name__ == "__main__":
    unittest.main()
