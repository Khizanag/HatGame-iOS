# Improvement Plan — November 2026

A fresh audit of Hat Game against the current code, re-verifying every finding in [`engineering-audit.md`](./engineering-audit.md) and [`ux-ui-improvement-plan.md`](./ux-ui-improvement-plan.md) and adding new ones. Four parallel passes: networking and multiplayer, single-device engine and tests, the SwiftUI view layer, and project configuration. Every item cites the file it lives in; ids are stable so commits can reference them.

## Baseline (2026-11-16, `main` @ `2e18528`)

| Gate | State |
|---|---|
| Build (iOS sim) | Clean — zero compiler warnings |
| Unit tests | 7 Swift Testing tests, all pass; UI tests are the Xcode template (no assertions) |
| `swiftlint --strict` | 66 violations across 9 rules |
| Swift language mode | App targets Swift 5 (`SWIFT_VERSION = 5.0`); packages Swift 6 |
| Shared scheme / CI | Neither — only a Firebase-rules deploy workflow |
| Privacy manifest | Missing |

## Verdict

The foundation is still sound — token discipline, per-flow DI, localization coverage, a careful Firebase decoding layer. But the audit found **two new online-play defects that corrupt games** (N1, N2), confirmed that **nearby play is still dead for guests** (C2, C2b), and found a **single-device game-corrupting navigation bug** (E1). Almost every item from the prior audit is still open: nothing below the security fix has landed.

## Phase 1 — Networking and multiplayer (`HatGame-Networking`, `database.rules.json`)

### Critical

| Id | Finding | Fix |
|---|---|---|
| N1 | `createRoom` writes `players: [host]` as a JSON array → RTDB stores the host at `players/0`; every later write keys by player id, so the host gets a partial/duplicate node. Partial node fails decoding → every client stuck on "joining"; full duplicate traps in `Dictionary(uniqueKeysWithValues:)`. `RoomManager.swift:56-64`, `FirebaseService.swift:42-43`, `GameRoom.swift:62`, `GameSyncManager.swift:201`, `OnlineNextTeamView.swift:35` | Custom `GameRoom.encode(to:)` writing `players`/`teams` as `[id: value]`; `uniquingKeysWith` at both call sites |
| N2 | `decodeFirebaseCollection` returns `Array(dict.values)` — per-process hash order, so team order differs per device while `currentTeamIndex` indexes it | Sort the dictionary case deterministically (by key) |
| C2 | Six nearby `ClientAction` cases `break` into a nonexistent `applyOnHost` — guest gameplay actions are dropped. `LocalRoomManager.swift:322-325` | Host-side apply through shared `GameRules` |
| C2b | Guest `connectToHost` restarts browsing (tearing down the session that found the host); browser `onDisappear` disconnects again; no connect timeout. `LocalRoomManager.swift:93-94`, `LocalMultipeerService.swift:95-121`, `LocalRoomBrowser.swift:50,179` | Split stop-browsing from end-session; reuse session; await `.connected` with timeout |
| C3 | `leaveRoom` nils `room` before reading `isHost` → rooms never deleted; guests of a deleted room spin forever. `RoomManager.swift:146-158` | Capture `isHost` first; `roomClosed` state for guests |
| C4 | `/feedback` has no rule → every feedback submission is denied | Create-only `/feedback/$id` rule with validation |

### High

| Id | Finding | Fix |
|---|---|---|
| H1 | Whole-`gameState` `setValue` from cached state; double-tap / tap-at-expiry races. `FirebaseService.swift:226-230` | `runTransactionBlock` around a pure precondition-checked transform |
| H2 | No presence; a backgrounded explainer wedges the game | `.info/connected` + `onDisconnectSetValue(false)`; host can advance a stalled turn |
| H3 | Room observer leaks; `stopObserving` guard fails when `room` is nil | Track `observedRoomId`; tear down on flow disappear |
| H6 | Multipeer trust: peer mapped before duplicate check; host-only actions accepted from guests | Map after add; `GameRules.canPerform` authority checks |
| H7 | `withTimeout` uses a task group that awaits its hung child — the timeout never fires; writes untimed | Cancellation-aware race with resume-once guard |
| H8 | Wire enums decode with hard `try` — one new case bricks old clients | Unknown values → `.unsupported` fallback |
| N3 | Guests treat any peer's disconnect as host loss; accept snapshots from any peer | Track `hostPeerID` |

### Medium / Low

