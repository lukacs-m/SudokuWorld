# CLAUDE.md

Guidance for Claude (and Claude Code) working in this repository.

**The full, canonical agent instructions are in [`AGENTS.md`](./AGENTS.md). Read it
first** — it covers the architecture, the strict layer rules, the `public import`
discipline, the per-feature workflow, and the tooling. This file only adds
Claude-specific emphasis and a fast-path checklist.

## Fast-path checklist (before writing any code)

1. **Which layer(s) does this touch?** Map the work to packages before editing.
   A feature is almost always a vertical slice: Model → Domain → Data → DI →
   Presentation → Tests.
2. **Am I about to break a boundary?** Domain/Data must not import Factory.
   Presentation must not import Data. Registrations go only in `DI/.../Registrations/`.
   If the task needs a boundary broken, say so instead of doing it.
3. **Import visibility.** For every file, decide each import's visibility. If a type
   from a module appears in this file's *public* API (including `@Observable` and
   `some View`), it's `public import`. Otherwise plain `import`. This is the #1
   cause of build failures here — double-check it.
4. **Existentials use `any`.** `any SomeRepository`, never bare.

## Things that have bitten past edits (learn from these)

- `@Observable public final class` needs `public import Observation` — the macro
  generates a *public* conformance.
- Public `var body: some View` needs `public import SwiftUI`.
- Public properties of type `UUID`/`Date` need `public import Foundation`.
- Pull-to-refresh must not set `state = .loading` (it destroys the `List` and its
  refresh control mid-gesture). The reload path keeps current content.
- `swift test` builds for macOS, so packages declare `.macOS(.v26)` alongside iOS;
  macOS-unavailable APIs will fail CLI tests even though the app is iOS-only.
- Work that must leave the main actor in Presentation (the package is MainActor by
  default) needs `nonisolated` on the value types it touches and `@concurrent` on the
  entry point; a plain `Task {}` stays on the main actor. See `CubeFaceRenderer`.

## Working style in this repo

- Prefer the Makefile targets over ad-hoc commands (`make test`, `make lint`,
  `make format`, `make generate`). Don't hand-edit the generated `.xcodeproj`.
- When you finish a change, run `make test` and report the result. If no Swift
  toolchain is available in the environment, say the change is unverified and
  explain what still needs a real build — don't claim it compiles.
- Keep edits minimal and within the established patterns; match the `Article`
  reference slice.
- When you add public API, add the matching `public import` in the same edit.

## Quick reference

| Need | Go to |
|---|---|
| Architecture & rationale | `docs/ARCHITECTURE.md`, `README.md` |
| Full agent rules | `AGENTS.md` |
| Add a feature | `AGENTS.md` → "Implementing a feature" |
| Build/test commands | `make help`, `README.md` → "Quick start" |
| DI registration | `Packages/DI/Sources/DI/Registrations/` |
