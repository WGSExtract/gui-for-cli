#!/usr/bin/env python3
"""Verify the documented development command and clean up its process tree."""

import sys

from dev_setup import smoke

smoke(
    [
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        ".\\make.ps1",
        "dev",
        "BUNDLE=examples/GitHelper",
        "PORT=0",
    ]
    if sys.platform == "win32"
    else ["make", "dev", "BUNDLE=examples/GitHelper", "PORT=0"]
)