N4 silent `try?` decode fallbacks wipe scores · N5 `LocalMultipeerService` data race (`@unchecked Sendable`) · N7 non-atomic `submitWords` · N8 `removeTeam` leaves dangling `teamId` · room-code uniqueness never checked · join-code filter accepts any letter · `print` → `Logger` · dead code (`RoomManager.error`, `GameSyncManager.isLoading/error`, `updatePlayerReady`, `updateSettings`, `onInvitationReceived`) · `.git` suffix in `Package.swift`.

### Architecture

Extract a pure **`GameRules`** layer (all seven turn/round transitions, plus `RoomRules` for lobby mutations and a `canPerform` authority matrix) inside the Networking package, fully unit-tested. Route Firebase transactions, the Multipeer host path, and guest-action application through it. The `RoomTransport` protocol collapse of the subclass pairs is deferred until the rules have test coverage and multi-device verification is available.

## Phase 2 — Single-device engine (`Manager/`, `Model/`, `View/Play`, `View/Setup`, tests)

| Id | Sev | Finding | Fix |
|---|---|---|---|
| E1 | Critical | Back-swipe from Next Team re-runs `prepareForNewPlay()` / `start()` — skips a team, rotates an explainer, skips a round, or wipes round-1 history. Double-tap on Start does the same | Phase-guarded idempotent transitions; hide back inside the game loop |
| E2 | High | Rematch keeps the previous game's round 2/3 history | Reset history on rematch |
| E3 | High | Navigation stack grows 3 pages per turn with colliding ids; dozens of live `GameView`s observe `currentWord` | One phase-switching container; no pushes inside the loop |
| H4 | High | A killed app loses the in-progress game; models not `Codable` | `Codable` `GameState` snapshot to Application Support; Resume on Home |
| H5 | High | `HistoryManager` keyed by whole `Team` (mutable name) | Key scores by `Team.ID` |
| E4 | Medium | Give-up alert doesn't pause the clock — expiry + confirm pushes two results | Pause during alert; phase guard |
| E5 | Medium | Turn shows 0 for a full tick; tick-counting clock drifts | Deadline-based `TurnClock` |
| E6 | Medium | Emptying the hat at 0 s grants a fresh timer, contradicting `rounds.md` | Decide and document |
| E7 | Medium | Manual entry ignores Allow Duplicate Words; case-sensitive | Apply the setting to manual entry |
| E8 | Medium | Back from Randomization and re-save duplicates the last player's words | Idempotent per-player save |
| E9 | Medium | Auto-fill `asyncAfter` appends unguarded | Cancellable task; guard capacity |
| E10 | Medium | Swift 6 blockers: `Timer` closures mutate captured vars, call main-actor methods | `Task`/`Clock.sleep` loops; `nonisolated` `Sendable` models |
| E11 | Medium | Play Again behavior contradicts `scoring.md` / `game-flow.md` | Align docs with code |
| — | Low | Ties sort randomly · index traps · missing word file leaves the game stuck · dead code · `print` · English-only team-name suggestions | Fix each |

Also: Georgian-only word database (no English list) · Test Mode ships in Release · singletons read in tests (`AppConfiguration.shared`) · leaked/uncancellable timers in `RandomizationView`/`NextTeamView`.

Design: `GameState` (Codable, Sendable) + pure `GameRules` + `TurnClock` + `@Observable GameEngine` with an injectable `Clock`, a `GameStore` protocol (`FileGameStore` actor), and a test suite covering every transition (target ≥ 80% of engine, scoring, persistence).

## Phase 3 — Project configuration and App Store readiness

| Id | Sev | Finding | Fix | Owner? |
|---|---|---|---|---|
| P1 | Critical | No `PrivacyInfo.xcprivacy` | Add with `CA92.1` UserDefaults reason + collected data types | Answer App Privacy in ASC to match |
| P2 | Critical | All 10 icon PNGs have an alpha channel (ITMS-90717) | Flatten headlessly | — |
| P3 | High | Alternate icons never compiled — Settings icon picker fails silently | `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`; drop hand-written `CFBundleIcons` | — |
| P4 | High | `remote-notification` background mode with no push code; orphaned entitlements file | Remove both | — |
| P5 | High | No macOS / visionOS icons | macOS sizes generated from the iOS master; visionOS layered icon needs design | visionOS: yes |
| P6 | High | No shared scheme | Add `xcshareddata/xcschemes/HatGame.xcscheme` | — |
| P7 | Medium | No build/test CI | `ci.yml`: lint + unit tests + macOS build | — |
| P8 | Medium | Swift 5 mode; no warnings-as-errors | Swift 6 mode on all app targets; warnings as errors | — |
| P9 | Medium | No export-compliance key; permission prompts unlocalized | `ITSAppUsesNonExemptEncryption = NO`; `InfoPlist.xcstrings` (en + ka) | Sign off Georgian copy |
| P10 | Medium | Lint skips `Package.swift`; no `parent_config` | Lint manifests | — |
| P11 | Low | Dead sandbox settings · package platforms `.iOS(.v17)` · test bundle ids · unpinned `firebase-tools` · template UI tests · empty AccentColor · stale `DEVELOPMENT.md`/`SWIFT_STYLE_RULES.md`/README | Fix each | Accent color choice |

