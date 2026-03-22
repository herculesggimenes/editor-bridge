# editor-bridge

macOS app and CLI shims that route file opens into Neovim running through Ghostty and tmux.

## What It Does

- `Dev Editor.app` lets Finder and LaunchServices open developer files in your terminal editor flow.
- `dev-editor` is a blocking CLI launcher suitable for `EDITOR`, `VISUAL`, and Git.
- `dev-editor-open` is a non-blocking app entrypoint that opens a new Ghostty window and keeps the tmux client attached after Neovim exits.
- `Zed.app` and `zed` provide a compatibility layer for tools that expect Zed to be installed.

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
ln -sfn "$PWD/bin/zed" ~/.local/bin/zed
```

2. Install the app shims:

```sh
./config/scripts/install-dev-editor-app.sh
./config/scripts/install-zed-shim-app.sh
./config/scripts/install-zed-cli-shim.sh
```

3. Optionally register file associations for the Dev Editor app:

```sh
./config/scripts/set-dev-editor-associations.sh
```

## Environment

- `nvim`
- `tmux`
- `Ghostty.app`
- `duti` for file associations

Defaults can be overridden with environment variables such as:

- `DEV_EDITOR_GHOSTTY_HELPER`
- `DEV_EDITOR_BUNDLE_ID`
- `ZED_SHIM_BUNDLE_ID`
- `GHOSTTY_APP`
- `NVIM_BIN`
- `TMUX_EDITOR_DEFAULT_SESSION`
- `TMUX_EDITOR_WINDOW_NAME`

## Tests

```sh
python3 -m unittest discover -s tests -v
```

