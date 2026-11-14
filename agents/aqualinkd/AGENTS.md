# AqualinkD Workspace Agent Context

Context for [`~/git/dotfiles/vscode/workspaces/AqualinkD.code-workspace`](../../../vscode/workspaces/AqualinkD.code-workspace).

## Included Projects (multi-root)

- `~/git/AqualinkD` - upstream core checkout
- `~/git/aqualinkd-validator` - validator package (`ballle98/aqualinkd-validator`)
- `~/git/AqualinkD.wiki`, `~/git/aqualinkd-validator.wiki` - cloned wikis
- `~/git/dotfiles` - this repo (scripts, workspaces, agent context)
- `~/mnt/pi-tmp` - rclone mount of `pi:/tmp` from `systemd/user/rclone-pi-tmp.service`;
  that unit is **not installed on this host** and `~/mnt` does not exist, so this root
  folder is dead until you install and start it
- `agents/aqualinkd` - this folder (durable context plus handoffs)

## Host Environment (verified 2026-11-13)

- Ubuntu 26.04.1 LTS (Resolute, x86_64), bash, Python 3.14.4, Docker 29.8.2
- Passwordless `sudo` confirmed; `jq` is **not** installed, use `python3` instead
- Present: `wine 11.0` (`winehq-stable`), `gcc-mingw-w64-i686`, `socat`, `xvfb`, `xauth`,
  `rsync`
- Dotfiles helpers: `~/git/dotfiles/bin/run-aqualinkd-*`, `sync-pi-sysroot`,
  `deploy-aqualinkd-pi`

## AqualinkD (core)

- Native build: `make -C ~/git/AqualinkD -j$(nproc) amd64` -> `release/aqualinkd-amd64`
- ARM64 build needs the synced Pi sysroot (see `bin/sync-pi-sysroot`) plus explicit
  `CC_ARM64`/`LIBS`; the workspace `make arm64` task carries the exact flags
- Web assets live in `~/git/AqualinkD/web/`

## aqualinkd-validator

- Python package; the venv already exists at `~/git/aqualinkd-validator/.venv`
  (rebuild with `python3 -m venv .venv && .venv/bin/pip install -e .`)
- CLI subcommands: `doctor`, `compare`, `validate-testcase`, `run-panel-free`, `run`
- `doctor` reports capabilities without touching hardware - cheapest first check
- Container flow: `sudo docker build --tag aqualinkd-validator:dev .` then run it;
  `bin/run-aqualinkd-validator-pi` builds and runs the image on the Pi
- Site profiles: `examples/aqualinkd-validator.yaml`, and
  `examples/aqualinkd-validator-wsl.yaml` for the Wine/WSL path; Power Center model is
  `B29231 (16 Combo)`

## Jandy Power Center / Wine (Ubuntu 26.04)

Verified host state - do not reuse 24.04 recipes from the validator wiki.

- WineHQ repo is configured: `/etc/apt/sources.list.d/winehq-resolute.sources`
  (`Suites: resolute`, `Architectures: amd64`) with the key at
  `/etc/apt/keyrings/winehq-archive.key`. **The key must be dearmored**: WineHQ serves
  it ASCII-armored (3212 B) and apt 3.2 rejects it with "unsupported filetype" /
  `NO_PUBKEY 76F1A20FF987672F`. `gpg --dearmor` to a 2313 B keyring; renaming to `.asc`
  also works but then `Signed-By` in the upstream `.sources` must be edited too.
- Installed: `winehq-stable 11.0.0.0~resolute-1`, payload `/opt/wine-stable`;
  `wine --version` reports `wine-11.0`.
- **No i386**: `dpkg --print-foreign-architectures` is empty. Never add i386 or install
  `wine32:i386`; WineHQ for `resolute` is amd64-only and Wine 11 uses WoW64.
- A single `wine` binary exists; there is no `wine64`.
- Prefix `~/.wine-aqualink` exists and is `#arch=win64` (WoW64), created without
  `WINEARCH=win32`. The validator never sets `WINEARCH`; it only exports `WINEPREFIX`
  (`src/aqualinkd_validator/adapters/power_center.py`, `power_center_session.py`).
- Simulator installed at **`drive_c/Program Files (x86)/Alwin32`** - the Wise installer
  is 32-bit, so WoW64 redirects it; `Pwrcntr.exe` and `Simio.exe` are both there. The
  validator used to hard-code `Program Files/Alwin32`; issue #22 / PR #23 probe `(x86)`
  first, then `Program Files` (PR still open on `fix/power-center-wow64-install-path`).
- Silent install (verified): `wine ~/Downloads/AquaLink_RS_Simulator.EXE /s` completes in
  ~7 s with no prompts and registers `btn32a20.ocx`. It still needs a display - with
  `DISPLAY` unset it exits **0 and installs nothing**; use
  `xvfb-run -a wine ... /s` on a headless host.
- The helper is already built: `contrib/power-center-helper/build/pwrcntr-control.exe`
  (plus `.sha256`); rebuild with `make` in that directory.
- Runner: `bin/run-aqualinkd-validator-power-center <suite> [aqualinkd_dir]
  [validator_dir] [wine_prefix]`, suites `pda-power-center-fast|pda-power-center-full|
  rs-fast|rs-full`. It requires `awk readlink socat sudo wine`, rewrites
  `~/.wine-aqualink/dosdevices/com3`, renders configs to `/tmp/aqualinkd-wsl.conf` and
  `/tmp/aqualinkd-validator.yaml`, runs the validator through `sudo -n` (as root), and
  restores the original COM3 link in its EXIT trap.
- The runner runs `wineserver -k` first (`e3f5daa`). Without it, `wine reg add` can
  leave a wineserver that is already shutting down; the session then loses its window
  (`X Error ... BadWindow ... X_UnmapWindow`, Pwrcntr exits 1).
- `pda-power-center-fast` passes on this host: `result: passed (scenario_completed)`,
  41.8 s, artifact `artifacts/20261113T045311Z-vscode-pda-power-center-fast`.
- `gh` is authenticated as `ballle98` (scopes include `repo`); both clones use the `gh`
  credential helper. The validator repo's `AGENTS.md` requires `Assisted-by:` and
  `Signed-off-by:` trailers.

## Gotchas / Tips

- The validator wiki (`Jandy-Windows-Panel-Simulator.md`) now covers both the 24.04
  i386 path and the 26.04/resolute WoW64 path (wiki commit `e116c79`, issue #24).
- Cross/remote builds: `bin/sync-pi-sysroot [pi@host] [sysroot]` recreates
  `~/sysroots/pi-arm64` with `rsync --delete`, then use the workspace `make arm64` task.
- Deploy before debug: `deploy-aqualinkd-pi` stages `/tmp/aqualinkd` on the Pi, and
  `run-aqualinkd-debug-pi` runs that staged binary, refusing a second copy.
- Handoffs: `handoffs/YYYY-MM-DD-HHMM-<topic>.md` (see `handoffs/README.md`); record
  branches, commands run, failures, and next steps, then archive or delete once folded in.
- Don't commit secrets or keys. Follow `~/git/dotfiles/AGENTS.md`.

## Quick Links

- Handoff (Wine setup): `handoffs/HANDOFF-wine11-ubuntu2604-setup.md`
- Validator README / CONTRIBUTING: `~/git/aqualinkd-validator/{README,CONTRIBUTING}.md`
- Wikis (local): `~/git/aqualinkd-validator.wiki/`, `~/git/AqualinkD.wiki/`
- Workspace tasks: `~/git/dotfiles/vscode/workspaces/AqualinkD.code-workspace`
