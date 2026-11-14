# Handoff: Wine 11 on Ubuntu 26.04 for the Jandy Power Center emulator

Original: 2026-10-25. Rewritten: 2026-11-13 after the wiki update and PR #23.
Workspace: `~/git/dotfiles/vscode/workspaces/AqualinkD.code-workspace`
Durable context: `../AGENTS.md`.

## Status

Functional. `pda-power-center-fast` passes on this host.

Verified 2026-11-13:

- WineHQ `resolute` repo is active (amd64 only); the key is dearmored at
  `/etc/apt/keyrings/winehq-archive.key` (2313 B).
- `winehq-stable 11.0.0.0~resolute-1` installed; `wine --version` reports `wine-11.0`.
- Foreign architectures are empty and there is a single `wine` binary.
- Prefix `~/.wine-aqualink` is `#arch=win64`; `dosdevices/com1..com8` map to `/dev/ttyS*`.
- Simulator installed in `drive_c/Program Files (x86)/Alwin32` (WoW64), with
  `Pwrcntr.exe` and `Simio.exe` present.
- `contrib/power-center-helper/build/pwrcntr-control.exe` is built and
  `sha256sum --check pwrcntr-control.exe.sha256` passes.
- Site wiring: `examples/aqualinkd-validator-wsl.yaml` is rendered to
  `/tmp/aqualinkd-validator.yaml` by `bin/run-aqualinkd-validator-power-center`
  (helper, prefix `~/.wine-aqualink`, model `B29231 (16 Combo)`, port `COM3`).
- Installer: `~/Downloads/AquaLink_RS_Simulator.EXE`, 7,871,862 bytes, sha256
  `9f6c6720189e1effbf03e505ef920ae4d8b5051ebb32e66672a57f9ffbfbfcaf`.
- `release/aqualinkd-amd64` present.

## Completed this session

- Issue #24 and wiki rewrite (`Jandy-Windows-Panel-Simulator.md`, wiki commit
  `e116c79`): 24.04 and 26.04 paths, dearmored key, `winehq-stable` 11, `#arch=win64`,
  both `Program Files` layouts, and the silent-install display caveat.
- `pda-power-center-fast` passes: `result: passed (scenario_completed)`, 41.8 s,
  artifact `artifacts/20261113T045311Z-vscode-pda-power-center-fast`.
- The runner kills a leftover `wineserver` before a run (`e3f5daa`), fixing the
  `BadWindow` / `X_UnmapWindow` failure after `wine reg add`.

## Open work

1. PR `ballle98/aqualinkd-validator#23` is still open (WoW64 path probe); merge when
   reviewed.

The dotfiles context is rebased onto `origin/main` and pushed; `agents/aqualinkd/AGENTS.md`
is now tracked and the Wine handoff is renamed.

## Superseded assumptions (do not reuse)

- `dpkg --add-architecture i386`, `wine32:i386`, `wine64` packages - 24.04-only and wrong
  on 26.04.
- Key path `.asc` - this host and the upstream `.sources` use `winehq-archive.key`.
- `WINEARCH=win32 wineboot` - unnecessary; the prefix is win64/WoW64.
- `winehq-devel 11.20` / `/opt/wine-devel` - replaced by `winehq-stable` 11.0.
- `drive_c/Program Files/Alwin32` - the WoW64 install is under `Program Files (x86)`.
- Xvfb sticky-bit workaround - applies only to WSLg's `/tmp/.X11-unix` mount, not here.

## Provenance

- The WineHQ install procedure originally came from
  https://computingforgeeks.com/install-wine-ubuntu-debian/ (Aug 2026 guide). Its `.asc`
  key advice did not match this host or the upstream `.sources` file; see above.
