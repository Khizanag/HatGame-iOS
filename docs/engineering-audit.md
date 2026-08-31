# Engineering and Architecture Audit

A code-grounded audit of Hat Game's engineering: correctness, security, architecture, testability, and App Store readiness. It is the counterpart to [`ux-ui-improvement-plan.md`](./ux-ui-improvement-plan.md) — that doc owns UX, visual design, game feel, and accessibility polish; this one owns what happens underneath. Where the two overlap (multiplayer resilience, accessibility correctness), this doc takes the engineering angle and defers the design angle there.

## How this was researched

Four parallel passes read the real codebase — the SwiftUI view layer, the test and quality infrastructure, the networking and sync layer, and app configuration and product readiness — then the load-bearing claims were re-verified by hand against source. Every finding cites `file:line`. The app is ~17.4k lines of Swift across one target and three local packages (`Navigation`, `Networking`, `DesignBook`), at `MARKETING_VERSION = 1.0`, build `1` — pre-launch, which is the right moment for this.

## Verdict

The foundation is genuinely strong and the house style is disciplined. But the app is not shippable as a "great product" yet, for reasons that are concentrated and fixable, not structural:

- **One live security exposure.** The Firebase Realtime Database is world-readable and world-writable with no authentication. This is an incident, not a backlog item.
- **Two player-facing flows are broken or fragile.** Nearby (Multipeer) play is non-functional the moment a guest is the explainer. Online games wedge permanently if the active player backgrounds the app, and rooms leak into the database forever.
- **Correctness gaps under concurrency and lifecycle.** Whole-node writes from cached state lose updates; a killed app loses an in-progress single-device game entirely.
- **The core game logic is nearly untestable**, which is why 7 unit tests guard ~3,400 lines of logic, and there is no build/test CI.

None of this needs a rewrite. The read/write topology, the navigation seam, the design-token system, and the localization pipeline are all sound. The work is a sequenced set of surgical fixes plus one architectural refactor that pays for itself by making the rest testable.

## What is already strong

Preserve these — they are the patterns the rest of the plan builds on.

- **Localization is effectively perfect.** 299 of 299 referenced keys resolve; Georgian coverage is ~100%; there are zero raw user-facing literals in shipping feature code. `Localizable.xcstrings`, driven by `AppLanguage` / `Bundle.appLanguage`.
- **View decomposition is consistent.** Every view over 300 lines has a short `body` with logic pushed into `private extension` blocks. The size comes from breadth, not monoliths.
- **The design-token system is real and adopted.** `DesignBook` exposes semantic `Color`/`Font`/`Spacing`/`Size`/`Motion`/`Haptics`; `Spacing` alone has 486 references, `Haptics` 103.
- **Cross-platform seams are centralized.** `Extensions/CrossPlatform.swift` keeps `#if os(...)` out of the views — only two remain in the entire view layer.
- **Per-flow navigation and DI scoping is clean.** Each `*FlowView` owns its `Navigator` and managers as `@State` and injects them; there is no global game state.
- **The Firebase decoding layer is careful.** `FirebaseDecoding.swift` documents and handles the two real Realtime Database quirks (dropped empty collections, child-writes reading back as maps); `GameSettings` defaults every field for forward compatibility.
- **Audio session handling is correct.** `.playback` + `.mixWithOthers` makes the time-up cue audible with the silent switch on without stopping the user's music.
- **Hygiene basics are clean.** Zero `TODO`/`FIXME`, zero `try!`/`as!` in the app and packages.

## Critical — fix now

