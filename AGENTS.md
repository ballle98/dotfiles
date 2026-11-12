# Repository Guidelines

Personal dotfiles, not an application: no build system, no CI, no tests. `README.md`
covers layout and the shell install; the rest of the durable context is under `agents/`.

## Layout
- `bin/` - standalone bash/python tools. Most operate on sibling checkouts under `~/git/`
  and a Pi reachable as `pi@pi`; nothing here builds the repo.
- `shell/bashrc` - the real interactive bash config, symlinked to `~/.bashrc`; it
  resolves `$DOTFILES_DIR` from that symlink so the checkout can live anywhere. Tracked
  customizations are ordered fragments in `shell/bashrc.d/` (`10-`…`70-`). Host-specific
  or secret settings go in gitignored `99-local.sh`, copied from `99-local.sh.example`;
  never put them in a tracked fragment.
- `vscode/workspaces/*.code-workspace` - JSONC: comments **and trailing commas**, so
  `json.loads` fails. They reference outside repos by relative path (`../../../AqualinkD`),
  so they only resolve when those checkouts are siblings under `~/git/`.
- `agents/<workspace>/AGENTS.md` + `agents/<workspace>/handoffs/` - durable environment
  context and dated handoffs (`YYYY-MM-DD-HHMM-<topic>.md`). Read the matching one first;
  archive or delete a handoff once folded into `AGENTS.md`. `agents/` is only partly
  tracked (handoff files and workspace `AGENTS.md` yes, README indexes and `.opencode/`
  no) - do not `git add -A` it by accident.
- `systemd/user/rclone-pi-tmp.service` - user unit (not installed on this host;
  `~/mnt/pi-tmp` does not exist) that mounts `pi:/tmp`. `AqualinkD.code-workspace` still
  lists that missing path as a root folder.
- `docx2md` / `pptx2md` need `pandoc` (pptx also goes through LibreOffice), write the
  `.md` next to the input, and drop extracted media into `./images`.

## Verification (there is no test suite)
- `bash -n` the bash tools in `bin/`: `backup-since`, `deploy-aqualinkd-pi`, `docx2md`,
  `gnucash`, `pptx2md`, `restore-since`, `run-aqualinkd-*`, `sync-pi-sysroot`.
- `bash -n shell/bashrc shell/bashrc.d/*.sh`
- `python3 -m py_compile bin/tether` then remove `bin/__pycache__/`
- Everything else is manual and hits real hardware, a remote host, or a Wine prefix -
  confirm the target before running anything.

## Scripts that leave this machine
Positional arguments are a public interface: the workspace tasks call these scripts in
exactly this order, so never reorder or rename parameters.

- `deploy-aqualinkd-pi [pi@host] [project_dir]` - copies `release/aqualinkd-arm64`,
  `release/aqualinkd.conf`, and `web/` to `/tmp/aqualinkd`, `/tmp/aqualinkd.conf`,
  `/tmp/aqualinkd-web`. Requires an arm64 build first.
- `run-aqualinkd-debug-pi [pi@host]` - runs the already-staged
  `/tmp/aqualinkd -d -v -c /tmp/aqualinkd.conf`; exits 2 if that process is running.
  Deploy first; it uploads nothing itself.
- `run-aqualinkd-validator-pi [pi@host] [aqualinkd_dir] [validator_dir] [suite] [devices] [profile]`
  - rsyncs the validator to the Pi, `sudo docker build` there, runs live suites
  (default `pda-live-fast`); needs ssh, rsync, docker.
- `run-aqualinkd-validator-power-center [suite] [aqualinkd_dir] [validator_dir] [wine_prefix]`
  - local Wine run; needs `wine`, `socat`, passwordless `sudo -n`,
  `contrib/power-center-helper/build/pwrcntr-control.exe`, and the Jandy simulator
  installed in `~/.wine-aqualink`. It re-links `com3` inside the prefix and `chown`s
  `artifacts/`.
- `sync-pi-sysroot [pi@host] [sysroot]` - recreates `~/sysroots/pi-arm64` using
  `rsync -aH --delete`.
- `tether` (python3, standard library only) - rewrites the `Host phone` block in
  `~/.ssh/config` and prunes matching `known_hosts` entries.

## Workspace tasks
- `AqualinkD.code-workspace` chains tasks with `dependsOn` + `dependsOrder: sequence`
  (e.g. `make amd64` before any power-center suite). `make arm64` needs the synced
  sysroot and passes explicit `CC_ARM64`/`LIBS`.
- When editing a script, grep the workspace file for its name: tasks pass the same
  positional args and break silently if the order changes.

## Style
- Bash: shebang, two-space indent, quoted expansions, `set -euo pipefail` on every
  multi-step script (`docx2md` and `pptx2md` are the exceptions; `tether` is Python).
  Keep `bin/` files executable.
- Python: four spaces, `snake_case`, standard library only.

## Commits
- Lowercase imperative subject; body explains behavior or environment assumptions.
- Required trailers:
  `Assisted-by: <Tool>:<Model>` and `Signed-off-by: <Name> <email>`

## Safety
- No secrets, keys, or machine credentials in this repo.
- Back up `~/.ssh/config` and `~/.ssh/known_hosts` before testing `tether`.
- `rsync --delete`, `sudo`, `docker`, and `rm -rf` all appear in `bin/`; confirm host,
  destination, and mount before executing.
