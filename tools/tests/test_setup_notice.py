"""Exercise POSIX setup notice behavior without downloading or installing tools."""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipIf(os.name == "nt", "POSIX setup")
class SetupNoticeTests(unittest.TestCase):
    def test_notice_only_on_changes_and_also_after_failure(self) -> None:
        (ROOT / "tmp").mkdir(exist_ok=True)
        for failing in (False, True):
            with (
                self.subTest(failing=failing),
                tempfile.TemporaryDirectory(
                    prefix="setup-notice-", dir=ROOT / "tmp"
                ) as directory,
            ):
                home = Path(directory)
                tools = home / ".local/bin"
                tools.mkdir(parents=True)
                login_profile = home / ".bash_profile"
                login_profile.write_text(
                    "# Does not source .profile or .bashrc\n", encoding="utf-8"
                )
                for tool in ("node", "cargo"):
                    (tools / tool).write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
                    (tools / tool).chmod(0o755)
                (tools / "uv").write_text(
                    '#!/bin/sh\nif [ "$1" = run ] && [ -f "$HOME/fail" ]; then exit 23; fi\n',
                    encoding="utf-8",
                )
                (tools / "uv").chmod(0o755)
                if failing:
                    (home / "fail").touch()
                env = {**os.environ, "HOME": str(home)}
                for changed in (True, False):
                    result = subprocess.run(
                        [
                            shutil.which("sh") or "sh",
                            "scripts/dev_setup.sh",
                            "--skip-smoke",
                        ],
                        cwd=ROOT,
                        env=env,
                        capture_output=True,
                        text=True,
                        check=False,
                    )
                    self.assertEqual(
                        result.returncode, 23 if failing else 0, result.stderr
                    )
                    self.assertEqual("Open a new terminal" in result.stdout, changed)
                bash = shutil.which("bash")
                if bash:
                    login = subprocess.run(
                        [
                            bash,
                            "--noprofile",
                            "--norc",
                            "-c",
                            '. "$HOME/.bash_profile"; command -v node',
                        ],
                        env=env,
                        capture_output=True,
                        text=True,
                        check=True,
                    )
                    self.assertEqual(login.stdout.strip(), str(tools / "node"))


if __name__ == "__main__":
    unittest.main()
