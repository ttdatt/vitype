# CLAUDE.md

## Build Verification (Required)

- After changing Swift/UI/Xcode settings, always run a build to confirm the app compiles and links the Rust core.
- Never leave the app in a broken state (failing build, missing `libvitype_core.a`, Settings window not opening, etc.).

## Build Commands

```bash
# Build Release and create DMG
bash ./scripts/build_dmg.sh

# Create DMG from existing app (skip build)
bash ./scripts/build_dmg.sh --skip-build --app "/path/to/ViType.app"

# Build only (without DMG) via xcodebuild
xcodebuild -project ViType.xcodeproj -scheme "ViType" -configuration Release build
```

Output: `dist/ViType-<version>(<build>).dmg`

## Architecture

ViType is a macOS menu bar utility for Vietnamese text input using Telex/VNI methods.

**Core Components:**

- **AppDelegate.swift** - Main orchestrator: global keyboard event tap, input processing, shortcut handling, app exclusion logic
- **KeyTransformer.swift** - C FFI wrapper for `libvitype_core.a` (Rust library handling Vietnamese text transformation)
- **MenuBarManager.swift** - Status bar icon ("V"/"E" indicator) and context menu
- **WindowManager.swift** - Bridge between AppKit and SwiftUI for settings window management
- **ContentView.swift** - Main settings UI with tabbed interface (General, Advanced, App Exclusion)

**Event Flow:**
1. `CGEvent.tapCreate()` intercepts global keyboard events (requires Accessibility permission)
2. Events pass through `KeyTransformer.process()` which calls Rust via C FFI
3. Synthetic keyboard events inject transformed text back
4. Tag `0x11EE22DD` marks synthetic events to prevent processing loops

**Key Files:**
- `vitype_core.h` - C FFI header for Rust library
- `ViType-Bridging-Header.h` - Swift/C bridge
- `libvitype_core.a` - Pre-built Rust static library (must exist)

## Settings Storage

All settings use `UserDefaults` with keys defined in `AppExclusion.swift`:
- `viTypeEnabled`, `autoFixTone`, `inputMethod`, `outputEncoding`
- `shortcutKey`, `shortcutCommand/Option/Control/Shift`
- `enableAppExclusion`, `excludedBundleIDs`
- `playSoundOnToggle`, `appLanguage`

## Localization

Uses XCStrings format (`Localizable.xcstrings`) with English and Vietnamese. Access via `String.localized()` extension from `LocalizationManager.swift`.
