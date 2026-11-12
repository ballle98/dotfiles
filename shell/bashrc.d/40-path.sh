# PATH additions. path_prepend keeps each directory at most once, so repeated
# sourcing (and .profile's own ~/.local/bin entry) cannot grow duplicates.

path_prepend() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1:$PATH" ;;
  esac
}

path_prepend "$HOME/.local/bin"

if [ -d "$HOME/.grok/bin" ]; then
  path_prepend "$HOME/.grok/bin"
fi

if [ -d "$HOME/.opencode/bin" ]; then
  path_prepend "$HOME/.opencode/bin"
fi

export PATH
