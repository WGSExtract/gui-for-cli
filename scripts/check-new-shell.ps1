# CI entry point runs as a real new PowerShell 5.1 process, without -Command quoting.
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
$nodeRoot = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "gui-for-cli\node"
$node = Get-Command node
if (-not $node.Source.StartsWith("$nodeRoot\", [StringComparison]::OrdinalIgnoreCase)) {
    throw "Hosted Node shadowed setup Node: $($node.Source)"
}
Write-Host "New-shell Node: $($node.Source)"
foreach ($tool in @("uv", "node", "npm.cmd", "cargo")) {
    & $tool --version
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
& powershell -NoProfile -ExecutionPolicy Bypass -File .\make.ps1 precheck
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& uv run --locked python scripts/smoke-dev.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& npm.cmd --prefix app run tauri:prepare-node
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& node app/scripts/run-tauri.mjs build --debug --no-bundle
exit $LASTEXITCODE
