# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Hat Game — a SwiftUI party game (explain words to teammates against a timer, 3 rounds). One app target plus three local Swift packages. Three independent play modes: single-device pass-and-play, online multiplayer (Firebase Realtime Database), and same-network multiplayer (MultipeerConnectivity).

Stack: SwiftUI, `@Observable` (Observation framework, never `@ObservableObject`), Swift Concurrency. Bundle id `com.khizanag.hat-game`, Firebase project `hat-game-e050f`.

Multiplatform: one target supporting iOS, macOS, and visionOS — deployment target 26.0 on all three (`TARGETED_DEVICE_FAMILY` 1,2,7). Platform differences are centralized in `Extensions/CrossPlatform.swift` (`#if os(...)` view shims — inline titles, edit mode, list styles); `HatGameApp` adds macOS window sizing (560×880 phone-like default, resizable) and a native Settings scene (Cmd-,). On macOS the game flows present as a `.page`-sized sheet (see `HatGame-Navigation/Sources/Navigation/NavigationView.swift`). `DEVELOPMENT_TEAM` is intentionally empty (the previous team id was wrong) — don't re-add one.

Canonical game rules (teams, the hat, 3 rounds, turns, scoring, the three modes) are documented in `docs/` — read `docs/README.md` first when behavior questions come up.

## Commands

The Xcode project has **no workspace** — it references the three packages as local SPM references, so always build with `-project` (never `-workspace`). Scheme is `HatGame`; the deployment target is iOS 26, so a destination on an iOS 26 simulator is required.

```bash
# Build (prefer XcodeBuildMCP tools in this environment when available).
# NOTE: a plain "iPhone 16" simulator is iOS 18.6 here; the deployment target is
# iOS 26, so use a generic destination or an iOS 26 device (iPhone 17 / 16e).
xcodebuild -project HatGame/HatGame.xcodeproj -scheme HatGame \
  -destination 'generic/platform=iOS Simulator' build

# macOS build (the target is multiplatform)
xcodebuild -project HatGame/HatGame.xcodeproj -scheme HatGame \
  -destination 'platform=macOS' build

# Run the full test suite (HatGameTests + HatGameUITests)
xcodebuild -project HatGame/HatGame.xcodeproj -scheme HatGame \
  -destination 'platform=iOS Simulator,name=iPhone 17' test

# Run a single Swift Testing test (target/suite/function)
xcodebuild ... test -only-testing:HatGameTests/HatGameTests/skippingDisabledKeepsCurrentWord

# Lint — strict, zero violations is the bar. Config at repo root covers the app + all 3 packages.
swiftlint lint --strict

# Visual snapshot harness — boots an iOS 26 sim, deep-links into each screen via a
# DEBUG launch-arg hook, captures one PNG per screen × light/dark into Screenshots/.
Scripts/snapshot.sh            # capture / update baselines
Scripts/snapshot.sh --verify   # exit 1 if any screen differs from its committed baseline
```

Unit tests use the **Swift Testing** framework (`import Testing`, `@Test`, `#expect`) — not XCTest. UI tests (`HatGameUITests`) use XCUITest.

Visual regression: `Scripts/snapshot.sh --verify` rebuilds the app, re-captures each screen, and pixel-compares against the committed `Screenshots/*.png` baselines (native CoreGraphics comparator in `Scripts/compare-images.swift`, no third-party). The DEBUG-only `-uiTestScreen` / `-uiTestColorScheme` launch hook lives in `Configuration/UITestConfiguration.swift`. Refresh baselines with `Scripts/snapshot.sh` after an intentional UI change.

## Architecture

### Three play modes — the central organizing idea

The app folder structure mirrors the three modes. Understand which mode a view belongs to before changing it:

| Mode | Entry flow view | Folder | State managers |
|---|---|---|---|
| Single-device pass-and-play | `GameFlowView` (`View/Game/`) | `View/Setup`, `View/Play` | `GameManager` |
| Online (Firebase) | `OnlineFlowView` (`View/Online/`) | `View/Online` | `RoomManager`, `GameSyncManager` |
| Same-network (Multipeer) | `LocalFlowView` (`View/Local/`) | `View/Local` (+ reuses `View/Online`) | `LocalRoomManager`, `LocalGameSyncManager` |

### Per-flow navigation + DI scoping (read `GameFlowView`/`OnlineFlowView`/`LocalFlowView` first)

Each mode's `*FlowView` is the seam. It:
1. Creates its **own** `Navigator()` and its mode's managers as `@State` (fresh per launch).
2. Wraps a `NavigationStack` bound to `navigator.navigationPath`.
3. Injects those objects into the environment for the whole subtree via `.environment(...)`.

`HatGameApp` only injects an app-level `RoomManager`/`GameSyncManager` and `AppConfiguration.locale`; the real per-game state is created inside the flow views. Child views read dependencies with `@Environment(GameManager.self)`, `@Environment(Navigator.self)`, etc. There is no global game state.

### Local multiplayer reuses online views via subclassing

`LocalRoomManager: RoomManager` and `LocalGameSyncManager: GameSyncManager` (the base classes are `open` in the Networking package). `LocalFlowView` injects them upcast as `RoomManager`/`GameSyncManager` (`.environment(roomManager as RoomManager)`), so the entire `View/Online` gameplay surface (`OnlineGameFlowView`, `OnlinePlayView`, results, etc.) runs unchanged on a Multipeer transport. When editing online gameplay views, remember they also drive local multiplayer — keep behavior transport-agnostic.

