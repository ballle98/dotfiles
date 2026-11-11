# Handoff: Wine 10 setup on Ubuntu 26.04 for Jandy Power Center emulator

Created: 2026-10-25
Associated workspace: `~/git/dotfiles/vscode/workspaces/AqualinkD.code-workspace`

## Objective

Set up the developer validation environment for `aqualinkd-validator` Jandy Power
Center (Windows Panel Simulator) testing on Ubuntu 26.04 (Resolute Raccoon),
which requires Wine 10's WoW64 model instead of the 24.04-style `wine32:i386`
setup that Grok attempted in its prior session.

## Agreed Decisions and Constraints

- **Ubuntu 26.04 is amd64-only for WineHQ**: do not run `sudo dpkg --add-architecture i386`, do not install `wine32:i386`, `wine64` as separate packages; Wine 10 uses WoW64 to run 32-bit Windows apps inside a 64-bit prefix.
- **Use WineHQ's deb822 `.sources` file** (not the old `.list` + `.key` pattern) for the `resolute` suite. APT 3.2 on 26.04 rejects ASCII-armored keys stored under a `.key` name; the correct name is `.asc` at `/etc/apt/keyrings/winehq-archive.asc`.
- **Single `wine` binary** handles both 32-bit and 64-bit executables; no separate `wine64`.
- **Install WineHQ stable** (`--install-recommends winehq-stable`), not Ubuntu archive's `wine 10.0~repack-12ubuntu1`.
- **Keep `WINEPREFIX` handling in mind**: old `WINEARCH=win32` behavior under Wine 10 WoW64 may differ; validators/config referencing `power_center.wine_prefix` will need verification.
- Managed display/COM port bridging via Xvfb and socat was part of Grok's prior tooling and may still be relevant; verify validator docs before discarding.
- Dotfiles context lives in `~/git/dotfiles/agents/aqualinkd/AGENTS.md`; handoffs in `~/git/dotfiles/agents/aqualinkd/handoffs/`.

## Completed Work

- Verified sudo is passwordless for the current user in the Grok session.
- Ran `sudo dpkg --add-architecture i386` and `sudo apt-get update` (via Grok session) — **outdated step on 26.04**; if i386 was enabled, it may need to stay or be removed, but wasn't verified here.
- Ran `sudo apt-get install -y wine wine32:i386 wine64 socat xvfb xauth gcc-mingw-w64-i686 python3-venv python3-pip` (via Grok session, 24.04-style — needs correction/replacement for 26.04).
- Downloaded the Jandy AquaLink RS Simulator `.EXE` installer to `~/Downloads/AquaLink_RS_Simulator.EXE`.
- Built `~/git/AqualinkD/release/aqualinkd-amd64` with `make -C ~/git/AqualinkD -j$(nproc) amd64`.
- Created the `~/git/dotfiles/agents/{aqualinkd/handoffs}` directory structure for the AqualinkD workspace:
  - `~/git/dotfiles/agents/README.md`
  - `~/git/dotfiles/agents/aqualinkd/AGENTS.md`
  - `~/git/dotfiles/agents/aqualinkd/handoffs/README.md`

## Unfinished Work