| # | Finding | Evidence |
|---|---|---|
| C1 | **Firebase database is world read + write, no auth.** Anyone with the public project URL (shipped inside the IPA) can `GET /rooms.json` to dump every room's player names, submitted words, and scores; rewrite any game's state; or `DELETE /rooms.json` to wipe every room at once. `.validate` rules do not run on deletes, so the room-code regex protects nothing. Every `guard isHost` in the app is a UI affordance, not a security control. | `database.rules.json:4-5`; no `FirebaseAuth` dependency in `Networking/Package.swift` |
| C2 | **Nearby play is dead for guests.** Six of twelve `ClientAction` cases `break` into `applyOnHost` — a method that does not exist anywhere in the repo. Every guest gameplay action (start turn, got-it, skip, end turn, advance) is received by the host and silently discarded. As soon as the explainer is anyone but the host, the session freezes with no error. | `LocalRoomManager.swift:322-325` (grep: `applyOnHost` is only that comment) |
| C3 | **Rooms are never deleted.** `leaveRoom()` calls `stopObserving()`, which nils `room`, *before* reading `isHost` — so `isHost` is always `false` and the `deleteRoom` branch is unreachable. Hosts always fall through to `removePlayer`, orphaning a room whose `hostId` now points at a removed player, which no remaining client can host or start. Every room ever created still exists, with no TTL and no cleanup. | `RoomManager.swift:146-158`, `:103-109`, `:26-28` |
| C4 | **Feedback submission has never worked.** The rules grant only `rooms`; Realtime Database default-denies everything else. `FeedbackService` writes to `/feedback`, so every submission fails with `PERMISSION_DENIED` and the user sees a failure. | `FirebaseService.swift:241` vs. `database.rules.json`; `FeedbackService.swift:82` |

C2 and C3 each block a complete user path with a one-file fix. C1 is a data-exposure and billing-abuse issue that should be treated with incident urgency: the credentials are already public in every build.

## High — correctness, data loss, resilience

| # | Finding | Evidence |
|---|---|---|
| H1 | **Whole-node writes from cached state lose updates.** Every `gameState` mutation is an unconditional `setValue` of the entire node built from a possibly-stale local copy — no transactions, no `ServerValue`. Concrete races: double-tapping "Got it" (no in-flight guard) scores one point for two words; a word tap in the same second as timer expiry either drops the point or rewinds the turn from `.turnResults` back to `.playing`. | `FirebaseService.swift:226-230`; `GameSyncManager.swift:73,96`; `OnlinePlayView.swift:220,270-280` |
| H2 | **Backgrounding the active player wedges the online game permanently.** No `scenePhase` handling for online, no presence (`OnlinePlayer.isConnected` is written once and never updated), no `onDisconnect`. Phase advancement is gated on `isActivePlayer`, so if that device never returns, no one else can move the game forward. | `OnlinePlayer.swift:17`; `OnlineTurnResultsView.swift:186` |
| H3 | **The Firebase room observer leaks.** `RoomManager` has no `deinit`, `OnlineFlowView` has no `.onDisappear`, and `stopObserving`'s own guard fails when `room` is already `nil` (host-deleted). Dismissing the online sheet leaves a `.value` observer streaming the whole room for the process lifetime. | `RoomManager.swift:103-109`; `OnlineFlowView.swift:15` |
| H4 | **A killed app loses the entire in-progress single-device game.** All round, word, score, and role state lives in memory on a view-local `GameManager`; `HistoryManager` is a plain in-memory dictionary. Nothing is written to disk, and the models (`Team`/`Word`/`Player`/`GameConfiguration`) are not even `Codable`. Backgrounding pauses the timer; termination discards everything. | `GameManager.swift:17-44`; `HistoryManager.swift:10`; `GameFlowView.swift:13`; `Model/*.swift` |
| H5 | **`HistoryManager` keys scores on the whole `Team`.** `Team`'s synthesized `Hashable` includes its mutable `name` and `players`, so renaming or editing a team mid-game orphans its history entry, and `totalRanking()` (which aggregates into `[Team: Int]`) can double-count it. `getScore` survives only because it happens to compare by `.id`. | `HistoryManager.swift:10,58-67`; `Model/Team.swift`; edited via `GameManager.updateTeam` |
| H6 | **Multipeer trust model is broken.** `peerToPlayerId[peer]` is set from a guest's self-declared player ID *before* the duplicate check, so a guest can claim the host's ID and have every subsequent action attributed to the host. `applyAction` accepts `.startGame`/`.createTeam`/`.removeTeam` from any guest with no host check — strictly more permissive than the online path it mirrors. Invitations auto-accept anyone on the network. | `LocalRoomManager.swift:306-327` vs. `RoomManager.swift:161-201`; `LocalMultipeerService.swift:170-179` |
| H7 | **Writes have no timeout.** 15 of 17 Firebase operations are untimed, and `withTimeout` itself cannot cancel a Firebase continuation (no `withTaskCancellationHandler`). With persistence enabled, an offline `createRoom` leaves an infinite spinner with no cancel and no error. | `FirebaseService.swift:266-284`; `RoomCreationView.swift:158-161` |
| H8 | **Enum decoding has no forward-compatibility fallback.** `RoomStatus`/`GamePhase`/`OnlineGameRound` decode with a hard `try`. Ship a build that adds one phase case, and every older client that receives it throws, maps to `room = nil`, and renders the "joining" screen forever while the game continues without it. The pattern to fix this already exists in `GameSettings`. | `GameRoom.swift:59`; `OnlineGameState.swift:101,108` |

