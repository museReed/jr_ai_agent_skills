import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


INSTALLER = Path(__file__).resolve().parents[1]
DETECTOR = INSTALLER / "detect-environment.py"
CONFIGURATOR = INSTALLER / "configure-editor.py"
CODEX_CONFIGURATOR = INSTALLER / "configure-codex.py"


class DetectorTests(unittest.TestCase):
    def run_detector(
        self,
        *,
        commands=(),
        term_program="",
        parents="",
        settings=(),
        platform="darwin",
    ):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            bin_dir = root / "bin"
            bin_dir.mkdir()
            for command in commands:
                executable = bin_dir / command
                executable.write_text("#!/bin/sh\nexit 0\n")
                executable.chmod(0o755)
            for editor in settings:
                app = {
                    "cursor": "Cursor",
                    "antigravity": "Antigravity IDE",
                    "vscode": "Code",
                }[editor]
                path = (
                    root
                    / "Library"
                    / "Application Support"
                    / app
                    / "User"
                    / "settings.json"
                )
                path.parent.mkdir(parents=True)
                path.write_text("{}\n")
            env = os.environ.copy()
            env.update(
                {
                    "JR_DETECT_HOME": str(root),
                    "JR_DETECT_PLATFORM": platform,
                    "JR_DETECT_PATH": str(bin_dir),
                    "JR_DETECT_TERM_PROGRAM": term_program,
                    "JR_DETECT_PARENT_PROCESSES": parents,
                }
            )
            output = subprocess.run(
                ["python3", str(DETECTOR)],
                check=True,
                capture_output=True,
                text=True,
                env=env,
            ).stdout
            return json.loads(output)

    def test_recommends_only_installed_cli(self):
        self.assertEqual(
            self.run_detector(commands=("claude",))["recommended_install_target"],
            "claude",
        )
        self.assertEqual(
            self.run_detector(commands=("codex",))["recommended_install_target"],
            "codex",
        )

    def test_recommends_all_or_none(self):
        self.assertEqual(
            self.run_detector(commands=("claude", "codex"))[
                "recommended_install_target"
            ],
            "all",
        )
        self.assertEqual(self.run_detector()["recommended_install_target"], "none")

    def test_parent_process_has_priority(self):
        terminal = self.run_detector(
            term_program="vscode",
            parents="/Applications/Cursor.app/Contents/MacOS/Cursor",
        )["terminal"]
        self.assertEqual(terminal["detected"], "cursor")
        self.assertEqual(terminal["confidence"], "high")

    def test_native_terminal_is_detected(self):
        terminal = self.run_detector(term_program="Apple_Terminal")["terminal"]
        self.assertEqual(terminal["kind"], "native")
        self.assertEqual(terminal["detected"], "native")

    def test_known_parents_are_exact_and_sanitized(self):
        cases = {
            "/Applications/Cursor.app/Contents/MacOS/Cursor": "cursor",
            "/Applications/Antigravity.app/Contents/MacOS/Antigravity": "antigravity",
            "/Applications/Visual Studio Code.app/Contents/MacOS/Visual Studio Code": "vscode",
        }
        for parent, expected in cases.items():
            with self.subTest(parent=parent):
                result = self.run_detector(parents=parent)
                self.assertEqual(result["terminal"]["detected"], expected)
                self.assertNotIn("/Applications/", json.dumps(result))

    def test_loose_parent_name_does_not_match_or_leak(self):
        secret = "cursor-project-secret-token"
        result = self.run_detector(parents=secret)
        self.assertEqual(result["terminal"]["detected"], "unknown")
        self.assertEqual(result["terminal"]["parent_processes"], ["other"])
        self.assertNotIn(secret, json.dumps(result))

    def test_iterm_and_unknown_terminal(self):
        self.assertEqual(
            self.run_detector(term_program="iTerm.app")["terminal"]["detected"],
            "native",
        )
        unknown = self.run_detector(term_program="wezterm", parents="zsh")["terminal"]
        self.assertEqual(
            (unknown["detected"], unknown["confidence"]), ("unknown", "none")
        )
        self.assertEqual(
            self.run_detector(term_program="notcursor-terminal")["terminal"][
                "detected"
            ],
            "unknown",
        )

    def test_generic_vscode_uses_single_settings_path_as_weak_evidence(self):
        terminal = self.run_detector(term_program="vscode", settings=("antigravity",))[
            "terminal"
        ]
        self.assertEqual(terminal["detected"], "antigravity")
        self.assertEqual(terminal["confidence"], "low")

    def test_generic_vscode_stays_ambiguous_with_multiple_settings(self):
        terminal = self.run_detector(
            term_program="vscode", settings=("cursor", "vscode")
        )["terminal"]
        self.assertEqual(terminal["detected"], "vscode-family")
        self.assertEqual(terminal["confidence"], "low")

    def test_linux_settings_paths(self):
        path = self.run_detector(platform="linux")["editors"]["cursor"]["settings_path"]
        self.assertTrue(path.endswith("/.config/Cursor/User/settings.json"))

    def test_linux_respects_xdg_config_home(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            env = os.environ.copy()
            env.update(
                {
                    "JR_DETECT_HOME": str(root / "home"),
                    "JR_DETECT_PLATFORM": "linux",
                    "JR_DETECT_XDG_CONFIG_HOME": str(root / "xdg"),
                    "JR_DETECT_PATH": str(root),
                    "JR_DETECT_PARENT_PROCESSES": "",
                }
            )
            output = subprocess.run(
                ["python3", str(DETECTOR)], check=True, capture_output=True, text=True, env=env
            ).stdout
            path = json.loads(output)["editors"]["antigravity"]["settings_path"]
            self.assertEqual(path, str(root / "xdg" / "Antigravity IDE" / "User" / "settings.json"))


class ConfiguratorTests(unittest.TestCase):
    def run_configurator(self, root, editor):
        env = os.environ.copy()
        env.update({"JR_INSTALL_HOME": str(root), "JR_INSTALL_PLATFORM": "darwin"})
        return subprocess.run(
            ["python3", str(CONFIGURATOR), editor],
            capture_output=True,
            text=True,
            env=env,
        )

    def settings_path(self, root, editor):
        app = {"cursor": "Cursor", "antigravity": "Antigravity IDE", "vscode": "Code"}[
            editor
        ]
        return root / "Library" / "Application Support" / app / "User" / "settings.json"

    def test_only_confirmed_editor_is_modified(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            cursor = self.settings_path(root, "cursor")
            vscode = self.settings_path(root, "vscode")
            for path in (cursor, vscode):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('{"existing": true}\n')

            result = self.run_configurator(root, "cursor")

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(
                json.loads(cursor.read_text())["terminal.integrated.tabs.title"],
                "${sequence}",
            )
            self.assertEqual(json.loads(vscode.read_text()), {"existing": True})
            self.assertTrue(json.loads(cursor.read_text())["existing"])
            self.assertEqual(len(list(cursor.parent.glob("settings.json.bak.*"))), 1)

    def test_missing_file_permissions_and_idempotency(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = self.settings_path(root, "vscode")
            self.assertEqual(self.run_configurator(root, "vscode").returncode, 0)
            self.assertEqual(path.stat().st_mode & 0o777, 0o644)
            first = path.read_bytes()
            self.assertEqual(self.run_configurator(root, "vscode").returncode, 0)
            self.assertEqual(path.read_bytes(), first)
            self.assertEqual(list(path.parent.glob("settings.json.bak.*")), [])

    def test_existing_permissions_are_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = self.settings_path(root, "cursor")
            path.parent.mkdir(parents=True)
            path.write_text('{"existing": true}\n')
            path.chmod(0o600)
            self.assertEqual(self.run_configurator(root, "cursor").returncode, 0)
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_antigravity_legacy_path_is_preserved_when_it_already_exists(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = (
                root
                / "Library"
                / "Application Support"
                / "Antigravity"
                / "User"
                / "settings.json"
            )
            path.parent.mkdir(parents=True)
            path.write_text("{}\n")

            result = self.run_configurator(root, "antigravity")

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(
                json.loads(path.read_text())["terminal.integrated.tabs.title"],
                "${sequence}",
            )
            self.assertFalse(
                (root / "Library" / "Application Support" / "Antigravity IDE").exists()
            )

    def test_antigravity_existing_product_directory_wins_before_settings_exists(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            legacy = root / "Library" / "Application Support" / "Antigravity"
            legacy.mkdir(parents=True)
            result = self.run_configurator(root, "antigravity")
            path = legacy / "User" / "settings.json"
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(path.exists())
            self.assertFalse((root / "Library" / "Application Support" / "Antigravity IDE").exists())

    def test_jsonc_failure_leaves_original_byte_identical(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = self.settings_path(root, "antigravity")
            path.parent.mkdir(parents=True)
            original = b'{\n  // keep this comment\n  "existing": true\n}\n'
            path.write_bytes(original)
            result = self.run_configurator(root, "antigravity")
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(path.read_bytes(), original)
            self.assertEqual(list(path.parent.glob("settings.json.bak.*")), [])
            self.assertEqual(
                [item for item in path.parent.iterdir() if item != path], []
            )

    def test_native_terminal_changes_nothing(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            result = self.run_configurator(root, "native")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(list(root.rglob("settings.json")), [])

    def test_invalid_editor_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_configurator(Path(directory), "zed")
            self.assertEqual(result.returncode, 2)


class CodexConfiguratorTests(unittest.TestCase):
    def run_configurator(self, root, *args):
        env = os.environ.copy()
        env["JR_INSTALL_HOME"] = str(root)
        return subprocess.run(
            ["python3", str(CODEX_CONFIGURATOR), *args],
            capture_output=True,
            text=True,
            env=env,
        )

    def test_adds_tui_section_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / ".codex" / "config.toml"
            path.parent.mkdir(parents=True)
            path.write_text('model = "example"\n')
            self.assertEqual(self.run_configurator(root).returncode, 0)
            first = path.read_text()
            self.assertIn("[tui]\nterminal_title = []", first)
            self.assertEqual(self.run_configurator(root).returncode, 0)
            self.assertEqual(path.read_text(), first)
            self.assertEqual(len(list(path.parent.glob("config.toml.bak.*"))), 1)
            self.assertEqual(self.run_configurator(root, "--check").returncode, 0)

    def test_updates_existing_tui_without_losing_other_settings(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / ".codex" / "config.toml"
            path.parent.mkdir(parents=True)
            path.write_text('[tui]\nterminal_title = ["project-name"]\nnotifications = true\n\n[other]\nvalue = 1\n')
            self.assertEqual(self.run_configurator(root).returncode, 0)
            text = path.read_text()
            self.assertIn("terminal_title = []", text)
            self.assertIn("notifications = true", text)
            self.assertIn("[other]\nvalue = 1", text)

    def test_adds_key_to_existing_tui_before_next_section(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / ".codex" / "config.toml"
            path.parent.mkdir(parents=True)
            path.write_text("[tui]\nnotifications = true\n[other]\nvalue = 1\n")
            self.assertEqual(self.run_configurator(root).returncode, 0)
            self.assertIn("notifications = true\nterminal_title = []\n[other]", path.read_text())


class FlowFixtureTests(unittest.TestCase):
    def test_all_locales_embed_preinstall_question_state_machine(self):
        repo = INSTALLER.parent
        refusal = {"en": "do not switch", "zh-Hans": "不切换", "zh-Hant": "不切換"}
        ambiguity = {"en": "ambiguous", "zh-Hans": "模糊", "zh-Hant": "模糊"}
        for locale in ("en", "zh-Hans", "zh-Hant"):
            text = (repo / locale / "auto-rename-install.md").read_text()
            with self.subTest(locale=locale):
                self.assertIn("AskUserQuestion", text)
                self.assertIn("request_user_input", text)
                self.assertIn("/plan 繼續安裝 jr_ai_agent_skills", text)
                self.assertIn(refusal[locale], text)
                self.assertIn(ambiguity[locale], text)
                self.assertIn('TARGET="<claude|codex|all>"', text)

    def test_verify_editor_interface_and_resume_prompt_are_documented(self):
        verify = (INSTALLER / "verify.sh").read_text()
        install = (INSTALLER / "install.sh").read_text()
        self.assertIn("--editor=cursor|antigravity|vscode|native", verify)
        self.assertIn("Copy/paste this continuation prompt", install)
        self.assertIn("VERIFICATION.md", install)
        self.assertIn('configure-editor.py" "$CONFIRMED_EDITOR', install)

    def test_removed_section_references_do_not_return(self):
        readme = (INSTALLER / "README.md").read_text()
        self.assertNotIn("Section C/D", readme)
        diagnostic = (
            INSTALLER.parent / "zh-Hant" / "auto-rename-cursor-diagnostic.md"
        ).read_text()
        self.assertNotIn("Section A + C", diagnostic)


class InstallerInterfaceTests(unittest.TestCase):
    def test_each_target_and_editor_produces_concrete_resume_command(self):
        cases = (
            ("claude", "cursor", "./verify.sh claude --editor=cursor"),
            ("codex", "antigravity", "./verify.sh codex --editor=antigravity"),
            ("all", "vscode", "./verify.sh --editor=vscode"),
            ("all", "native", "./verify.sh --editor=native"),
        )
        for target, editor, expected in cases:
            with (
                self.subTest(target=target, editor=editor),
                tempfile.TemporaryDirectory() as home,
            ):
                env = os.environ.copy()
                env["HOME"] = home
                result = subprocess.run(
                    [
                        "bash",
                        str(INSTALLER / "install.sh"),
                        target,
                        f"--editor={editor}",
                    ],
                    capture_output=True,
                    text=True,
                    env=env,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(expected, result.stdout)
                self.assertNotIn("<confirmed-editor>", result.stdout)
                if target != "claude":
                    config = Path(home) / ".codex" / "config.toml"
                    self.assertIn("terminal_title = []", config.read_text())

    def test_invalid_or_missing_editor_is_rejected(self):
        for args in (("codex",), ("codex", "--editor=zed")):
            result = subprocess.run(
                ["bash", str(INSTALLER / "install.sh"), *args],
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
