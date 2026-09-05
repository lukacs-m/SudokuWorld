---
name: verify
description: Build, install, and drive SudokuWorld in the simulator to screenshot any screen for visual verification
---

# Verifying SudokuWorld visually

The app is iOS 26-only. Use the iPhone 17 Pro simulator
(`1E8D8069-8A97-47EE-9C99-A29A5A684394`), not the iOS 18 devices.
There are no tap-automation tools on this machine (no idb/axe) — use the
DEBUG-only launch hooks instead (`Packages/Common/Sources/Common/LaunchHooks.swift`,
handled in `HomeView.handleLaunchHooks`, except `-uiHookFogMoves`, which
`GameViewModel.start` drives; compiled out of release builds).

```bash
SIM=1E8D8069-8A97-47EE-9C99-A29A5A684394
xcrun simctl bootstatus $SIM -b
make build
# Resolve THIS worktree's build dir — DerivedData holds one per worktree and
# `find | head -1` happily returns another worker's stale app.
APP=$(xcodebuild -showBuildSettings -project SudokuWorld.xcodeproj -scheme SudokuWorld \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>/dev/null \
  | awk '/ BUILT_PRODUCTS_DIR =/ {print $3}')/SudokuWorld.app
xcrun simctl install $SIM "$APP"
xcrun simctl terminate $SIM com.mlukacs.sudokuWorld 2>/dev/null
# Straight into a game (slugs = SudokuVariant / Difficulty raw values):
xcrun simctl launch $SIM com.mlukacs.sudokuWorld -uiHookVariant littlekiller -uiHookDifficulty easy
# Or open the New Game sheet: ... -uiHookNewGameSheet YES
# Fog of War: ... -uiHookVariant fogofwar -uiHookDifficulty expert -uiHookFogMoves 5
#   plays N logic-only moves 3 s after the board appears (reveals + "fog lifts" cue).
sleep 6   # let generation finish before screenshotting
xcrun simctl io $SIM screenshot /path/to/shot.png
```

Gotchas:
- Verify the installed .app is fresh (`-newer` on a changed source file)
  before trusting the screenshot.
- The simulator is shared with parallel workers: another worker's
  `simctl install` replaces the app and kills your run mid-burst. Install
  right before launching and keep the screenshot loop short.
- `simctl io screenshot` takes ~0.5 s each; for a transient cue take a
  burst (`for i in $(seq 1 24)`) and pick frames by file timestamp.
- Board geometry for checking outside-clue/overlay positions: read the grid
  edges off the screenshot, cell size = width/9; clue labels sit in a
  one-cell gutter band around the grid.
- Cube variant (`-uiHookVariant cube`): `-uiHookCubeYaw 35 -uiHookCubePitch 25`
  starts the 3D board turned (degrees; keep values positive — a leading `-`
  is parsed as a new key) and `-uiHookSelectCell 22` pre-selects a cell
  (indices are face-major, see `CubeNet`). Real drags/pinches need touch
  injection: a throwaway XCUITest bundle (any project, `XCUIApplication(
  bundleIdentifier:)` + `press(forDuration:thenDragTo:)` / `pinch(withScale:)`)
  run with `xcodebuild test -destination id=$SIM` works without idb; take
  `simctl io screenshot`s from a shell loop while it runs.
