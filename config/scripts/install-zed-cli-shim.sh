#!/usr/bin/env bash
set -euo pipefail

SOURCE="${1:-$HOME/.local/bin/zed}"
TARGET="${ZED_CLI_SHIM_TARGET:-}"

pick_target() {
  local candidate
  for candidate in /usr/local/bin/zed /opt/homebrew/bin/zed "$HOME/.local/bin/zed"; do
    [ "$candidate" = "$SOURCE" ] && continue
    if [ -L "$candidate" ] || [ ! -e "$candidate" ]; then
      if [ -w "$(dirname "$candidate")" ]; then
        printf '%s\n' "$candidate"
        return 0
      fi
    fi
  done
  return 1
}

if [ ! -x "$SOURCE" ]; then
  echo "zed shim source not found: $SOURCE" >&2
  exit 1
fi

if [ -z "$TARGET" ]; then
  TARGET="$(pick_target || true)"
fi

if [ -z "$TARGET" ]; then
  echo "skipped: no writable target found for zed shim" >&2
  exit 0
fi

if [ -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
  echo "skipped: $TARGET already exists and is not a symlink" >&2
  exit 0
fi

mkdir -p "$(dirname "$TARGET")"
ln -sfn "$SOURCE" "$TARGET"
echo "$TARGET"