### Single-device game engine

`GameManager` (`Manager/GameManager.swift`, `@Observable`) owns all pass-and-play logic: round iteration, team rotation, explainer-role locking, word pool, and per-team time preservation across rounds. It **owns** `HistoryManager` as a `let` (accessed via `gameManager.historyManager`, not injected separately). Other single-device managers: `GameConfiguration`, `SoundPlayer`, `WordDatabase` (4,943 Georgian quick-fill words from Wiktionary, bundled as `Resources/georgian-words.txt`), `TeamDefaultColorGenerator`, `TeamNameSuggestions`, `FeedbackService`.

### Local Swift packages (repo-root siblings: `HatGame-Navigation/`, `Networking/`, `HatGame-DesignBook/`)

- **HatGame-Navigation** — the navigation system; module name stays `Navigation`. `Page<Content: View>` is a typed, `id`-keyed view factory; `AnyPage` type-erases it for the stack; `Navigator` (`@MainActor @Observable`) exposes `push`/`present`/`dismiss`/`popToRoot`. App-specific destinations are static factories in `HatGame/Navigation/Page.swift` (`extension Page`). swift-tools 6.2.
- **Networking** — both multiplayer transports. Online: `FirebaseService` (singleton, Realtime Database under `/rooms/$roomId`), `RoomManager`, `GameSyncManager`, and `Online*` models (`GameRoom`, `OnlinePlayer`, `OnlineTeam`, `OnlineWord`, `OnlineGameState`, `Feedback`). Local: `LocalMultipeerService` (Bonjour `_hg-hat-game`), `LocalRoomManager`, `LocalGameSyncManager`, `LocalMessage`. Depends on firebase-ios-sdk 11+. swift-tools 6.0.
- **HatGame-DesignBook** — design tokens namespace + color assets bundle. Module name stays `DesignBook`. swift-tools 6.2.

## Conventions (enforced by SwiftLint custom rules — see `.swiftlint.yml`)

This project predates / diverges from the generic personal-org house pattern. **Follow what this repo does, not the generic `AppCoordinator`/`DesignSystem` convention** from global rules:

- **Navigation:** never `NavigationLink`; never `.navigationDestination(for:)` outside the flow views' own `NavigationStack`. Navigate with `navigator.push(.somePage)` / `navigator.present(...)`, where pages are the `Page` static factories. (rules: `no_navigation_link`, `no_navigation_destination`, `no_on_tap_gesture_navigation`)
- **Design tokens:** use `DesignBook.*` (`DesignBook.Spacing.md`, `DesignBook.Color.Text.primary`, `DesignBook.Font.headline`, `DesignBook.Size.*`, also `Gradient`/`Shadow`/`Opacity`/`Motion`/`Haptics`). Never raw `.font(.system(size:))`, never raw `.white`/`.black` foreground/background. (rules: `no_inline_font`, `no_raw_*_white_black`)
- **View structure:** private view-returning `func`/computed `var` inside a `View` body get moved into a `private extension <ViewName>` block at the bottom of the file. Every `extension` is preceded by a `// MARK: -`. No empty line after a MARK or doc comment.
- **Sheets:** never `.presentationDragIndicator(...)`.
- **Misc:** trailing commas mandatory in multiline collections; no 3+ stacked unclosed `(` on one line; `Package.swift` URLs have no trailing `.git` and use `from:` not `.upToNextMajor(from:)`.

## Localization

All UI strings live in `HatGame/Localization/Localizable.xcstrings` (English + Georgian). No hardcoded user-facing strings. Use dot-notation keys (`home.title`, `wordInput.addWord`). In-app language switching is driven by `AppLanguage` / `AppConfiguration.locale` (re-renders in place).

## Important notes / gotchas

- **`README.md` and `DEVELOPMENT.md` are stale.** They claim iOS 15, Swift 5.9, "no external dependencies," and a `Managers/`/`Navigation/`/`DesignBook/` in-app layout. Reality: iOS 26, Firebase + Multipeer dependencies, three extracted packages, Swift Testing. Trust the code, not those docs — game rules live in `docs/`.
- **Commit/PR messages must NOT include AI attribution.** Ignore the `🤖 Generated with Claude Code` / `Co-Authored-By: Claude` template shown in `DEVELOPMENT.md` — it contradicts the standing no-attribution rule for personal repos. Default branch is `main`; branch and PR for non-trivial work.
- **Firebase gating:** `GoogleService-Info.plist` is committed, so online play works out of the box. Online code paths must gate on `Networking.isConfigured` / `FirebaseService.shared.isAvailable` (both require a non-empty `DATABASE_URL` in the plist) before reads/writes. Test mode: `AppConfiguration.shared.isTestMode` makes `GameManager` load `GameConfiguration.mockForTesting`.
- **Multipeer requires** `NSLocalNetworkUsageDescription`, `NSBluetoothAlwaysUsageDescription`, and `NSBonjourServices` (`_hg-hat-game._tcp`/`._udp`) — already in `Info.plist`; keep them if touching local multiplayer.
- **CI:** the only GitHub Actions workflow deploys Firebase Realtime Database rules when `database.rules.json` / `firebase.json` / `.firebaserc` change on `main`. There is no build/test CI. The `FIREBASE_SERVICE_ACCOUNT` GitHub secret is the only real secret.
- Logging uses `OSLog` with subsystem `com.khizanag.hat-game`.
