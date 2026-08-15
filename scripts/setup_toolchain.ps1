# Fetches and configures everything the v100 plugin toolchain needs beyond
# the compiler itself: ENet + patches, the pinned/patched KenshiLib_deps
# snapshot, Boost extraction, env vars, and (optionally) VS2022 Build Tools
# with the C++ workload MSBuild needs to drive the legacy v100 toolset.
#
# What this script CANNOT do: install the VC++ 2010 (v100) compiler itself
# (Windows SDK 7.1 + the KB2519277 compiler update). That installer is an
# interactive GUI wizard with no reliable silent path - see docs/BUILD_SETUP.md
# "Part A" for the manual walkthrough. Run this script either before or after
# that step; it just reports whether the compiler is there yet.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\setup_toolchain.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\setup_toolchain.ps1 -Yes   (no prompts)

param(
    [switch]$Yes,                # skip confirmation prompts (for automation)
    [switch]$SkipBuildToolsInstall  # never install VS2022 Build Tools even if missing
)

# Deliberately NOT $ErrorActionPreference = "Stop": under PS 5.1, a "Stop"
# preference turns any native exe's stderr output into a terminating error,
# even routine/expected ones (e.g. a probing "git apply --check" that's
# supposed to fail sometimes). Native-command failures are instead checked
# explicitly via $LASTEXITCODE below, so real failures still get caught.
$ErrorActionPreference = "Continue"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

$KenshiLibPin = "e75769b"  # see third_party/KenshiLib_patches/README.md for why

function Write-Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  [ok] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  [!] $msg" -ForegroundColor Yellow }
function Write-Bad($msg)  { Write-Host "  [MISSING] $msg" -ForegroundColor Red }

function Confirm-Action($prompt) {
    if ($Yes) { return $true }
    $answer = Read-Host "$prompt [y/N]"
    return $answer -match '^[Yy]'
}

# Applies a patch from the repo root if not already applied; safe to re-run.
# Note: native-exe stderr is intentionally routed to $null, not 2>&1 - under
# $ErrorActionPreference = "Stop", PowerShell 5.1 turns a native command's
# stderr output into a terminating error even on a routine, expected "check
# failed" probe like this one. $LASTEXITCODE is what actually matters here.
function Apply-PatchIfNeeded($patchPath, $label) {
    & git apply --check $patchPath 2>$null
    if ($LASTEXITCODE -eq 0) {
        & git apply $patchPath
        Write-Ok "applied $label"
        return
    }
    & git apply --reverse --check $patchPath 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "$label already applied"
        return
    }
    Write-Warn "$label did not apply cleanly (forward or reverse) - inspect manually: $patchPath"
}

# ---------------------------------------------------------------------------
Write-Step "ENet"

$enetDir = "third_party\enet\enet"
if (-not (Test-Path "$enetDir\include\enet\enet.h")) {
    Write-Host "  Cloning ENet..."
    git clone https://github.com/lsalzman/enet.git $enetDir
    if ($LASTEXITCODE -ne 0) { Write-Bad "ENet clone failed"; exit 1 }
} else {
    Write-Ok "ENet source already present"
}

Get-ChildItem "third_party\enet\patches\*.patch" | ForEach-Object {
    Apply-PatchIfNeeded $_.FullName $_.Name
}

# ---------------------------------------------------------------------------
Write-Step "KenshiLib_deps (pinned to $KenshiLibPin)"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Bad "git not found on PATH - cannot fetch dependencies"
    exit 1
}
& git lfs version 2>$null 1>$null
if ($LASTEXITCODE -ne 0) {
    Write-Warn "git-lfs not found - KenshiLib.lib etc. would be tiny pointer stubs, not real binaries. Install git-lfs first: https://git-lfs.com"
} else {
    Write-Ok "git-lfs present"
}

$depsDir = "third_party\KenshiLib_deps"
if (-not (Test-Path "$depsDir\.git")) {
    Write-Host "  Cloning KenshiLib_Examples_deps (this pulls Boost via git-LFS, ~150MB)..."
    git clone https://github.com/BFrizzleFoShizzle/KenshiLib_Examples_deps.git $depsDir
    if ($LASTEXITCODE -ne 0) { Write-Bad "KenshiLib_deps clone failed"; exit 1 }
} else {
    Write-Ok "KenshiLib_deps clone already present"
}

Push-Location $depsDir
try {
    $currentCommit = (& git rev-parse HEAD).Substring(0, 7)
    if ($currentCommit -ne $KenshiLibPin) {
        Write-Host "  Pinning to $KenshiLibPin (was $currentCommit)..."
        & git fetch origin 2>$null | Out-Null
        & git reset --hard $KenshiLibPin 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Bad "checkout of pin $KenshiLibPin failed"; Pop-Location; exit 1 }
        & git clean -fdx -- KenshiLib/Include 2>$null | Out-Null
        Write-Ok "pinned to $KenshiLibPin"
    } else {
        Write-Ok "already pinned to $KenshiLibPin"
    }
} finally {
    Pop-Location
}

$boostZip = "$depsDir\boost_1_60_0\boost.zip"
$boostMarker = "$depsDir\boost_1_60_0\boost\version.hpp"
if ((Test-Path $boostZip) -and -not (Test-Path $boostMarker)) {
    Write-Host "  Extracting Boost..."
    Expand-Archive -Path $boostZip -DestinationPath "$depsDir\boost_1_60_0" -Force
    Write-Ok "Boost extracted"
} elseif (Test-Path $boostMarker) {
    Write-Ok "Boost already extracted"
} else {
    Write-Bad "boost.zip not found at $boostZip - KenshiLib_deps clone may be incomplete"
}

