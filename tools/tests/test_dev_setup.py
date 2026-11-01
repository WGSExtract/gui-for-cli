"""Focused checks for shared setup prerequisite handling."""

from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path
from unittest.mock import mock_open, patch

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/dev_setup.py"
SPEC = importlib.util.spec_from_file_location("dev_setup", SCRIPT)
assert SPEC and SPEC.loader
setup = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(setup)
REGISTER_SPEC = importlib.util.spec_from_file_location(
    "dev_register", SCRIPT.with_name("dev-register.py")
)
assert REGISTER_SPEC and REGISTER_SPEC.loader
register = importlib.util.module_from_spec(REGISTER_SPEC)
sys.modules[REGISTER_SPEC.name] = register
REGISTER_SPEC.loader.exec_module(register)


class DesktopPrerequisiteTests(unittest.TestCase):
    def test_missing_desktop_prerequisites_fail_unless_web_only_is_requested(
        self,
    ) -> None:
        for flags, expected in [([], 1), (["--web-only"], 0)]:
            with (
                self.subTest(flags=flags),
                patch.object(sys, "argv", ["dev_setup.py", "--skip-smoke", *flags]),
                patch.object(
                    setup,
                    "desktop_prerequisites",
                    return_value=["Install system libraries"],
                ),
                patch.object(setup, "run"),
                patch.object(setup, "succeeds", return_value=True),
                patch.object(setup, "smoke") as smoke,
            ):
                self.assertEqual(setup.main(), expected)
                smoke.assert_not_called()

    def test_registration_preserves_local_identity_without_github_or_config_write(
        self,
    ) -> None:
        with (
            patch.object(
                sys,
                "argv",
                [
                    "dev-register.py",
                    "--local-only",
                    "--no-update-git-config",
                    "--choice",
                    "1",
                ],
            ),
            patch.object(
                register, "git_config", side_effect=["Developer", "dev@example.com"]
            ),
            patch.object(register, "available_identities") as github,
            patch.object(register, "run") as command,
            patch("builtins.open", mock_open()) as output,
        ):
            self.assertEqual(register.main(), 0)
        github.assert_not_called()
        command.assert_not_called()
        output().write.assert_called_once_with(
            "name=Developer\nemail=dev@example.com\n"
        )

    def test_linux_missing_webkit_prints_admin_commands(self) -> None:
        with (
            patch.object(setup.sys, "platform", "linux"),
            patch.object(setup, "succeeds", return_value=False),
        ):
            instructions = setup.desktop_prerequisites()
        self.assertTrue(any("libwebkit2gtk-4.1-dev" in item for item in instructions))
        self.assertTrue(any("sudo dnf install" in item for item in instructions))

    def test_linux_with_libraries_but_no_compiler_is_not_ready(self) -> None:
        with (
            patch.object(setup.sys, "platform", "linux"),
            patch.object(setup, "succeeds", return_value=True),
            patch.object(setup.shutil, "which", return_value=None),
        ):
            self.assertTrue(setup.desktop_prerequisites())

    def test_macos_needs_working_clang_not_only_xcode_path(self) -> None:
        with (
            patch.object(setup.sys, "platform", "darwin"),
            patch.object(setup, "succeeds", side_effect=[True, False]),
        ):
            self.assertEqual(
                setup.desktop_prerequisites(),
                ["macOS: xcode-select --install (accept the installer dialog)."],
            )


if __name__ == "__main__":
    unittest.main()
