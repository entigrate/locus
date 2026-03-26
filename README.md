# Locus

A macOS menu bar app that screenshots the window under your cursor with a single hotkey and copies it to your clipboard.

## Requirements

- macOS 14+ (Sonoma)
- Swift 5.9+

## Build

```bash
./Scripts/build.sh
```

## Run

```bash
open Locus.app
```

On first launch, grant **Screen Recording** and **Accessibility** permissions when prompted.

## Usage

1. Hover your cursor over any window
2. Press **Cmd+Shift+W** to capture the window
3. Press **Cmd+Shift+F** to capture the full screen
4. The capture is copied to your clipboard
5. Paste anywhere with **Cmd+V**

Shortcuts are configurable via Settings (accessible from the menu bar icon).

You'll hear a sound and see a brief flash to confirm the capture. The app lives in your menu bar with a camera icon.
