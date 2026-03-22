#!/usr/bin/env bash

dev_editor_prepend_path() {
  local dir="$1"
  [ -n "$dir" ] || return 0
  [ -d "$dir" ] || return 0
  case ":${PATH:-}:" in
    *":$dir:"*) ;;
    *) PATH="$dir${PATH:+:$PATH}" ;;
  esac
}

dev_editor_bootstrap_path() {
  dev_editor_prepend_path "/bin"
  dev_editor_prepend_path "/usr/bin"
  dev_editor_prepend_path "/usr/local/bin"
  dev_editor_prepend_path "/opt/homebrew/bin"
  dev_editor_prepend_path "${PNPM_HOME:-$HOME/Library/pnpm}"
  dev_editor_prepend_path "$HOME/.local/bin"
  export PATH
}

dev_editor_bootstrap_path
