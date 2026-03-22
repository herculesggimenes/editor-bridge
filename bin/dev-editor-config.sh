#!/usr/bin/env bash

editor_bridge_config_path() {
  if [ -n "${EDITOR_BRIDGE_CONFIG_PATH:-}" ]; then
    printf '%s\n' "$EDITOR_BRIDGE_CONFIG_PATH"
    return
  fi

  local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  printf '%s\n' "$config_home/editor-bridge/config.plist"
}

editor_bridge_print_value() {
  local key_path="$1"
  local config_path="${2:-$(editor_bridge_config_path)}"
  local buddy_path="${key_path//./:}"

  [ -f "$config_path" ] || return 1
  /usr/libexec/PlistBuddy -c "Print :$buddy_path" "$config_path" 2>/dev/null
}

editor_bridge_string_or_default() {
  local key_path="$1"
  local default_value="$2"
  local value=""

  if value="$(editor_bridge_print_value "$key_path")"; then
    printf '%s\n' "$value"
    return
  fi

  printf '%s\n' "$default_value"
}

editor_bridge_bool_or_default() {
  local key_path="$1"
  local default_value="$2"
  local value=""

  if value="$(editor_bridge_print_value "$key_path")"; then
    case "$value" in
      true|false|0|1|yes|no)
        printf '%s\n' "$value"
        return
        ;;
    esac
  fi

  printf '%s\n' "$default_value"
}