## Architecture

Four structural themes sit underneath the findings above. Addressing them is what turns "fix the bugs" into "won't regress."

### The transport seam is in the wrong place

Online and Local are related by subclassing: `LocalRoomManager: RoomManager` and `LocalGameSyncManager: GameSyncManager`, with the base classes `open`. In practice the subclasses override everything, make **zero `super` calls**, and inherit only stored properties. The consequences are all bad:

- **Base-class Firebase state leaks into the subclass.** `LocalRoomManager` inherits `firebaseService` and `roomObserverHandle` and survives only because the inherited `stopObserving()` happens to no-op on the local path — by accident, not design. Make it do anything unconditional and local mode breaks silently.
- **The rules logic is copy-pasted.** `LocalGameSyncManager` reimplements all six `GameSyncManager` methods verbatim — identical rotation, explainer, and initialization math. C2 exists *precisely because* the local copy drifted from the online one and nothing caught it. The next rule change will have to touch both, and one will be missed again.
- **Authority guards are silently dropped.** The online `guard isHost else { throw }` checks are absent from the local overrides, which is the root of H6.
- **Liskov is already violated in the type.** `joinRoom` throws `notImplementedForLocal`; `updatePlayerReady` is an empty override.

The right seam is a value-type rules layer plus a transport protocol:

```swift
// Pure, synchronous, exhaustively testable — no network, no I/O.
enum GameRules {
    static func markGuessed(_ state: GameState, teamId: String) -> GameState
    static func advanceAfterTurn(_ state: GameState) -> GameState
    // ...the transitions currently duplicated across two managers.
}

protocol RoomTransport {
    func write(_ room: GameRoom) async throws
    var updates: AsyncStream<GameRoom> { get }
}
```

`FirebaseTransport` and `MultipeerTransport` conform; a single concrete `@Observable RoomManager` is injected with one. This deletes both `open` classes, both no-op overrides, the `notImplementedForLocal` throw, the authority asymmetry, and the duplication — and it makes every game-rule transition unit-testable without a network, which is impossible today. This is the single highest-leverage architectural change, and it is why the plan sequences it *after* the urgent bug fixes but *before* investing in test coverage.

### Game logic lives in views, not managers

The game clock itself is a `Timer` owned by `GameView` (`:238`) and again by `OnlinePlayView` (`:260`). Word-pool generation with a three-attempt retry loop lives in `OnlineGameFlowView` and `LocalSessionView`. Autofill choreography with eight staggered `asyncAfter` appends lives in `WordInputView`.

The sharpest consequence: the time-preservation rule — the subtlest rule in the game — is split across `GameView` and `GameManager`, so it is only reachable through the view and cannot be unit-tested at all. Two of the view-owned timers (`RandomizationView:156`, `NextTeamView:393`) are also created without a `@State` handle or `.onDisappear` invalidation, so they keep firing and mutating state after the view is gone — a real leak, and `WordGenerationView` already shows the correct pattern.

Move orchestration and timing into the managers/engine; leave views to render and dispatch intent. This is the precondition for testing the rules that matter.

### There is no persistence layer

Everything is in-memory plus `UserDefaults`. There is no SwiftData, no Core Data, no file I/O, no Keychain. H4 is the direct result. For a great product, single-device games should survive termination via a `Codable` snapshot, and online play should support rejoin using the stable `deviceId` that already exists. This is a product-quality gap as much as a technical one — party games get interrupted constantly.

