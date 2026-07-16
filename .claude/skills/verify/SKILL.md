---
name: verify
description: Build, install, and drive SudokuWorld in the simulator to screenshot any screen for visual verification
---

# Verifying SudokuWorld visually

The app is iOS 26-only. Use the iPhone 17 Pro simulator
(`1E8D8069-8A97-47EE-9C99-A29A5A684394`), not the iOS 18 devices.
There are no tap-automation tools on this machine (no idb/axe) — use the
DEBUG-only launch hooks instead (`Packages/Common/Sources/Common/LaunchHooks.swift`,
handled in `HomeView.handleLaunchHooks`; compiled out of release builds).

```bash
SIM=1E8D8069-8A97-47EE-9C99-A29A5A684394
xcrun simctl bootstatus $SIM -b
make build
APP=$(find ~/Library/Developer/Xcode/DerivedData -name "SudokuWorld.app" -path "*iphonesimulator*" | head -1)
xcrun simctl install $SIM "$APP"
xcrun simctl terminate $SIM com.mlukacs.sudokuWorld 2>/dev/null
# Straight into a game (slugs = SudokuVariant / Difficulty raw values):
xcrun simctl launch $SIM com.mlukacs.sudokuWorld -uiHookVariant littlekiller -uiHookDifficulty easy
# Or open the New Game sheet: ... -uiHookNewGameSheet YES
sleep 6   # let generation finish before screenshotting
xcrun simctl io $SIM screenshot /path/to/shot.png
```

Gotchas:
- Verify the installed .app is fresh (`-newer` on a changed source file)
  before trusting the screenshot.
- Board geometry for checking outside-clue/overlay positions: read the grid
  edges off the screenshot, cell size = width/9; clue labels sit in a
  one-cell gutter band around the grid.
