<#
.SYNOPSIS
  Set the windowed Video Mode (client size) in BOTH Kenshi installs' kenshi.cfg.

.DESCRIPTION
  Kenshi reads its window size from kenshi.cfg ("Video Mode=W x H @ 32-bit
  colour [0]"); the window tiler (arrange_windows.ps1) only MOVES windows, so
  the size each session wants must be written here before launch. The two
  harnesses call this with their own layout:
    * manual_session.ps1 -> plain windowed default (1080x720 per client, no
      auto-positioning - see -WindowW/-WindowH there). Pass -Tile to that
      script for host-left/join-right auto-positioning instead, with a
      smaller -WindowW sized for the target monitor's actual width.
    * run_test.ps1       -> automated layout (1280x1024 pair on the laptop
      primary monitor, the long-standing screenshot-stable baseline)
  Idempotent: only rewrites a cfg whose current mode differs. Also enforces
  windowed mode (Full Screen=No).

  This machine's real displays are two ~1920px-wide screens, not one wide
  ultrawide panel - don't assume a 3440-class monitor when picking a size.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\set_video_mode.ps1 -Width 1700 -Height 1350
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][int]$Width,
    [Parameter(Mandatory = $true)][int]$Height,
    [string]$HostDir = "C:\Program Files (x86)\Steam\steamapps\common\Kenshi",
    [string]$JoinDir = "$env:USERPROFILE\Kenshi-Join"
)

$ErrorActionPreference = "Stop"

foreach ($dir in @($HostDir, $JoinDir)) {
    $cfg = Join-Path $dir "kenshi.cfg"
    if (-not (Test-Path $cfg)) { Write-Warning "kenshi.cfg not found: $cfg"; continue }
    $lines = Get-Content $cfg
    $want = "Video Mode=$Width x $Height @ 32-bit colour [0]"
    $changed = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^Video Mode=") {
            if ($lines[$i] -ne $want) { $lines[$i] = $want; $changed = $true }
        } elseif ($lines[$i] -match "^Full Screen=" -and $lines[$i] -ne "Full Screen=No") {
            $lines[$i] = "Full Screen=No"; $changed = $true
        }
    }
    if ($changed) {
        Set-Content -Path $cfg -Value $lines -Encoding ASCII
        Write-Host "  video mode -> ${Width}x${Height} (windowed) in $cfg"
    } else {
        Write-Host "  video mode already ${Width}x${Height} (windowed) in $cfg"
    }
}