## Phase 4 — View layer, accessibility, localization

| Id | Sev | Finding | Fix |
|---|---|---|---|
| V1 | High | 66 lint violations (19 inline fonts, 12 identifier names, 10 raw white/black, 8 line length, 7 view-var structure, 4 trailing closures, 3 false-positive nav-destination, 2 for-where, 1 body length) | Hero tokens in DesignBook, `onAccent` color, split nested structs, fix rule excludes — zero violations, no blanket disables |
| V2 | High | Standings sheet has no dismiss on macOS/visionOS | Toolbar Done + `.cancelAction` |
| V3 | High | Errors bypass the in-app language: hard-coded English in Networking, 8× literal `"common.error"`, `String(localized:)` | App-side error → key mapping; all titles via `localized()` |
| V4 | High | Online gameplay writes fire-and-forget (`try?`, no in-flight guard) | `isSubmitting` + error alert |
| V5 | High | Dynamic Type mostly unsupported — fixed-size font tokens, no `@ScaledMetric` | Rebase tokens on text styles; scaled hero metrics |
| V6 | High | Test Mode reachable in Release | `#if DEBUG` |
| V7 | Medium | WordCard a11y: Skip action always exposed; `.isButton` with no default action | Conditional actions; default = Got It |
| V8 | Medium | Reduce Motion gaps (2 symbol effects, ~10 `withAnimation`) | Gate on `reduceMotion` |
| V9 | Medium | Missing VoiceOver labels/titles/values | Add them |
| V10 | Medium | White on light team colors fails contrast | Contrast-aware `onAccent` |
| V11 | Medium | No plural handling — "1 words collected" | Plural variations in the catalog |
| V12 | Medium | Unstructured view `Task`s with no cancellation; init only from `onChange` | `.task(id:)` |
| V13 | Medium | Oversized views (TeamFormView 558, WordInputView 524, RandomizationView 450, NextTeamView 416, RoomLobbyView 413) | Extract subviews into files |
| V14 | Medium | 34× deprecated `.cornerRadius()` | `.clipShape(.rect(cornerRadius:))` |
| V15 | Medium | Toolbar button with custom opaque background fights Liquid Glass; hero radius hardcoded 5× | System toolbar button; `Size.heroCardCornerRadius` |
| V16 | Medium | `CrossPlatform` shims use `#if os(iOS)` — visionOS loses edit mode and inline titles | `#if !os(macOS)` |
| V17 | Medium | Duplication: `errorBinding` 11×, `subscript(safe:)` 6×, `lastPlayerName` 4×, `LocalSessionView`/`OnlineGameFlowView` 57% identical, `RoomCreationView`/`LocalHostSetupView` 70% | Shared helpers and views |
| V18 | Low | 43 stale catalog keys; emoji `Text` creates keys; package `NavigationView` clashes with SwiftUI; unused tokens; team delete without confirmation; `Networking.isConfigured` never consulted | Fix each |

## Out of scope — needs the owner

- Firebase Anonymous Auth / App Check — declined on 2026-11-16; the database remains open to anyone holding a room code.
- Restricting the iOS API key to the bundle id (Google Cloud console).
- visionOS layered app icon (design).
- App Store Connect App Privacy answers matching `PrivacyInfo.xcprivacy`.
- Multi-device verification of nearby play and online presence (two physical devices).

## Execution

Phases 1–3 run in parallel on disjoint file sets, then Phase 4 on top, then the Swift 6 language-mode switch and a final gate (build zero warnings on iOS + macOS, `swiftlint --strict` zero, all tests green, snapshot baselines refreshed, device install). Each item lands as its own commit on `main` referencing its id.
