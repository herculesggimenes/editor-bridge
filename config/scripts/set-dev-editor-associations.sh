#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="${DEV_EDITOR_BUNDLE_ID:-dev.editorbridge.deveditor}"

if ! command -v duti >/dev/null 2>&1; then
  echo "duti is required to set macOS file associations" >&2
  exit 1
fi

# Broad text/code mappings plus custom UTIs for dev-specific dotfiles and TypeScript.
# `public.data` is included because hidden dotfiles such as `.bazelrc` resolve there on macOS.
for uti in \
  dev.editorbridge.dotfile \
  dev.editorbridge.typescript \
  public.data \
  public.plain-text \
  public.source-code \
  public.script \
  public.shell-script \
  public.unix-executable \
  public.json \
  public.python-script \
  com.netscape.javascript-source \
  net.daringfireball.markdown \
  public.mpeg-2-transport-stream; do
  duti -s "$BUNDLE_ID" "$uti" all
done
