# Glimpse

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
open Glimpse.app
```

On first launch, grant **Screen Recording** and **Accessibility** permissions when prompted.

## Usage

1. Hover your cursor over any window
2. Press **Cmd+Shift+G**
3. The window is captured and copied to your clipboard
4. Paste anywhere with **Cmd+V**

You'll hear a sound and see a brief flash to confirm the capture. The app lives in your menu bar with a camera icon.
