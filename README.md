# dotfiles

Personal configuration for my Linux hosts.

## Layout

| Path | Purpose |
| --- | --- |
| `bin/` | Standalone scripts: AqualinkD deploy/validate, Pi sysroot sync, `tether`, doc converters |
| `shell/bashrc` | Interactive bash configuration, symlinked to `~/.bashrc` |
| `shell/bashrc.d/` | Ordered fragments sourced by `shell/bashrc` |
| `systemd/user/` | User units (not installed on every host) |
| `vscode/workspaces/` | VS Code workspaces and tasks (JSONC) |
| `agents/` | Durable workspace context and dated handoffs |

## Install

Run from the repo checkout:

```bash
[ -e ~/.bashrc.pre-dotfiles ] || cp ~/.bashrc ~/.bashrc.pre-dotfiles
ln -sf "$PWD/shell/bashrc" ~/.bashrc
```

The guarded `cp` keeps an existing backup, so re-running the install cannot
overwrite the original file with the repo copy. `ln -sf` replaces the regular
`~/.bashrc` with the symlink; a plain `ln -s` fails because the file still
exists.

`shell/bashrc` locates the repo by resolving the `~/.bashrc` symlink, so the
checkout may live anywhere. When `~/.bashrc` is a regular file it falls back to
`$HOME/git/dotfiles`.

## Local overrides

Fragments run in filename order, so `10-` through `70-` are tracked settings and
`99-local.sh` is the untracked escape hatch. Create it from the repo root:

```bash
cp shell/bashrc.d/99-local.sh.example shell/bashrc.d/99-local.sh
```

Personal aliases belong there too: the stock `~/.bash_aliases` hook is not
sourced by `shell/bashrc`.

## Verify

There is no test suite; shell files are syntax-checked and then exercised by
hand.

```bash
bash -n shell/bashrc shell/bashrc.d/*.sh
env -i HOME="$HOME" TERM=xterm-256color bash -i -c 'echo "$PATH"; echo "$EDITOR"; alias ll'
```

See `AGENTS.md` for the scripts that touch remote hosts and their required
arguments.
