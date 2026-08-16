---
name: manual-freeplay-session
description: >-
  Launch a manual free-play KenshiCoop session with host + join as plain
  windowed clients so one person can play both. Boots both clients to the
  title screen (no auto-load, no auto-connect); the user loads a save and
  goes online by hand via the F2 panel. Covers the exact manual_session.ps1
  -TitleScreen invocation, the default window size/placement behavior, and
  how to end the session. Use when the user asks to start a manual/free
  test, play both clients, do a hands-on side-by-side co-op session, or
  eyeball the latest mod build in game.
disable-model-invocation: true
---

# Manual Free-Play Session (title screen, windowed)

A "manual free test" = both clients (host + join) launched on this one machine,
left running with NO self-exit and NO scenario, so the user drives both
characters and eyeballs sync.

`-TitleScreen` boots BOTH clients to the Kenshi main menu with no auto-load and
no auto-connect. The user then loads a save and goes ONLINE via F2 by hand - the
real remote-play flow, with full control over which save and connection role.

`scripts/manual_session.ps1` defaults to plain windowed clients, sized
`WindowW x WindowH` (1080x720 by default) via `set_video_mode.ps1`, with NO
automatic positioning - the user places/moves them (this machine's real
displays are two ~1920px-wide screens, not one wide ultrawide panel; 1080x720
fits comfortably on either with room to move it). Pass `-Tile` to opt into
`scripts/arrange_windows.ps1`'s host-left/join-right auto-positioning on one
monitor instead - **do not use the default `-WindowW` with it**, since two
1080-wide windows side-by-side won't fit one ~1920px monitor; shrink
`-WindowW` to roughly half the target monitor's width first.

Do NOT reach for a hardcoded "ultrawide" size/layout - there isn't one on this
machine. If a past session's notes or an old default suggest one, that's stale;
trust the current `-WindowW`/`-WindowH` defaults in `manual_session.ps1`
instead (`kenshi.cfg` lives outside the repo, so there's no git history to
recover a "before" value from if a script overwrites it - see the
`dont-run-automated-tests-against-manual-install-pair` memory for the usual
way that happens).

## Launch command

```
powershell -ExecutionPolicy Bypass -File scripts/manual_session.ps1 -TitleScreen
```

This builds the latest DLL, deploys it to both installs, sizes the two windows,
launches host then join to the main menu, and returns immediately (windows
stay up until closed).

## In-game connect (by hand, after launch)
1. Load the SAME save on both clients (Continue / Load). NPC sync is
   resolve-by-hand, so both MUST be on identical saves.
2. On each window press F2 -> set Connection ONLINE: host role on one client,
   join role on the other. UDP loopback is preset.
3. Free-play: each window drives its own character; watch it render/follow on
   the other.

Do co-op free play on a DEBUG save (`together`, `separate`, `zoom`, or a
throwaway), NEVER a validation/fixture save (`sync`, `squad1`, `duel1`,
fixtures): on connect the host `armConnectPush()` bakes the live world over the
loaded save and rots the fixture. See the `coop-save-orchestration` skill.

## Common variations
- Reuse the current build (skip the ~minutes-long compile): add `-SkipBuild`.
- Colored authority markers on the join (green DRV / red HID / yellow LOC):
  add `-DebugMarkers`.
- Custom window size: `-WindowW <n> -WindowH <n>`.
- Leave `kenshi.cfg` Video Mode untouched entirely: add `-NoResize`.
- Auto-position host-left/join-right on one monitor: add `-Tile` (shrink
  `-WindowW` first - see above).
- Auto-load + auto-connect instead of the title screen: drop `-TitleScreen` and
  pass `-Save "together" -Inhabit` (host owns rank 0, join owns the rest).

`-Sync` is NOT needed on a single machine - both installs read the same
per-user save folder.

## Preconditions
- Windowed mode: `-Tile` requires `kenshi.cfg` Full Screen = No (the script
  sets the video mode; if a window won't tile, confirm it launched windowed).
- The join install exists (`scripts/setup_join_install.cmd` created
  `%USERPROFILE%\Kenshi-Join`).

## Ending the session
Close both game windows (no auto-exit, no screenshots).