- WineHQ repository for `resolute` has **not** been added on this host; no WineHQ key/repo file in `/etc/apt/keyrings/` or `/etc/apt/sources.list.d/` has been verified in this session.
- WineHQ stable (`winehq-stable`) has **not** been installed via the correct 26.04 procedure.
- The 24.04-style `wine32:i386` install performed earlier may be in a broken or inconsistent state on 26.04 and should be audited/cleaned.
- Wine prefix for Power Center emulator (`~/.wine-aqualink` in Grok's earlier work) has **not** been created under the correct WoW64 model.
- Power Center helper (`pwrcntr-control.exe`) status/materials not verified in this session (binary, SHA256, source presence).
- Site YAML wiring for `power_center.helper`, `power_center.wine_prefix`, model, COM port, etc., not yet reconciled with the new Wine layout.
- 32-bit Wine prefix initialization path in `aqualinkd-validator` code has not been audited for Wine 10/WoW64 differences.

## Exact Output Paths

- Workspace agent context: `/home/lee_ballard/git/dotfiles/agents/aqualinkd/AGENTS.md`
- Workspace agent index: `/home/lee_ballard/git/dotfiles/agents/README.md`
- Handoff template: `/home/lee_ballard/git/dotfiles/agents/aqualinkd/handoffs/README.md`
- Handoff file: `/home/lee_ballard/git/dotfiles/agents/aqualinkd/handoffs/HANDOFF-wine10-ubuntu2604-setup.md`
- Expected Jandy installer: `/home/lee_ballard/Downloads/AquaLink_RS_Simulator.EXE` (validity not re-verified in this session)
- Expected built AqualinkD binary: `/home/lee_ballard/git/AqualinkD/release/aqualinkd-amd64` (validity not re-verified in this session)
- Expected WineHQ key: `/etc/apt/keyrings/winehq-archive.asc`
- Expected WineHQ repo file: `/etc/apt/sources.list.d/winehq-resolute.sources`
- Expected Wine prefix created as: `~/.wine-aqualink` (per Grok session; verify actual config)

## Approved Source Links

- Wine install guide (Ubuntu 26.04 / 24.04 / 22.04), ComputingForGeeks, Aug 2026 (reported as run-through-tested): https://computingforgeeks.com/install-wine-ubuntu-debian/
- GitHub wiki — Developer Validation Environment: https://github.com/ballle98/aqualinkd-validator/wiki/Developer-Validation-Environment
- GitHub wiki — Jandy Windows Panel Simulator: https://github.com/ballle98/aqualinkd-validator/wiki/Jandy-Windows-Panel-Simulator

## Next Three Steps

1. **Audit current Wine state on 26.04** — check whether the 24.04-style `wine`, `wine32:i386`, `wine64` install from the Grok session left conflicts on this host. Decide whether to purge and start clean with WineHQ stable, and whether i386 architecture should be removed from `dpkg --print-foreign-architectures`.
2. **Add the WineHQ `resolute` repository and install WineHQ stable** — follow the 26.04 procedure using `winehq-archive.asc` and `winehq-resolute.sources`; verify `wine --version` reports the current stable (expected ~11.0).
3. **Re-initialize the Wine prefix under WoW64** — create `~/.wine-aqualink` (or whatever `power_center.wine_prefix` references) without the old `WINEARCH=win32` flag, then verify that the installer and `pwrcntr-control.exe` both run correctly under it before wiring into `aqualinkd-validator`.

## Non-Secret Setup Requirements

- Sudo (passwordless) for apt/dpkg operations and for creating `/etc/apt/keyrings/`, `/etc/apt/sources.list.d/` entries.
- Network access to `dl.winehq.org` (for key/repo) and `cdn.fluidrausa.com` (for the Jandy installer download).
- Disk space for WineHQ install (~331 packages, per guide).
- `gcc-mingw-w64-i686` available in the archive — already attempted by Grok; verify it's still present or reinstall.
- `socat`, `xvfb`, `xauth` packages for managed display/COM port support (per validator requirements).
- A local venv for `aqualinkd-validator` with the package installed; see `pyproject.toml`.
- Proper MinGW compiler to build `pwrcntr-control.exe` helper in `~/git/aqualinkd-validator/contrib/power-center-helper/` and verify via `sha256sum --check pwrcntr-control.exe.sha256`.

## Things I Cannot Verify (in this session)

- Whether the Grok session actually completed the 24.04-style install successfully
- Whether the Jandy installer at `~/Downloads/AquaLink_RS_Simulator.EXE` is still valid and unmodified
- Whether the SHA256 of `~/git/AqualinkD/release/aqualinkd-amd64` matches the source
- Whether `pwrcntr-control.exe` is present and verified on this host (binary, hash, source)
- Whether the Ubuntu `wine 10.0~repack-12ubuntu1` distro package (if installed via Grok) can coexist or should be removed before WineHQ
- Whether APT 3.2 on 26.04 will accept the `.asc` key without additional verification steps
- Whether `aqualinkd-validator`'s Wine prefix initialization code is compatible with Wine 10's WoW64 model without code changes
- Whether the old `Xvfb` sticky-bit workaround noted in the validator docs still applies on this host/state
- Exactly which fmt of Power Center config (model, COM port) was wired per the Grok session
