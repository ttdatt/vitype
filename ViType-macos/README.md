# ViType (macOS)

## Build DMG (with `Applications` shortcut inside)

The DMG created by the script includes:
- `ViType.app`
- `Applications` (a symlink to `/Applications`) so users can drag-drop install

### Build (and create DMG)

From the repo root:

```bash
cd ViType-macos
bash ./scripts/build_dmg.sh
```

Output:
- DMG is written to `ViType-macos/dist/`

### Create DMG from an already-built `.app`

```bash
cd ViType-macos
bash ./scripts/build_dmg.sh --skip-build --app "/path/to/ViType.app"
```


