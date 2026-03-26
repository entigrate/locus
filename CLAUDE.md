# Locus

A macOS menu bar app that captures the window under your cursor with a hotkey (Cmd+Shift+W) and copies it to clipboard.

## Build & Run

```bash
make build          # Build Locus.app (with ad-hoc code signing)
make run            # Build and open
make build-reset    # Build with permission reset
make check          # Format + build (all quality gates)
make format         # Auto-format Swift files
make lint           # Check formatting without modifying files
make test           # Run tests (requires Xcode)
make setup          # First-time: install tools, configure git hooks
make release        # Full release: build, sign, notarize, DMG, appcast, GitHub release
```

## Architecture

- **Target:** macOS 14+ (Sonoma), Swift 5.9+
- **Build:** Swift Package Manager + build script assembling .app bundle with ad-hoc code signing
- **UI:** SwiftUI MenuBarExtra (menu bar only, no dock icon)
- **Hotkey:** CGEventTap (consumes keystroke, doesn't leak to focused app)
- **Capture:** ScreenCaptureKit (modern API, no deprecated calls)
- **Window detection:** CGWindowListCopyWindowInfo (cursor hit-testing)

## Source Layout

```
Sources/Locus/
  LocusApp.swift        — @main entry, MenuBarExtra UI
  AppDelegate.swift     — Permissions, hotkey wiring, capture pipeline
  HotkeyBinding.swift   — Hotkey binding model (keyCode, modifiers, display)
  HotkeyManager.swift   — CGEventTap global hotkey dispatch
  SettingsStore.swift    — App settings (bindings, sound, launch at login)
  SettingsView.swift     — Settings window UI
  WindowDetector.swift   — Window enumeration & cursor hit-testing
  ScreenCapture.swift    — ScreenCaptureKit → clipboard
  Feedback.swift         — Configurable sound + screen flash on capture
Tests/LocusTests/        — XCTest (requires Xcode to run)
Scripts/build.sh         — Compile + .app bundle + ad-hoc signing
```

## Conventions

- Use `guard let` or `if let` for optionals — never force-unwrap (`!`)
- Use `#if DEBUG` for any print/logging statements
- Use `NSScreen.screens.first` (primary screen) for coordinate conversion, not `NSScreen.main`
- All enums used as namespaces (no cases) should be declared as `enum`, not `struct`
- Permissions: poll for grant status and auto-recover — never require manual restart
- Sound: configurable via Settings (default "Glass" for success, "Basso" for failure)
- Run `make format` before committing to ensure consistent style

## Quality Gates

Before committing, run `make check`. This runs:
1. SwiftFormat (auto-fixes formatting per `.swiftformat` config)
2. `swift build` (compile check)

Pre-commit hook enforces formatting + build automatically via `.githooks/pre-commit`.

## Tool Requirements

- **SwiftFormat** (via Homebrew): `brew install swiftformat` — formatting + lint
- **Xcode** (optional): Required for `swift test` and SwiftLint. Install from App Store.
- Run `make setup` to install tools and configure git hooks.
