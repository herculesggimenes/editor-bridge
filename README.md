# editor-bridge

macOS app and CLI shims that route file opens into Neovim running through Ghostty and tmux, with a native SwiftUI config app for managing defaults.

## What It Does

- `Dev Editor.app` lets Finder and LaunchServices open developer files in your terminal editor flow.
- `dev-editor` is a blocking CLI launcher suitable for `EDITOR`, `VISUAL`, and Git.
- `dev-editor-open` is a non-blocking app entrypoint that opens a new Ghostty window and keeps the tmux client attached after Neovim exits.
- `Zed.app` and `zed` provide a compatibility layer for tools that expect Zed to be installed.
- `Editor Bridge.app` is a native SwiftUI control panel for launcher settings and file-association presets.

## Architecture

- Shell stays on the hot path for launching: `dev-editor`, `dev-editor-open`, and `dev-editor-ghostty` remain the runtime entrypoints.
- A shared plist config at `~/.config/editor-bridge/config.plist` drives both the shell launchers and the SwiftUI app.
- `editor-bridge-apply` turns that config into two generated artifacts:
  - a LaunchServices plist fragment merged into `Dev Editor.app`
  - a UTI list that `duti` applies as default handlers
- The broad programmable-file preset is generated from GitHub Linguist's language database and can be extended or trimmed per machine.

## Flow

```text
LaunchServices/Finder
  -> Dev Editor.app
  -> ~/.local/bin/dev-editor-open
  -> Ghostty
  -> ~/.local/bin/dev-editor-ghostty
  -> tmux + nvim
```

```text
Codex or any caller expecting Zed
  -> Zed.app or zed
  -> Dev Editor flow
```

## Install

1. Link the CLI entrypoints:

```sh
mkdir -p ~/.local/bin
ln -sfn "$PWD/bin/dev-editor" ~/.local/bin/dev-editor
ln -sfn "$PWD/bin/dev-editor-open" ~/.local/bin/dev-editor-open
ln -sfn "$PWD/bin/dev-editor-ghostty" ~/.local/bin/dev-editor-ghostty
ln -sfn "$PWD/bin/editor-bridge-apply" ~/.local/bin/editor-bridge-apply
ln -sfn "$PWD/bin/zed" ~/.local/bin/zed
```

2. Install the app shims and config app:

```sh
./config/scripts/install-editor-bridge-config-app.sh
./config/scripts/install-dev-editor-app.sh
./config/scripts/install-zed-shim-app.sh
./config/scripts/install-zed-cli-shim.sh
```

3. Generate and apply the current file-association config:

```sh
~/.local/bin/editor-bridge-apply
```

4. Optionally open the SwiftUI config app:

```sh
open -a "$HOME/Applications/Editor Bridge.app"
```

## Configuration

The shared config lives at:

```sh
~/.config/editor-bridge/config.plist
```

The default config exposes:

- launcher settings such as `Ghostty.app`, `nvim` path, tmux session name, and tmux window name
- a broad programmable-file preset
- opt-in `public.plain-text` and `public.data` fallback modes
- custom extensions
- custom exact filenames
- excluded extensions and filenames
- extra UTIs to claim and map

The default programmable preset is bundled at:

```sh
Sources/EditorBridgeApp/Resources/default-programmable-files.json
```

Regenerate it from GitHub Linguist with:

```sh
./config/scripts/update_programmable_manifest.rb
```

## Requirements

- `nvim`
- `tmux`
- `Ghostty.app`
- `duti` for file associations
- macOS 13+ for the SwiftUI config app

Defaults can be overridden with environment variables such as:

- `DEV_EDITOR_GHOSTTY_HELPER`
- `DEV_EDITOR_BUNDLE_ID`
- `ZED_SHIM_BUNDLE_ID`
- `GHOSTTY_APP`
- `NVIM_BIN`
- `TMUX_EDITOR_DEFAULT_SESSION`
- `TMUX_EDITOR_WINDOW_NAME`
- `EDITOR_BRIDGE_CONFIG_PATH`
- `EDITOR_BRIDGE_APPLY_BIN`

## Tests

```sh
python3 -m unittest discover -s tests -v
swift build
```

## Reference Projects

These informed the architecture and scope:

- [FileTypeGuard](https://github.com/yibie/FileTypeGuard) for the native macOS association-manager shape and settings/logging split
- [duti](https://github.com/moretension/duti) for the actual default-handler application layer
- [SwiftDefaultApps](https://github.com/holvanato/SwiftDefaultApps) for the broader LaunchServices/default-app management problem space
- [GitHub Linguist](https://github.com/github-linguist/linguist) as the upstream source for the bundled programmable-file extension and filename preset
