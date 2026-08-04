# Run headless glider controller verification.
# Usage: .cursor/skills/glider-game-feel/scripts/run-verify.ps1

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")
$GodotCandidates = @(
    "C:\Users\olema\OneDrive\Documents\heathen\.tools\Godot_v4.6.3-stable_win64_console.exe",
    "godot",
    "Godot_v4.6.3-stable_win64_console.exe"
)

$Godot = $null
foreach ($candidate in $GodotCandidates) {
    if ($candidate -match '[\\/]' -and (Test-Path $candidate)) {
        $Godot = $candidate
        break
    }
    $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($cmd) {
        $Godot = $cmd.Source
        break
    }
}

if (-not $Godot) {
    Write-Error "Godot console binary not found. Set path in run-verify.ps1 or add godot to PATH."
}

Write-Host "Project: $ProjectRoot"
Write-Host "Godot:   $Godot"
Write-Host ""

& $Godot --headless --path $ProjectRoot --script res://scripts/player/verify_glider.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $Godot --headless --path $ProjectRoot --script res://scripts/world/verify_ripple_spawner.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $Godot --headless --path $ProjectRoot --script res://scripts/world/verify_radar_pulse.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $Godot --headless --path $ProjectRoot --script res://scripts/world/verify_outpost_spawner.gd
exit $LASTEXITCODE
