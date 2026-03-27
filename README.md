# Locus

A macOS menu bar app that captures the window under your cursor with one hotkey and copies it to your clipboard. Paste into Claude, ChatGPT, Slack, or anywhere else. No click, no drag, no file to find.

**[locusapp.dev](https://locusapp.dev)**

## The Problem

Sharing what's on your screen takes too many steps:

1. Cmd+Shift+4 (enter screenshot mode)
2. Spacebar (switch to window mode)
3. Click the window
4. Find the file on your Desktop
5. Copy the file
6. Paste

**Locus reduces this to one hotkey + Cmd+V.**

## Features

- **Instant window capture** — press Cmd+Shift+1 to capture the window under your cursor
- **Full screen capture** — press Cmd+Shift+2 to capture the entire screen
- **Capture history** — browse, re-copy, and manage past captures with Cmd+Shift+H
- **Configurable shortcuts** — set your own hotkeys in Settings
- **Audio and visual feedback** — confirmation sound and screen flash on capture
- **Launch at login** — optional, configurable in Settings
- **Menu bar only** — no dock icon, runs quietly in the background

## Install

### Download

Download the latest DMG from the [Releases](https://github.com/entigrate/locus/releases) page.

### Homebrew

```bash
brew install entigrate/tap/locus
```

### Build from Source

Requires macOS 14+ (Sonoma) and Swift 5.9+.

```bash
make setup   # First-time: install tools, configure git hooks
make build   # Build Locus.app
open Locus.app
```

## Permissions

Locus requires two macOS permissions on first launch:

- **Accessibility** — needed to register global hotkeys so the capture shortcut works in any app
- **Screen Recording** — needed to capture window contents

Both are standard macOS permissions with system-level prompts. The source code is public so you can verify exactly what these permissions are used for. No data leaves your machine.

## Usage

1. Hover your cursor over any window
2. Press **Cmd+Shift+1** to capture the window
3. The capture is copied to your clipboard — paste anywhere with **Cmd+V**

Access Settings, capture history, and more from the menu bar icon.

## License

[FSL-1.1-MIT](LICENSE) — source available, free to use, converts to MIT after 2 years per release.
