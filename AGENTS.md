# Repository Guidelines

## Project Structure & Module Organization

This repository stores personal command-line utilities and editor configuration rather than a single application. Executable tools live in `bin/`: `gnucash` launches the Flatpak application, `tether` detects an Android tether gateway and updates SSH files, and `sync-pi-sysroot.sh` builds a local Raspberry Pi ARM64 sysroot. VS Code multi-root workspaces and their build/deploy tasks live under `vscode/workspaces/`. Keep host- or project-specific automation beside similar files; do not commit generated sysroots, credentials, logs, or build output.

## Build, Test, and Development Commands

There is no repository-wide build system. Use lightweight checks from the repository root:

- `bash -n bin/gnucash bin/sync-pi-sysroot.sh` checks shell syntax without executing remote or destructive operations.
- `python3 -m py_compile bin/tether` checks Python syntax (remove any generated `bin/__pycache__/` before committing).
- `bin/sync-pi-sysroot.sh pi@pi ~/sysroots/pi-arm64` refreshes a Pi sysroot; it requires SSH and `rsync` and recreates the destination.
- Open a file in `vscode/workspaces/` with VS Code to run its named Maven or Make tasks against adjacent project checkouts.

## Coding Style & Naming Conventions

For Bash, use an explicit shebang, two-space indentation, quoted expansions, and `set -euo pipefail` for substantial scripts. Use uppercase names for constants and environment-derived settings. Python uses four spaces, `snake_case` functions and variables, and standard-library modules where practical. Preserve executable permissions on files in `bin/`. Workspace files are JSON with comments; retain the existing indentation style of the file being edited and use descriptive task labels such as `AqualinkD: make arm64`.

## Testing Guidelines

No automated test suite or coverage threshold is configured. Run the syntax checks above and manually exercise only the platform-specific path you changed. For remote tasks, first verify the target host, destination, and prerequisites. Describe manual validation in the pull request, especially for SSH configuration changes, sysroot synchronization, deployment, or service control.

## Commit & Pull Request Guidelines

Recent history uses short, lowercase, imperative summaries, for example `add vscode workspace for AqualinkD`. Keep each commit focused and explain behavioral or environment assumptions in its body when needed. Pull requests should summarize affected scripts or workspaces, list validation performed, and identify required external paths, hosts, or tools. Include screenshots only when editor-visible workspace behavior changes.

## Safety & Configuration

Never embed secrets, private keys, or machine-specific credentials. Review commands using `rm -rf`, `--delete`, `sudo`, or SSH before running them. Back up `~/.ssh/config` and `known_hosts` before testing changes to `bin/tether`.
