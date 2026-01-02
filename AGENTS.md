# Repository Guidelines

## Project Structure

- `ViType-macos/`: macOS menu-bar app (Swift/SwiftUI), Xcode project in `ViType-macos/ViType.xcodeproj/`.
- `ViType-core/`: Rust core engine (`vitype_core`) built as a static library and linked into the macOS app.
- Docs for input rules live in `ViType-core/TELEX_RULES.md` and `ViType-core/VNI_RULES.md`.
- Build artifacts are typically ignored (`**/target/`, `**/build/`, `ViType-macos/.derivedData/`, `ViType-macos/dist/`).

## Build, Test, and Development Commands

Prereqs: Xcode + Command Line Tools, Rust toolchain (`cargo`), and macOS `hdiutil` (for DMG).

- Initialize submodules (if needed): `git submodule update --init --recursive`
- Rust core build/test:
  - `cd ViType-core && cargo build`
  - `cd ViType-core && cargo test`
- macOS app build (invokes `cargo build` via an Xcode build phase):
  - `xcodebuild -project ViType-macos/ViType.xcodeproj -scheme ViType -configuration Debug build`
- Build a distributable DMG:
  - `cd ViType-macos && bash ./scripts/build_dmg.sh` (writes to `ViType-macos/dist/`)

## Build Verification (Required)

- After changing Rust or Swift code, always run a build to confirm everything compiles (and `cargo test` when you touch core logic).
- Never leave the repository in a broken state (failing build, failing tests, or an app that doesn’t launch).

## Coding Style & Naming Conventions

- Rust (`ViType-core/`): `PascalCase` types, `snake_case` fns/fields, keep public API minimal; prefer early returns and `?` for `Result`/`Option`. Run `cargo fmt` before submitting if available.
- Swift (`ViType-macos/ViType/`): follow Swift API Design Guidelines; 4-space indentation; `UpperCamelCase` types, `lowerCamelCase` members. Keep UI in SwiftUI views and keep input/transformation logic isolated (e.g., `KeyTransformer.swift`).

## Commit & Pull Request Guidelines

- Commits: short, imperative subjects (e.g., “Fix …”, “Add …”, “Support …”); avoid “WIP”.
- PRs: describe user-visible behavior, include repro/verification steps, and attach screenshots for UI changes (Settings/menu bar). Keep changes scoped; update docs/tests when rules change.