### Testability is a downstream symptom

The 7-tests-for-3,400-lines ratio is not discipline debt; it is a design consequence. Singletons are reached statically (`AppConfiguration.shared`, `FirebaseService.shared` as a hard-wired `private let`, `SoundPlayer.shared`), `Date()` is the implicit clock in the online timer, and the logic that matters lives in views. Fixing the transport seam and moving logic out of views removes these blockers as a side effect; then CI has something worth enforcing.

## Product readiness — App Store

At version 1.0/1 this is the pre-launch checklist, and several items are hard submission blockers.

- **No `PrivacyInfo.xcprivacy` anywhere.** The app uses `UserDefaults` (required-reason API `CA92.1`) and uploads a device identifier, hardware model, OS version, and locale to Firebase via `FeedbackService`. A privacy manifest with the required-reason declaration and collected-data types is mandatory. Blocker.
- **Entitlements request capabilities the app never uses.** `aps-environment: development` (push) with zero notification code, and CloudKit with an empty container array and no `CKContainer` usage. The push background mode (`UIBackgroundModes: remote-notification`) with no matching functionality is a classic 2.5.4 rejection, and `development` APS fails distribution signing. Remove all three unless you intend to build the features. `HatGame.entitlements`; `Info.plist`.
- **No macOS or visionOS app icons**, despite both being in `SUPPORTED_PLATFORMS`; all five icon sets are iOS-only 1024px. The global `AccentColor` asset is also empty while it is wired as the compiler accent color.
- **The "no typing needed" auto-fill is Georgian-only.** The bundled word list is 4,943 Georgian words with no English (or other) list and no language check. `WordSourceView` promises "we'll choose words from our database" with no hint the words will be Georgian — the feature is unusable for an English player with no fallback. `WordDatabase.swift:35`; `Resources/`.
- **A "Test Mode" developer toggle ships in release builds.** It swaps the real config for a mock and has no `#if DEBUG` guard. `DeveloperInfoView.swift`.
- **Multiplayer errors are hard-coded English inside the `Networking` package**, and 9 alert titles use `.alert("common.error")`, which resolves via `Bundle.main` and bypasses the in-app language override. A Georgian user sees English errors throughout online and nearby play (including "check your GoogleService-Info.plist"). `RoomManager.swift:254-267`; `FirebaseService.swift:296-313`.
- **`Networking.isConfigured` has zero call sites**, so a misconfigured build lets the user drill four screens deep before hitting a raw developer diagnostic. Gate the online entry point on it.

## Testing and CI

State: 7 `@Test` functions and 3 template XCTest methods (zero assertions) for the whole repo; no tests in any package; the hardest `GameManager` rules (time preservation, explainer locking, rotation, all scoring accessors) untested; the working `-uiTestScreen` deep-link hook unused by the UI test target. The only CI deploys Firebase rules.

Two hard blockers stand before any build/test CI:

- **No shared scheme in git.** `xcuserdata/` is gitignored and there is no `xcshareddata/xcschemes/HatGame.xcscheme`, so a fresh clone has no scheme to build.
- **`Package.resolved` is untracked** against a floating `from: "11.0.0"` Firebase pin — CI would resolve a non-reproducible version.

There is also an accidental language-mode split: the app target builds in Swift 5 mode (`SWIFT_VERSION = 5.0`) while all three packages default to Swift 6 mode; `SWIFT_STRICT_CONCURRENCY` and `TREAT_WARNINGS_AS_ERRORS` are set nowhere. Align these deliberately.

Minimal CI once the blockers clear: `macos-26` runner, pinned Xcode 26, `xcodebuild test` on an iPhone 17 (iOS 26) destination, `swiftlint lint --strict`, and `swift build` per package (cache the SwiftPM directory — Networking pulls the full Firebase SDK).

## The plan

Sequenced by risk and dependency. Each phase ships value alone; later phases assume earlier ones. UX, game-feel, and visual work stay tracked in [`ux-ui-improvement-plan.md`](./ux-ui-improvement-plan.md) and interleave between these.

### Phase 0 — Security incident (now)

