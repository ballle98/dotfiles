# Default editor. `fresh` is the preferred terminal editor; fall back to vim or
# vi so the variable is still usable on a bare host.

if command -v fresh >/dev/null 2>&1; then
  EDITOR=fresh
elif command -v vim >/dev/null 2>&1; then
  EDITOR=vim
else
  EDITOR=vi
fi
export EDITOR

# VS Code terminals are the one place a GUI editor makes sense.
if [ "${TERM_PROGRAM:-}" = vscode ]; then
  export VISUAL="code --wait"
fi
