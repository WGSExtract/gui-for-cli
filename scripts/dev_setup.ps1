param(
    [switch]$SkipSmoke,
    [switch]$WebOnly
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Set-Location (Split-Path $PSScriptRoot -Parent)
New-Item -ItemType Directory -Force "tmp\dev-setup" | Out-Null
$env:TEMP = Join-Path $PWD "tmp\dev-setup"
$env:TMP = $env:TEMP
$originalPath = $env:Path
$userBin = Join-Path ([Environment]::GetFolderPath("UserProfile")) ".local\bin"
$cargoBin = Join-Path ([Environment]::GetFolderPath("UserProfile")) ".cargo\bin"
$nodeRoot = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "gui-for-cli\node"
$env:Path = "$userBin;$cargoBin;$nodeRoot;$env:Path"

function Invoke-Checked {
    param([string]$Command, [string[]]$Arguments)
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Command failed (exit $LASTEXITCODE)." }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Install Git for Windows: https://git-scm.com/download/win, then rerun setup."
}
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Invoke-WebRequest -UseBasicParsing https://astral.sh/uv/install.ps1 -OutFile tmp\dev-setup\uv-install.ps1
    $oldInstallDir = $env:UV_INSTALL_DIR
    $env:UV_INSTALL_DIR = $userBin
    & powershell -NoProfile -ExecutionPolicy Bypass -File tmp\dev-setup\uv-install.ps1
    $env:UV_INSTALL_DIR = $oldInstallDir
    if ($LASTEXITCODE -ne 0) { throw "uv installation failed." }
}
$node = Get-Command node -ErrorAction SilentlyContinue
$nodeMajor = 0
if ($node) { $nodeMajor = [int]((& node --version).TrimStart("v").Split(".")[0]) }
if ($nodeMajor -lt 22) {
    $version = "24.15.0"
    $arch = if ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq "Arm64") { "arm64" } else { "x64" }
    $archive = "node-v$version-win-$arch.zip"
    Invoke-WebRequest -UseBasicParsing "https://nodejs.org/dist/v$version/$archive" -OutFile "tmp\dev-setup\$archive"
    $sums = (Invoke-WebRequest -UseBasicParsing "https://nodejs.org/dist/v$version/SHASUMS256.txt").Content
    $expected = ($sums -split "`n" | Where-Object { $_.Trim().EndsWith("  $archive") }).Trim().Split(" ")[0]
    $sha = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead((Join-Path $PWD "tmp\dev-setup\$archive"))
    try { $actual = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace("-", "").ToLowerInvariant() }
    finally { $stream.Dispose(); $sha.Dispose() }
    if ($actual -ne $expected) { throw "Node archive checksum mismatch." }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $unpack = Join-Path $PWD "tmp\dev-setup\node"
    if (Test-Path $unpack) { Remove-Item -Recurse -Force $unpack }
    [IO.Compression.ZipFile]::ExtractToDirectory((Join-Path $PWD "tmp\dev-setup\$archive"), $unpack)
    New-Item -ItemType Directory -Force $nodeRoot | Out-Null
    Copy-Item "$unpack\node-v$version-win-$arch\*" $nodeRoot -Recurse -Force
}
if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    $arch = if ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq "Arm64") { "aarch64" } else { "x86_64" }
    Invoke-WebRequest -UseBasicParsing "https://static.rust-lang.org/rustup/dist/$arch-pc-windows-msvc/rustup-init.exe" -OutFile tmp\dev-setup\rustup-init.exe
    Invoke-Checked "tmp\dev-setup\rustup-init.exe" @("-y", "--profile", "minimal", "--default-host", "$arch-pc-windows-msvc")
}
# User scope only; no elevation, winget, or machine PATH changes.
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
foreach ($directory in @($userBin, $cargoBin, $nodeRoot)) {
    if (($userPath -split ";") -notcontains $directory) { $userPath = "$directory;$userPath" }
}
[Environment]::SetEnvironmentVariable("Path", $userPath, "User")
Invoke-Checked "uv" @("sync", "--locked")
$arguments = @("run", "--locked", "python", "scripts/dev_setup.py")
if ($SkipSmoke) { $arguments += "--skip-smoke" }
if ($WebOnly) { $arguments += "--web-only" }
Invoke-Checked "uv" $arguments
if ($originalPath -ne $env:Path) { Write-Host "Open a new terminal before running .\make.ps1 dev (setup added user tool paths)." }
exit 0
