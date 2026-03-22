import os
import pathlib
import plistlib
import stat
import subprocess
import tempfile
import textwrap
import unittest


REPO = pathlib.Path(__file__).resolve().parents[1]
DEV_EDITOR = REPO / "bin" / "dev-editor"
DEV_EDITOR_GHOSTTY = REPO / "bin" / "dev-editor-ghostty"
ZED_SHIM = REPO / "bin" / "zed"
BUILD_ARTIFACTS = REPO / "config" / "scripts" / "build_editor_bridge_artifacts.py"


def write_executable(path: pathlib.Path, content: str) -> None:
    path.write_text(content)
    path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


class DevEditorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tempdir.name)
        self.home = self.root / "home"
        self.local_bin = self.home / ".local" / "bin"
        self.local_bin.mkdir(parents=True)
        self.logs = self.root / "logs"
        self.logs.mkdir()

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def base_env(self) -> dict[str, str]:
        return {
            "HOME": str(self.home),
            "USER": "tester",
            "LOGNAME": "tester",
            "PATH": "/usr/bin:/bin",
        }

    def write_config(self, payload: dict) -> pathlib.Path:
        config_path = self.home / ".config" / "editor-bridge" / "config.plist"
        config_path.parent.mkdir(parents=True)
        with config_path.open("wb") as handle:
            plistlib.dump(payload, handle)
        return config_path

    def run_cmd(self, args: list[str], env: dict[str, str]) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            args,
            cwd="/",
            env=env,
            text=True,
            capture_output=True,
            timeout=10,
        )

    def test_dev_editor_finds_nvim_from_bootstrapped_path(self) -> None:
        log = self.logs / "nvim.log"
        write_executable(
            self.local_bin / "nvim",
            textwrap.dedent(
                f"""\
                #!/usr/bin/env bash
                set -euo pipefail
                printf '%s\\n' "$*" >> "{log}"
                """
            ),
        )

        env = self.base_env()
        env["DEV_EDITOR_DISABLE_GHOSTTY"] = "1"
        result = self.run_cmd([str(DEV_EDITOR), "/tmp/example.txt"], env)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(log.read_text().strip(), "/tmp/example.txt")

    def test_dev_editor_reads_nvim_path_from_config(self) -> None:
        log = self.logs / "nvim.log"
        configured_nvim = self.local_bin / "configured-nvim"

        write_executable(
            configured_nvim,
            textwrap.dedent(
                f"""\
                #!/usr/bin/env bash
                set -euo pipefail
                printf '%s\\n' "$*" >> "{log}"
                """
            ),
        )

        self.write_config(
            {
                "launcher": {
                    "ghosttyApp": "Ghostty.app",
                    "nvimBin": str(configured_nvim),
                    "tmuxDefaultSession": "main",
                    "tmuxWindowName": "nvim",
                }
            }
        )

        env = self.base_env()
        env["DEV_EDITOR_DISABLE_GHOSTTY"] = "1"
        result = self.run_cmd([str(DEV_EDITOR), "/tmp/example.txt"], env)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(log.read_text().strip(), "/tmp/example.txt")

    def test_dev_editor_ghostty_finds_nvim_and_tmux_from_bootstrapped_path(self) -> None:
        tmux_log = self.logs / "tmux.log"
        fake_nvim = self.local_bin / "nvim"

        write_executable(
            fake_nvim,
            textwrap.dedent(
                """\
                #!/usr/bin/env bash
                set -euo pipefail
                """
            ),
        )

        write_executable(
            self.local_bin / "tmux",
            textwrap.dedent(
                f"""\
                #!/usr/bin/env bash
                set -euo pipefail
                printf 'tmux:%s\\n' "$*" >> "{tmux_log}"
                cmd="${{1:-}}"
                shift || true
                case "$cmd" in
                  list-sessions)
                    exit 0
                    ;;
                  new-session|new-window)
                    exit 0
                    ;;
                  attach-session|wait-for|detach-client)
                    exit 0
                    ;;
                  display-message)
                    exit 1
                    ;;
                esac
                """
            ),
        )

        env = self.base_env()
        result = self.run_cmd([str(DEV_EDITOR_GHOSTTY), "--cwd", "/", "--", "/tmp/example.txt"], env)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("tmux:new-session", tmux_log.read_text())
        self.assertIn(str(fake_nvim), tmux_log.read_text())

    def test_dev_editor_ghostty_picks_existing_session_in_stripped_env(self) -> None:
        tmux_log = self.logs / "tmux.log"
        fake_nvim = self.local_bin / "nvim"

        write_executable(
            fake_nvim,
            textwrap.dedent(
                """\
                #!/usr/bin/env bash
                set -euo pipefail
                """
            ),
        )

        write_executable(
            self.local_bin / "tmux",
            textwrap.dedent(
                f"""\
                #!/usr/bin/env bash
                set -euo pipefail
                printf 'tmux:%s\\n' "$*" >> "{tmux_log}"
                cmd="${{1:-}}"
                shift || true
                case "$cmd" in
                  list-sessions)
                    printf '0:10:10:main\\n0:20:30:work\\n'
                    exit 0
                    ;;
                  new-window|attach-session|wait-for|detach-client)
                    exit 0
                    ;;
                  display-message)
                    exit 1
                    ;;
                esac
                """
            ),
        )

        env = self.base_env()
        result = self.run_cmd([str(DEV_EDITOR_GHOSTTY), "--cwd", "/", "--", "/tmp/example.txt"], env)

        self.assertEqual(result.returncode, 0, result.stderr)
        log = tmux_log.read_text()
        self.assertIn("tmux:new-window -t work:", log)
        self.assertIn(str(fake_nvim), log)
        self.assertIn("tmux:attach-session -t work", log)

    def test_dev_editor_ghostty_stay_attached_does_not_detach_client(self) -> None:
        tmux_log = self.logs / "tmux.log"
        fake_nvim = self.local_bin / "nvim"

        write_executable(
            fake_nvim,
            textwrap.dedent(
                """\
                #!/usr/bin/env bash
                set -euo pipefail
                """
            ),
        )

        write_executable(
            self.local_bin / "tmux",
            textwrap.dedent(
                f"""\
                #!/usr/bin/env bash
                set -euo pipefail
                printf 'tmux:%s\\n' "$*" >> "{tmux_log}"
                cmd="${{1:-}}"
                shift || true
                case "$cmd" in
                  list-sessions)
                    printf '1:10:20:work\\n'
                    exit 0
                    ;;
                  new-window|attach-session)
                    exit 0
                    ;;
                  display-message)
                    exit 1
                    ;;
                esac
                """
            ),
        )

        env = self.base_env()
        result = self.run_cmd(
            [str(DEV_EDITOR_GHOSTTY), "--stay-attached", "--cwd", "/", "--", "/tmp/example.txt"],
            env,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        log = tmux_log.read_text()
        self.assertIn("tmux:new-window -t work:", log)
        self.assertIn("tmux:attach-session -t work", log)
        self.assertNotIn("detach-client", log)

    def test_dev_editor_ghostty_stay_attached_creates_shell_session_when_none_exists(self) -> None:
        tmux_log = self.logs / "tmux.log"
        fake_nvim = self.local_bin / "nvim"
        fake_zsh = self.local_bin / "zsh"

        write_executable(
            fake_nvim,
            textwrap.dedent(
                """\
                #!/usr/bin/env bash
                set -euo pipefail
                """
            ),
        )

        write_executable(
            fake_zsh,
            textwrap.dedent(
                """\
                #!/usr/bin/env bash
                set -euo pipefail
                """
            ),
        )

        write_executable(
            self.local_bin / "tmux",
            textwrap.dedent(
                f"""\
                #!/usr/bin/env bash
                set -euo pipefail
                printf 'tmux:%s\\n' "$*" >> "{tmux_log}"
                cmd="${{1:-}}"
                shift || true
                case "$cmd" in
                  list-sessions)
                    exit 0
                    ;;
                  new-session|new-window|attach-session)
                    exit 0
                    ;;
                  display-message)
                    exit 1
                    ;;
                esac
                """
            ),
        )

        env = self.base_env()
        result = self.run_cmd(
            [str(DEV_EDITOR_GHOSTTY), "--stay-attached", "--cwd", "/", "--", "/tmp/example.txt"],
            env,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        log = tmux_log.read_text()
        self.assertIn("tmux:new-session -d -s main -n shell -c /", log)
        self.assertIn("tmux:new-window -t main:", log)
        self.assertIn(str(fake_nvim), log)
        self.assertIn("tmux:attach-session -t main", log)

    def test_dev_editor_ghostty_uses_configured_tmux_names(self) -> None:
        tmux_log = self.logs / "tmux.log"
        fake_nvim = self.local_bin / "nvim"

        write_executable(
            fake_nvim,
            textwrap.dedent(
                """\
                #!/usr/bin/env bash
                set -euo pipefail
                """
            ),
        )

        write_executable(
            self.local_bin / "tmux",
            textwrap.dedent(
                f"""\
                #!/usr/bin/env bash
                set -euo pipefail
                printf 'tmux:%s\\n' "$*" >> "{tmux_log}"
                cmd="${{1:-}}"
                shift || true
                case "$cmd" in
                  list-sessions)
                    exit 0
                    ;;
                  new-session)
                    exit 0
                    ;;
                  display-message)
                    exit 1
                    ;;
                esac
                """
            ),
        )

        self.write_config(
            {
                "launcher": {
                    "ghosttyApp": "Ghostty.app",
                    "nvimBin": str(fake_nvim),
                    "tmuxDefaultSession": "workspace",
                    "tmuxWindowName": "editor",
                }
            }
        )

        env = self.base_env()
        result = self.run_cmd([str(DEV_EDITOR_GHOSTTY), "--cwd", "/", "--", "/tmp/example.txt"], env)

        self.assertEqual(result.returncode, 0, result.stderr)
        log = tmux_log.read_text()
        self.assertIn("tmux:new-session -s workspace -n editor -c /", log)
        self.assertIn(str(fake_nvim), log)

    def test_zed_shim_uses_nonblocking_launcher_by_default(self) -> None:
        open_log = self.logs / "open.log"
        wait_log = self.logs / "wait.log"

        write_executable(
            self.local_bin / "dev-editor-open",
            textwrap.dedent(
                f"""\
                #!/usr/bin/env bash
                set -euo pipefail
                printf '%s\\n' "$*" >> "{open_log}"
                """
            ),
        )

        write_executable(
            self.local_bin / "dev-editor",
            textwrap.dedent(
                f"""\
                #!/usr/bin/env bash
                set -euo pipefail
                printf '%s\\n' "$*" >> "{wait_log}"
                """
            ),
        )

        env = self.base_env()
        result = self.run_cmd([str(ZED_SHIM), "/tmp/example.txt"], env)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(open_log.read_text().strip(), "/tmp/example.txt")
        self.assertFalse(wait_log.exists())

    def test_zed_shim_wait_mode_uses_blocking_launcher_and_maps_cursor(self) -> None:
        open_log = self.logs / "open.log"
        wait_log = self.logs / "wait.log"
        target = self.root / "example.txt"
        target.write_text("hello\n")

        write_executable(
            self.local_bin / "dev-editor-open",
            textwrap.dedent(
                f"""\
                #!/usr/bin/env bash
                set -euo pipefail
                printf '%s\\n' "$*" >> "{open_log}"
                """
            ),
        )

        write_executable(
            self.local_bin / "dev-editor",
            textwrap.dedent(
                f"""\
                #!/usr/bin/env bash
                set -euo pipefail
                printf '%s\\n' "$*" >> "{wait_log}"
                """
            ),
        )

        env = self.base_env()
        result = self.run_cmd([str(ZED_SHIM), "--wait", f"{target}:12:4"], env)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(open_log.exists())
        self.assertEqual(wait_log.read_text().strip(), f"+call cursor(12,4) {target}")

    def test_build_artifacts_generates_custom_uti_and_filtered_lists(self) -> None:
        config_path = self.root / "config.plist"
        fragment_path = self.root / "generated" / "fragment.plist"
        uti_list_path = self.root / "generated" / "utis.txt"
        manifest_path = self.root / "manifest.json"

        with config_path.open("wb") as handle:
            plistlib.dump(
                {
                    "associations": {
                        "includeStaticBaseTypes": True,
                        "includeProgrammingPreset": True,
                        "includePlainText": False,
                        "includePublicData": True,
                        "customExtensions": [".foo"],
                        "customFilenames": [".customrc"],
                        "excludedExtensions": [".bar"],
                        "excludedFilenames": ["Dockerfile"],
                        "extraContentTypes": ["public.python-script"],
                    }
                },
                handle,
            )

        manifest_path.write_text(
            textwrap.dedent(
                """\
                {
                  "extensions": ["bar", "baz"],
                  "filenames": ["Dockerfile", ".envrc"]
                }
                """
            )
        )

        result = self.run_cmd(
            [
                "/usr/bin/env",
                "python3",
                str(BUILD_ARTIFACTS),
                "--config",
                str(config_path),
                "--fragment",
                str(fragment_path),
                "--uti-list",
                str(uti_list_path),
                "--manifest",
                str(manifest_path),
            ],
            self.base_env(),
        )

        self.assertEqual(result.returncode, 0, result.stderr)

        with fragment_path.open("rb") as handle:
            fragment = plistlib.load(handle)

        exported = fragment["UTExportedTypeDeclarations"][0]
        self.assertEqual(exported["UTTypeIdentifier"], "dev.editorbridge.programmable.custom")
        self.assertEqual(exported["UTTypeTagSpecification"]["public.filename-extension"], ["baz", "foo"])
        self.assertEqual(exported["UTTypeTagSpecification"]["public.filename"], [".customrc", ".envrc"])

        self.assertIn("public.data", uti_list_path.read_text())
        self.assertIn("public.python-script", uti_list_path.read_text())
        self.assertIn("dev.editorbridge.programmable.custom", uti_list_path.read_text())


if __name__ == "__main__":
    unittest.main()