1. Add Firebase Anonymous Auth (`FirebaseAuth`), sign in before any room access.
2. Rewrite `database.rules.json`: scope `.read`/`.write` to `$roomId` (kill the collection-level read), require auth, add `.validate` on room contents and size caps, add a write-only `/feedback` rule, restrict `status`/`gameState` writes to the appropriate role.
3. Add a `createdAt`-driven cleanup (scheduled function) to reclaim abandoned rooms, and store timestamps as `ServerValue.timestamp()` so they are usable as TTL keys.
4. Rotate the database if it currently holds real user data.

### Phase 1 — Fix the broken flows

5. Fix C3: capture `isHost` before `stopObserving()`.
6. Fix C2: implement the missing host-side apply path for the six gameplay actions; fix the `connectToHost` self-teardown and the `LocalRoomBrowser.onDisappear` session teardown.
7. Fix H3: add `deinit`/`.onDisappear` observer teardown, and make `stopObserving` robust to a nil `room`.
8. Add connect/join timeouts with a retry-and-escape path (H7), and surface `Networking.isConfigured` at the online entry point.

### Phase 2 — Correctness and data safety

9. Make `gameState` writes safe: `runTransactionBlock` for the read-modify-write operations, leaf-only `updateChildValues` for player-flag writes, an in-flight guard on "Got it" (H1).
10. Add presence + `onDisconnect` and a host/auto-advance fallback so a backgrounded player can't wedge the game (H2).
11. Make `Team`/`Word`/`Player`/`GameConfiguration` `Codable`; key history by `Team.id` (H5); snapshot single-device games to disk for restore-on-relaunch (H4).
12. Add `@unknown`-style fallbacks to the wire enums (H8).

### Phase 3 — The architecture refactor

13. Extract `GameRules` value-type transitions from the two sync managers.
14. Introduce `RoomTransport` with `FirebaseTransport` and `MultipeerTransport`; collapse the two manager hierarchies into one injected concrete type. Removes the subclassing, the duplication, and the authority asymmetry (H6) in one move.
15. Move the game clock and orchestration out of the views into the engine/managers.

### Phase 4 — Testing and CI foundation

16. Share the scheme; track `Package.resolved`; align Swift language mode and turn on strict concurrency + warnings-as-errors deliberately.
17. Unit-test `GameRules` and `GameManager` (rotation, locking, time preservation, scoring) — now possible after Phase 3.
18. Stand up build + test + lint CI; extend the snapshot harness to the gameplay and multiplayer screens via the existing deep-link hook.

### Phase 5 — App Store readiness

19. Add `PrivacyInfo.xcprivacy`; strip the unused push/CloudKit entitlements or implement them; fix `aps-environment`.
20. Add macOS/visionOS icons and the accent color; localize `Networking` errors and the `.alert("common.error")` titles; add an English word list (or gate the auto-fill feature by language); `#if DEBUG`-guard Test Mode.
21. Bump `MARKETING_VERSION`; add `ITSAppUsesNonExemptEncryption`; add an `InfoPlist.xcstrings` for localized permission prompts.

## Quick wins

Small, independent, do-anytime:

- Add `.DS_Store` to `.gitignore` (two are untracked right now).
- Delete dead code: `AppConfiguration.applyStoredAppIcon()`, the unused `RoomManager.error` / `GameSyncManager.error`/`isLoading` published properties, `SWIFT_STYLE_RULES.md` (orphaned, superseded by SwiftLint).
- Extract the copy-paste helpers: `errorBinding` (10×), `subscript(safe:)` (4×), the randomizer algorithm (2×), `@AppStorage("HatGame.lastPlayerName")` (4×).
- Collapse the ~160 byte-identical lines shared by `LocalSessionView` and `OnlineGameFlowView`, and the ~85% overlap of `RoomCreationView` and `LocalHostSetupView`.
- Replace `print()` with `OSLog` in `AppConfiguration` and `FirebaseService.observeRoom`.
- Prune the 43 stale keys from `Localizable.xcstrings`, and delete the 7 unused `DesignBook.Size` tokens.
- Fix the SwiftLint config so it lints the `Package.swift` manifests (the `.git`-suffix rule already has a live violation in `Networking/Package.swift`), and update `README.md`/`DEVELOPMENT.md` off `master` and iOS-only.
