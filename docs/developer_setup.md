# Developer setup

Clone the repository, then run one command from its root:

```sh
git clone https://github.com/theontho/gui-for-cli.git
cd gui-for-cli
make setup
```

On Linux/macOS without `make`, use `sh scripts/dev_setup.sh` instead.
On Windows, use **Windows PowerShell 5.1**, not WSL:

```powershell
git clone https://github.com/theontho/gui-for-cli.git
cd gui-for-cli
powershell -ExecutionPolicy Bypass -File .\make.ps1 setup
```

## What setup does

- Installs missing **user-level** uv, Node.js (22+; bootstraps 24.15.0), and
  Rust/Cargo (minimal stable toolchain). uv supplies Python 3.11+ when needed.
  Node archives are verified against the publisher's SHA-256 checksums.
- Runs `uv sync --locked` and `npm --prefix app ci`; does not rewrite lockfiles.
- Registers an available developer identity using the existing identity tool,
  without changing Git configuration; installs and checks the existing hooks.
  If no identity exists, this is advisory: set `git config user.name "Your Name"`
  and `git config user.email "you@example.com"`, then run
  `uv run python scripts/dev-register.py` before committing.
- Checks tool versions and locked Cargo metadata, compiles TypeScript, starts the
  real GitHelper server on an ephemeral loopback port, verifies HTTP 200, and
  stops it. The smoke log is in `tmp/dev-setup/smoke.log`.
- Advises about GitHub CLI authentication and an optional AI-agent CLI. It does
  **not** install or authenticate these, or change your Git identity.

Safe to rerun. Open a **new terminal** if prompted: setup persists user tool
directories for future terminals, but cannot change its parent's PATH.
Downloads/installers are from the tools' official HTTPS endpoints; review the
scripts before running if your organization requires approval.

Skip only the quick smoke check with `sh scripts/dev_setup.sh --skip-smoke` or
`powershell -ExecutionPolicy Bypass -File scripts\dev_setup.ps1 -SkipSmoke`.
For browser-only work, add `--web-only` / `-WebOnly` to waive desktop prerequisite
checks (Rust is still installed). Default setup exits nonzero if desktop system
prerequisites are missing, after preparing the Web UI.

## Manual prerequisites

Setup never runs sudo, elevates, or installs system packages.
You need Git and a network connection. Linux/macOS also need curl, tar, and a
SHA-256 tool (`sha256sum` or macOS `shasum`).

- **Debian/Ubuntu:** an administrator runs
  `sudo apt-get update && sudo apt-get install build-essential pkg-config libwebkit2gtk-4.1-dev libayatana-appindicator3-dev librsvg2-dev patchelf`.
- **Fedora:** an administrator runs
  `sudo dnf install gcc gcc-c++ make pkgconf-pkg-config webkit2gtk4.1-devel gtk3-devel libappindicator-gtk3-devel librsvg2-devel patchelf`.
- **macOS:** `xcode-select --install`, and accept the Command Line Tools dialog.
  Signing/notarization credentials are unnecessary for ordinary development.
- **Windows:** [Git for Windows](https://git-scm.com/download/win),
  [Visual Studio Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/)
  with **Desktop development with C++** and a Windows 10/11 SDK, and
  [WebView2 Evergreen Runtime](https://developer.microsoft.com/microsoft-edge/webview2/)
  (normally included with Windows 11). These may require an administrator.

The script detects missing desktop prerequisites and prints installation
instructions; see also the [Tauri prerequisite guide](https://v2.tauri.app/start/prerequisites/).

There is **no required sibling wgsextract-cli checkout** for UI development.
Start with `examples/GitHelper`, which uses Git already on PATH. The default
WGSExtract bundle's genome actions have separate CLI/runtime/data requirements;
install those through its documented bundle setup when you need that workflow.
Developer setup does not download genomes or run extraction.

## Change → check → PR

```sh
git switch -c my-change
make dev BUNDLE=examples/GitHelper
# Open http://127.0.0.1:8787. Edit a bundle page or a localized string.
# Stop the server with Ctrl-C before running the checks.
make lint
make test
git add <the-files-you-changed>
git commit -m "Describe the change"
git push -u origin my-change
gh pr create --fill
```

Windows: replace each `make <target>` with `.\make.ps1 <target>`.
For a fork, push to your fork and open a PR against `theontho/gui-for-cli`.
Hooks check identity/lint on commit and tests on push. Run `make build-tauri`
after changing the Tauri shell or packaging. `make tauri` runs the desktop UI.

## Make an AI-directed change

Install and authenticate your preferred agent CLI using its official instructions.
Run it from this repository so it reads `AGENTS.md` / `CLAUDE.md`.
Pick an issue from the
[good-first-issue list](https://github.com/theontho/gui-for-cli/labels/good%20first%20issue)
and give it a bounded request, for example:

> Fix #N. Read the issue and repository instructions, confirm the behavior,
> implement the acceptance criteria with a regression test, run `make lint` and
> `make test`, and open a PR. Do not merge. Summarize the checks and any limitations.

Review the diff, try the change yourself, and wait for CI before requesting review.
The Developer setup CI matrix exercises this setup on fresh Ubuntu, macOS, and
Windows runners without tool-setup actions, including reruns and a new-shell PATH
check. Hosted runners supply the OS-level prerequisites; the script itself never
installs those.