Get-ChildItem "third_party\KenshiLib_patches\*.patch" | ForEach-Object {
    Apply-PatchIfNeeded $_.FullName $_.Name
}

# ---------------------------------------------------------------------------
Write-Step "Environment variables (user scope)"

$kenshilibDir = Join-Path $RepoRoot "$depsDir\KenshiLib"
$boostInclude = Join-Path $RepoRoot "$depsDir\boost_1_60_0"

[Environment]::SetEnvironmentVariable("KENSHILIB_DIR", $kenshilibDir, "User")
[Environment]::SetEnvironmentVariable("BOOST_INCLUDE_PATH", $boostInclude, "User")
[Environment]::SetEnvironmentVariable("BOOST_ROOT", $boostInclude, "User")
[Environment]::SetEnvironmentVariable("KENSHILIB_DEPS_DIR", (Join-Path $RepoRoot $depsDir), "User")
Write-Ok "KENSHILIB_DIR      = $kenshilibDir"
Write-Ok "BOOST_INCLUDE_PATH = $boostInclude"
Write-Warn "these apply to NEW shells/processes only - restart your terminal before building"

# ---------------------------------------------------------------------------
Write-Step "VC++ 2010 (v100) compiler"

$clPath = "C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\bin\amd64\cl.exe"
if (Test-Path $clPath) {
    Write-Ok "found at $clPath"
} else {
    Write-Bad "not found. This needs a manual, interactive install (Windows SDK 7.1 + KB2519277 compiler update) - see docs/BUILD_SETUP.md Part A."
}

# ---------------------------------------------------------------------------
Write-Step "MSBuild + C++ build scaffold"

function Find-MSBuild {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $found = & $vswhere -latest -requires Microsoft.Component.MSBuild -find "MSBuild\**\Bin\MSBuild.exe" 2>$null
        if ($found) { return $found | Select-Object -First 1 }
    }
    # vswhere can miss a complete, working instance when Build Tools was
    # installed to a non-default drive root - fall back to a direct scan.
    $candidates = @(
        "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
        "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
        "C:\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
        "D:\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
        "D:\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
        "C:\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    return $null
}

function Test-VCTargetsScaffold($msbuildPath) {
    # $(VCTargetsPath) default props only ship with a C++ workload, not the
    # bare MSBuild engine. Look for it next to whichever MSBuild.exe we found.
    $root = Split-Path (Split-Path (Split-Path $msbuildPath))  # .../MSBuild
    $vcDir = Join-Path $root "Microsoft\VC"
    return (Test-Path $vcDir) -and ((Get-ChildItem $vcDir -Directory -ErrorAction SilentlyContinue).Count -gt 0)
}

$msbuild = Find-MSBuild
$needsInstall = $false
if (-not $msbuild) {
    Write-Bad "MSBuild.exe not found anywhere"
    $needsInstall = $true
} elseif (-not (Test-VCTargetsScaffold $msbuild)) {
    Write-Ok "MSBuild found at $msbuild"
    Write-Bad "C++ build scaffold (`$(VCTargetsPath)) missing - needs the VCTools workload"
    $needsInstall = $true
} else {
    Write-Ok "MSBuild found at $msbuild, with C++ scaffold"
}

if ($needsInstall -and -not $SkipBuildToolsInstall) {
    $doInstall = Confirm-Action "Install/modify VS2022 Build Tools with the Desktop C++ workload now? (a few GB download)"
    if ($doInstall) {
        $bootstrapper = Join-Path $env:TEMP "vs_buildtools.exe"
        Write-Host "  Downloading VS2022 Build Tools bootstrapper..."
        Invoke-WebRequest -Uri "https://aka.ms/vs/17/release/vs_buildtools.exe" -OutFile $bootstrapper

        $installPath = "C:\BuildTools"
        $verb = if (Test-Path "$installPath\Common7") { "modify" } else { "install" }
        Write-Host "  Running Build Tools installer ($verb, this can take a while)..."
        $proc = Start-Process -FilePath $bootstrapper -ArgumentList @(
            $verb, "--installPath", $installPath,
            "--add", "Microsoft.VisualStudio.Workload.VCTools",
            "--includeRecommended", "--quiet", "--wait", "--norestart"
        ) -Wait -PassThru
        if ($proc.ExitCode -eq 0) {
            Write-Ok "Build Tools installed/updated at $installPath"
        } else {
            Write-Warn "installer exited with code $($proc.ExitCode) - check %TEMP%\dd_setup_*_errors.log"
        }
    } else {
        Write-Warn "skipped - install VS2022 Build Tools (Desktop development with C++ workload) manually"
    }
} elseif ($needsInstall) {
    Write-Warn "skipped by -SkipBuildToolsInstall"
}

# ---------------------------------------------------------------------------
Write-Step "Summary"

$clOk = Test-Path $clPath
$msbuildOk = $null -ne (Find-MSBuild)
Write-Host ("  ENet:              ready")
Write-Host ("  KenshiLib_deps:    pinned to $KenshiLibPin, patched")
Write-Host ("  v100 compiler:     " + $(if ($clOk) { "ready" } else { "MISSING - see docs/BUILD_SETUP.md Part A" }))
Write-Host ("  MSBuild + C++:     " + $(if ($msbuildOk) { "ready" } else { "MISSING" }))

if ($clOk -and $msbuildOk) {
    Write-Host "`nAll set. Restart your terminal (for the new env vars), then:" -ForegroundColor Green
    Write-Host "  cmd //c scripts\build_plugin.cmd Release`n"
} else {
    Write-Host "`nNot ready yet - resolve the MISSING items above, then re-run this script.`n" -ForegroundColor Yellow
}
