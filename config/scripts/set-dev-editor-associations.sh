#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
. "$SCRIPT_DIR/bin/dev-editor-config.sh"

BUNDLE_ID="${DEV_EDITOR_BUNDLE_ID:-dev.editorbridge.deveditor}"
UTI_FILE="${DEV_EDITOR_ASSOCIATION_UTIS_FILE:-}"

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

while IFS= read -r uti; do
  [ -n "$uti" ] || continue
  duti -s "$BUNDLE_ID" "$uti" all
done <"$UTI_FILE"
