# SudokuWorld

A complete, production-ready iOS Sudoku game built with SwiftUI on a strict,
layered MVVM architecture. Seven variants with a guaranteed-unique-solution
engine, technique-based difficulty grading, hints that explain themselves,
SwiftData persistence, Game Center leaderboards & achievements, daily/weekly
events, RevenueCat monetization, and full English + French localization.

> **Architecture documentation:** [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
> for the layer deep-dive, [`AGENTS.md`](AGENTS.md) / [`CLAUDE.md`](CLAUDE.md)
> for the contribution rules (layer boundaries, `public import` discipline).

## Features

- **Variants** — Classic 9×9, Mini 6×6, Killer (cages with sums), Diagonal/X,
  Hyper/Windoku, Even-Odd, and Samurai (five overlapping grids, behind
  `FeatureFlags.samuraiEnabled`; on in Debug builds).
- **Six difficulties** (Beginner → Master) graded by the *solving techniques a
  puzzle actually requires* — never by clue count. The ladder: naked/hidden
  singles → pairs & killer cage arithmetic (medium) → pointing pairs,
  box-line reduction, triples, X-wing (hard) → swordfish & XY-wing (expert)
  → XY-chains (master). Expert and master boards genuinely *require* their
  techniques (pinned by tests). Every generated puzzle is fully solvable by
  logic (that's also what guarantees a unique solution) and every hint names
  and explains its technique.
- **Deterministic generation** — one seed produces a byte-identical puzzle on
  every device. The Daily Challenge derives its seed from the UTC date, so the
  whole world plays the same board.
- **Gameplay** — cell-first or digit-first input, pencil notes with optional
  auto-clean, unlimited undo/redo (undo restores auto-cleaned notes), mistake
  highlighting, conflict auto-check, hardcore mode (3 mistakes, no hints,
  losses count), pause that hides the board, autosave on every move and on
  backgrounding, a clock that never counts suspended time, confetti on wins,
  haptics via `.sensoryFeedback`.
- **Stats** — per variant × difficulty: played/won/lost/abandoned, win rate,
  win streaks, fastest/average times; daily-challenge streaks; Swift Charts
  (30-day activity, win rate by difficulty, best-vs-average times, variant
  distribution).
- **Game Center** — 84 matrix leaderboards + 4 aggregates, 16 achievements
  (incremental progress for milestones), offline submission queue, standings
  in the events hub. Gameplay never blocks on authentication.
- **Events** — three Daily Challenges per day (classic plus two rotating
  variants covering the full catalog every 17 days, identical for every
  player), streak protection reminders (opt-in local notifications), and a
  Weekly Tournament (themed variant × difficulty per ISO week, cumulative
  points on a recurring leaderboard).
- **Monetization** — fair freemium, no ads: classic play, all difficulties,
  hints, and undo are free forever; the three dailies are free on their day.
  The `premium` entitlement (RevenueCat monthly/annual/lifetime) unlocks
  unlimited variant play, the daily archive, and premium themes. Soft wall
  instead of lock screens; paywall with restore and no dark patterns.
- **Polish** — 6 color themes (3 premium) with light/dark palettes, full
  VoiceOver labels on every board cell, Dynamic Type, complete English +
  French string catalogs.

## Quick start

Requirements: Xcode 26.x (Swift 6.3 toolchain), plus `xcodegen`, `swiftlint`,
`swiftformat` (all installable via Homebrew — `make setup` installs XcodeGen).

```bash
make setup      # install XcodeGen and generate SudokuWorld.xcodeproj
make open       # open in Xcode — select the SudokuWorld scheme and run
make test       # run every package's test suite (139 tests, ~40s)
make build      # build for the iOS simulator from the CLI
make lint       # SwiftLint
make format     # SwiftFormat (in place)
```

The app runs fully **without any third-party keys**: purchases degrade to the
free tier (the paywall explains itself), ads use the built-in house provider,
and Game Center simply stays signed out until available.

## Project structure

```
App/SudokuWorld/          @main only — hands off to Presentation.AppRootView
Packages/
  Common/                 ViewState, Log, FeatureFlags
  Model/                  Sendable+Codable value types (puzzle, board, records…)
  Domain/                 THE ENGINE (topology-generic solver/generator/grader/
                          hints), GameSession, GameCenterIDs, stats aggregation,
                          repository & service protocols, use cases
  Data/                   SwiftData repositories, GameKit adapter (+offline
                          queue), RevenueCat adapter, simulated ads, notifications
  DI/                     FactoryKit Container registrations (composition root)
  Presentation/           SwiftUI views + @Observable ViewModels, themes,
                          Localizable.xcstrings (en + fr)
```

Dependency direction is strictly `Presentation → DI → Data → Domain → Model →
Common`, enforced by the package manifests. The engine is topology-generic:
one solver/generator/grader serves all seven variants — a variant is just a
`GridTopology` (cells + all-different houses) plus optional per-puzzle
constraints (cages, parity marks).

### Engine at a glance

| Stage | How |
|---|---|
| Fill | MRV backtracking with seed-shuffled digits (own xoshiro256★★ RNG — never the system RNG) |
| Variant extras | Killer: random-walk cage partition with distinct digits and exact sums; Even-Odd: parity marks derived from the solution |
| Carve | Grade-guided digging under two per-difficulty constraints: a removal is kept only while the technique ladder still solves the puzzle *and* grades ≤ target, and digging stops at the difficulty's givens floor (beginner ≈ 55% of cells stay given, easy 47%, medium 40%, hard 35%, expert 31%, master minimal) so difficulty is visible on the board, not just in the techniques |
| Uniqueness | Ladder-solvable ⇒ unique (every deduction is forced); tests independently re-verify with `solutionCount(limit: 2)` |
| Difficulty miss | Deterministic seed evolution, ≤ 40 attempts, nearest-grade fallback recorded in `gradedDifficulty` |
| Hints | The same ladder yields the next step with cells, eliminations, and a localized explanation |

## Configuration

All third-party keys live in
[`Packages/Data/Sources/Data/Purchases/AppSecrets.swift`](Packages/Data/Sources/Data/Purchases/AppSecrets.swift)
as clearly marked `REPLACE_ME` placeholders — the only placeholders in the
codebase.

### Game Center (App Store Connect)

The app already ships the entitlement (`com.apple.developer.game-center`, see
`project.yml`) and all reporting code. You only need to create the boards and
achievements in App Store Connect → *Your app* → **Game Center**.

Every identifier derives from `GameCenterIDs.prefix`
(`com.mlukacs.sudokuWorld`, in
[`GameCenterIDs.swift`](Packages/Domain/Sources/Domain/GameCenter/GameCenterIDs.swift)).
Change the prefix there once and the whole matrix follows; a unit test pins
the counts (84/88/16) so a rename can't silently desync. The in-app **Debug
menu** (Debug builds → Home → Debug) lists every ID for copy-paste and offers
an achievement reset.

**Leaderboards — 84 classic (non-recurring):** for each variant slug
(`classic, mini6, killer, diagonal, windoku, evenodd, samurai`) × difficulty
slug (`beginner, easy, medium, hard, expert, master`):

| ID pattern | Score format | Sort |
|---|---|---|
| `com.mlukacs.sudokuWorld.lb.time.<variant>.<difficulty>` | Integer (centiseconds — the app submits `Int(duration × 100)`; display “To the Hundredth of a Second”) | Low to high |
| `com.mlukacs.sudokuWorld.lb.wins.<variant>.<difficulty>` | Integer (cumulative wins) | High to low |

**Aggregates — 4:**

| ID | Type | Score | Sort |
|---|---|---|---|
| `com.mlukacs.sudokuWorld.lb.wins.all` | Classic | total wins | High to low |
| `com.mlukacs.sudokuWorld.lb.streak.best` | Classic | best daily streak | High to low |
| `com.mlukacs.sudokuWorld.lb.daily` | **Recurring, daily reset** | completion centiseconds | Low to high |
| `com.mlukacs.sudokuWorld.lb.weekly` | **Recurring, weekly reset (Monday 00:00 UTC)** | cumulative points | High to low |

**Achievements — 16** (`com.mlukacs.sudokuWorld.ach.<name>`), 450 points total
(≤ 1000 cap). Enable *Show completion banner* on all; milestones report
incremental percent automatically:

| Suffix | Trigger | Points | Notes |
|---|---|---|---|
| `firstwin` | first completed puzzle | 5 | |
| `wins.10` / `wins.100` / `wins.1000` | total-win milestones | 10 / 25 / 100 | incremental |
| `speed.expert3` | Expert Classic under 3:00 | 25 | |
| `speed.master5` | Master (any variant) under 5:00 | 40 | |
| `nohint.expert` | Expert win, zero hints/reveals | 20 | |
| `flawless.hard` | Hardcore Hard win, zero mistakes | 20 | |
| `streak.7` / `streak.30` | daily streaks | 15 / 50 | incremental |
| `variety` | win each core variant (6, samurai excluded) | 30 | incremental |
| `killer.master` | Killer win at Master | 30 | |
| `samurai` | complete a Samurai | 25 | |
| `daily.first` | complete any Daily Challenge | 10 | |
| `weekly.podium` | top 3 in a Weekly Tournament | 40 | |
| `night` | win between 00:00–04:00 local | 5 | **hidden** |

### RevenueCat

1. Create App Store Connect in-app purchases: auto-renewing subscriptions
   `sudokuworld.premium.monthly` and `sudokuworld.premium.yearly` (7-day intro
   trial on yearly only) and non-consumable `sudokuworld.premium.lifetime`
   (IDs pinned in `PremiumProducts`,
   [`PurchasesService.swift`](Packages/Domain/Sources/Domain/Services/PurchasesService.swift)).
2. In the RevenueCat dashboard: create an entitlement named **`premium`**,
   attach all three products, and add them to the *current* Offering as the
   standard *monthly*, *annual*, and *lifetime* packages (the paywall maps by
   package type, and all gating checks the entitlement — never product IDs).
3. Paste your public Apple API key (`appl_…`) into
   `AppSecrets.revenueCatAPIKey`. A `test_…` sandbox key works for local
   testing.

With a placeholder key, `configure()` is a no-op and purchase/restore throw
`DomainError.purchasesUnavailable`, which the paywall renders as a friendly
unavailable state — gameplay is never affected.

### Notifications

Opt-in from Settings: a daily-challenge reminder at a chosen hour and an
evening streak-saver that only schedules while a streak is actually at risk.
All copy lives in the string catalog.

## Localization

`Packages/Presentation/Sources/Presentation/Resources/Localizable.xcstrings`
carries complete **English and French** (~450 keys: UI, technique names, hint
explanations, notifications, paywall). French-default-ready: the catalog is
complete, so shipping French-first is just a `CFBundleDevelopmentRegion` flip
in `project.yml`. Test at runtime with:

```bash
xcrun simctl launch booted com.mlukacs.sudokuWorld -AppleLanguages "(fr)"
```

## Testing

Tests across four packages (`make test`, macOS host, ~40 s):

- **Domain** — solver correctness on known fixtures, per-variant generation
  (uniqueness re-verified from scratch, cage partitions, parity, determinism,
  daily-seed identity), daily rotation (full-catalog coverage per 17-day
  cycle without repeats, accessible/complex pairing, next-appearance scan),
  technique finders on crafted grids, grader monotonicity, `GameSession`
  rules (mistakes, hardcore loss, undo restoring auto-cleaned notes,
  pause/resume clock math), `GameCenterIDs` matrix (84/88/16, prefix, no
  duplicates), achievement evaluator (all 16), stats/streak edge cases.
- **Data** — SwiftData roundtrips on in-memory containers (saved-game upserts
  per context, records, per-slot daily completions incl. the on-day streak
  rule, tournament scores), UserDefaults repositories.
- **Presentation** — ViewModels with container-registered mocks
  (`@Suite(.container)`): game flow incl. hardcore loss, unlimited hints,
  digit-first input, `PremiumGate` (cache seed + stream flips), paywall
  flows, premium theme gating, events hub.
- **Model** — note bitsets, board/topology invariants.

CI (`.github/workflows/ci.yml`): format-check → lint → generate → test →
simulator build.
