@echo off
REM Build dist\tunneltest.exe - proves the ENet protocol survives the
REM socket-hook tunnel (patch 0002) under Steam P2P's constraints (1200-byte
REM datagram cap + loss) in one process, no game / no Steam (src\tunneltest).
REM Compiles the SAME vendored+patched ENet sources as the plugin, with the
REM same v100 (VC++ 2010) x64 toolchain, so the seam under test is the seam
REM that ships.
setlocal

set "REPO=%~dp0.."
pushd "%REPO%" >nul
set "REPO=%CD%"
popd >nul

set "VS10=C:\Program Files (x86)\Microsoft Visual Studio 10.0"
set "VC=%VS10%\VC"

REM Windows SDK 7.1's installer lets the user pick any drive; the official
REM default is "C:\Program Files\Microsoft SDKs\Windows\v7.1" but it's also
REM commonly found directly off another drive's root (e.g. "D:\Microsoft
REM SDKs\Windows\v7.1") when that drive was chosen at install time. Try the
REM default first, then fall back to scanning other drive roots (matches
REM build_plugin.cmd's SDK detection).
set "SDK=C:\Program Files\Microsoft SDKs\Windows\v7.1"
if not exist "%SDK%\Include\Windows.h" (
  for %%D in (C D E F) do (
    if exist "%%D:\Microsoft SDKs\Windows\v7.1\Include\Windows.h" set "SDK=%%D:\Microsoft SDKs\Windows\v7.1"
  )
)

set "PATH=%VC%\bin\amd64;%VC%\bin;%VS10%\Common7\IDE;%SDK%\Bin\x64;%SDK%\Bin;%PATH%"
set "INCLUDE=%VC%\include;%SDK%\Include;%REPO%\third_party\vc10_compat;%REPO%\third_party\enet\enet\include"
set "LIB=%VC%\lib\amd64;%SDK%\Lib\x64"

if not exist "%REPO%\dist" mkdir "%REPO%\dist"
if not exist "%REPO%\build\tunneltest" mkdir "%REPO%\build\tunneltest"

set "ENET=%REPO%\third_party\enet\enet"

REM Fail fast with a clear message instead of a wall of buried C1083 errors
REM (third_party/enet/enet is git-ignored, so a fresh clone or a wiped
REM third_party leaves cl.exe unable to find enet.h deep into the build).
if not exist "%ENET%\include\enet\enet.h" (
    echo ERROR: ENet source missing at %ENET%
    echo   Run: powershell -ExecutionPolicy Bypass -File scripts\setup_toolchain.ps1
    exit /b 1
)

echo === Building tunneltest.exe (Release^|x64, v100) ===
cl.exe /nologo /O2 /EHsc /W3 /DWIN32 ^
    /Fo"%REPO%\build\tunneltest\\" ^
    /Fe"%REPO%\dist\tunneltest.exe" ^
    "%REPO%\src\tunneltest\main.cpp" ^
    "%ENET%\callbacks.c" "%ENET%\compress.c" "%ENET%\host.c" "%ENET%\list.c" ^
    "%ENET%\packet.c" "%ENET%\peer.c" "%ENET%\protocol.c" "%ENET%\win32.c" ^
    ws2_32.lib winmm.lib
if errorlevel 1 (
    echo tunneltest build FAILED
    exit /b 1
)
echo tunneltest built: %REPO%\dist\tunneltest.exe
exit /b 0
