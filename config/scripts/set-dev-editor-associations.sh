#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
. "$SCRIPT_DIR/bin/dev-editor-config.sh"

BUNDLE_ID="${DEV_EDITOR_BUNDLE_ID:-dev.editorbridge.deveditor}"
UTI_FILE="${DEV_EDITOR_ASSOCIATION_UTIS_FILE:-}"
EXTENSION_FILE="${DEV_EDITOR_ASSOCIATION_EXTENSIONS_FILE:-}"

if ! command -v duti >/dev/null 2>&1; then
  echo "duti is required to set macOS file associations" >&2
  exit 1
fi

# Prefer the generated list produced by `editor-bridge-apply`.
if [ -z "$UTI_FILE" ] || [ ! -f "$UTI_FILE" ]; then
  UTI_FILE="$(mktemp "${TMPDIR:-/tmp}/editor-bridge-utis.XXXXXX")"
  trap 'rm -f "$UTI_FILE"' EXIT
  cat >"$UTI_FILE" <<'EOF'
public.source-code
public.script
public.shell-script
public.json
public.xml
com.netscape.javascript-source
net.daringfireball.markdown
EOF
fi

successes=0
failures=0

apply_mapping() {
  local value="$1"
  if duti -s "$BUNDLE_ID" "$value" viewer >/dev/null 2>&1; then
    successes=$((successes + 1))
    return 0
  fi

  failures=$((failures + 1))
  printf 'warning: failed to set %s as handler for %s\n' "$BUNDLE_ID" "$value" >&2
  return 1
}

if [ -n "$EXTENSION_FILE" ] && [ -f "$EXTENSION_FILE" ]; then
  while IFS= read -r extension; do
    [ -n "$extension" ] || continue
    apply_mapping ".$extension" || true
  done <"$EXTENSION_FILE"
fi

while IFS= read -r uti; do
  [ -n "$uti" ] || continue
  apply_mapping "$uti" || true
done <"$UTI_FILE"

if [ "$successes" -eq 0 ] && [ "$failures" -gt 0 ]; then
  echo "failed: no file associations were updated" >&2
  exit 1
fi
