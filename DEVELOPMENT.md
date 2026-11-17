# Development Guide

Technical reference for the Hat Game project — architecture, conventions, and workflows. For product-level rules and quick start, see [README.md](README.md). For the condensed agent reference, see [CLAUDE.md](CLAUDE.md).

> Last updated: 2026-11-16.

## Technical stack

- **Platforms:** one multiplatform target for iOS, macOS, and visionOS, deployment target 26.0 on all three. Platform differences live in `Extensions/CrossPlatform.swift`.
- **UI:** SwiftUI, Observation framework (`@Observable` — never `@ObservableObject`).
- **Concurrency:** Swift Concurrency (`async`/`await`, `@MainActor`); app target builds in Swift 5 language mode with approachable concurrency enabled, packages use swift-tools 6.x.
- **Persistence:** `UserDefaults` for settings; Firebase Realtime Database for online rooms; no local database.
- **Dependencies:** Firebase iOS SDK only (via the `Networking` package). Everything else is first-party.

## Architecture

### Three play modes

The folder layout under `View/` mirrors three independent modes. Identify a view's mode before changing it.

| Mode | Entry flow view | Screens | State managers |
|---|---|---|---|
| Pass-and-play | `View/Game/GameFlowView` | `View/Setup`, `View/Play` | `GameManager` |
| Online (Firebase) | `View/Online/OnlineFlowView` | `View/Online` | `RoomManager`, `GameSyncManager` |
| Nearby (Multipeer) | `View/Local/LocalFlowView` | `View/Local` (+ reuses `View/Online`) | `LocalRoomManager`, `LocalGameSyncManager` |

### Per-flow navigation and dependency injection

Each mode's `*FlowView` is the composition seam. It:

1. Creates its own `Navigator()` and the mode's managers as `@State` — fresh per launch.
2. Hosts a `NavigationStack` bound to `navigator.navigationPath`.
3. Injects those objects into the environment for the whole subtree with `.environment(...)`.

`HatGameApp` injects only an app-level `RoomManager`/`GameSyncManager` plus `AppConfiguration.locale`; the live per-game state is owned by the flow views, not globally. Child views read what they need with `@Environment(GameManager.self)`, `@Environment(Navigator.self)`, and so on. There is no global mutable game state.

### Nearby multiplayer reuses online views via subclassing

`LocalRoomManager: RoomManager` and `LocalGameSyncManager: GameSyncManager` — the base classes are `open` in the `Networking` package. `LocalFlowView` injects the subclasses upcast to the base types (`.environment(roomManager as RoomManager)`), so the entire `View/Online` gameplay surface (`OnlineGameFlowView`, `OnlinePlayView`, results screens, …) runs unchanged over a Multipeer transport instead of Firebase.

**Consequence:** when editing an online gameplay view, keep it transport-agnostic — it also drives nearby play. Behavior that must differ belongs behind the manager API, overridden in the `Local*` subclass.

### Single-device game engine

`GameManager` (`Manager/GameManager.swift`, `@Observable`) owns all pass-and-play logic:

- Round iteration over `GameConfiguration.rounds` (`.first`, `.second`, `.third`).
- Team rotation and explainer-role locking.
- The word pool (`remainingWords`, `currentWord`) and skipping.
- Per-team remaining-time tracking and preservation across rounds.

It **owns** `HistoryManager` as a `let` (reached via `gameManager.historyManager`, not injected separately). `HistoryManager` tracks guessed words per team per round and computes scores and rankings.

`GameConfiguration` (`@Observable`, reference type) holds one game's settings and data (teams, words, durations). Defaults come from `AppConfiguration.shared` unless overridden. Test mode swaps in `GameConfiguration.mockForTesting`, which must stay a fresh value per access (see the regression note in the type).

Supporting single-device managers: `WordDatabase` (bundled quick-fill words), `SoundPlayer`, `TeamDefaultColorGenerator`, `TeamNameSuggestions`, `FeedbackService`.

### Local Swift packages

Three packages live as siblings of the app and are referenced as local SPM packages (no workspace).

- **Navigation** (swift-tools 6.2) — the navigation system. `Page<Content: View>` is a typed, `id`-keyed view factory; `AnyPage` type-erases it for storage in the stack; `Navigator` (`@MainActor @Observable`) exposes `push` / `present` / `dismiss` / `popToRoot` / `replace`. App destinations are static factories in `HatGame/Navigation/` (`extension Page`).
- **Networking** (swift-tools 6.0, depends on firebase-ios-sdk 11+) — both multiplayer transports.
  - Online: `FirebaseService` (singleton over Realtime Database at `/rooms/$roomId`), `RoomManager`, `GameSyncManager`, and the `Online*` models (`GameRoom`, `OnlinePlayer`, `OnlineTeam`, `OnlineWord`, `OnlineGameState`, `Feedback`).
  - Nearby: `LocalMultipeerService` (thin `MultipeerConnectivity` wrapper, Bonjour service `hg-hat-game`), `LocalRoomManager`, `LocalGameSyncManager`, `LocalMessage`.
- **DesignBook** (swift-tools 6.2) — the `DesignBook` token namespace plus a bundled color asset catalog.

One remote package: [TestingLab](https://github.com/Khizanag/TestingLab-iOS) (`from: 1.1.0`), the debug-only developer screen shared by the personal apps. Release builds contain none of it.

## Navigation

Banned in feature code (enforced by SwiftLint): `NavigationLink`, and `.navigationDestination(for:)` anywhere except a flow view's own `NavigationStack`. Navigate instead through the `Navigator` in the environment:

```swift
@Environment(Navigator.self) private var navigator

navigator.push(.wordInput)            // push onto the stack
navigator.present(.feedback)          // full-screen presentation
navigator.dismiss()                   // pop the presented flow
```

Destinations are `Page` factories. Add a screen by adding a factory to `extension Page` (in `HatGame/Navigation/`) and pushing it — no central switch to update:

```swift
static func nextTeam(round: GameRound, team: Team) -> Page<NextTeamView> {
    Page<NextTeamView>(id: "nextTeam-\(round.rawValue)-\(team.id)") {
        NextTeamView(round: round, team: team)
    }
}
```

## Design system

All visual values come from the `DesignBook` namespace. Never hardcode a font size, color literal, or spacing value in feature code.

```swift
.padding(DesignBook.Spacing.md)
.foregroundStyle(DesignBook.Color.Text.primary)
.font(DesignBook.Font.headline)
```

Token categories: `Color`, `Font` (Typography), `Spacing`, `Size`, `Shadow`, `Opacity`, `Gradient`, `Motion`, `Haptics`. Reusable UI lives in `View/Component/`; components stay generic and free of business logic.

## State management

- **Managers / view models:** `@Observable` classes, injected via `.environment(...)` and read with `@Environment(Type.self)`.
- **View-local state:** `@State`, `@FocusState`.
- **Ownership:** views own UI state; managers own game state. Pass dependencies down the environment, scoped to the flow that creates them.

## Conventions

This project uses its own `Navigator` / `Page` / `DesignBook` patterns. Follow them — do not migrate toward a generic coordinator or `DesignSystem` pattern. `swiftlint lint --strict` must pass with zero violations; the custom rules in `.swiftlint.yml` encode the house style:

- Navigation: `no_navigation_link`, `no_navigation_destination`, `no_on_tap_gesture_navigation`.
- Design tokens: `no_inline_font`, `no_raw_foreground_white_black`, `no_raw_background_white_black`.
- View structure: private view-returning `func`/`var` move into a `private extension <ViewName>` block at the bottom of the file; every `extension` is preceded by a `// MARK: -`; no blank line after a MARK or doc comment.
- Sheets: no `.presentationDragIndicator`.
- Package files: no trailing `.git` in URLs, `from:` over `.upToNextMajor(from:)`.
- General: trailing commas mandatory in multiline collections; avoid `!` force-unwraps; descriptive `is`/`has`/`should` booleans; MARK-organized files.

## Localization

UI strings live in `HatGame/Localization/Localizable.xcstrings` (English and Georgian). No hardcoded user-facing strings. Use dot-notation keys (`home.title`, `wordInput.addWord`, `gameRound.first.description`). In-app language selection runs through `AppLanguage` and `AppConfiguration.locale`, which re-renders views in place.

## Testing

- **Unit tests** (`HatGameTests`) use the **Swift Testing** framework — `@Test`, `#expect`, `#require`, `@MainActor` suites. Not XCTest.
- **UI tests** (`HatGameUITests`) use XCUITest.
- **Testing Lab (debug builds):** shake the device (Device ▸ Shake in the simulator), tap Settings ▸ Developer Info ▸ Testing Lab, press ⌥⌘T on a Mac, or launch with `-openTestingLab YES`. It lists this build's changes, each of which can jump to its screen, and has the app's tools: a started quick game, Test Mode, the gameplay switches, language and appearance, the multiplayer setup, and every top-level screen. `View/TestingLab/` holds Hat Game's part; rewrite `HatGameBuildNotes` for each build handed over for testing.
- **Test mode:** a switch in the Testing Lab. `GameManager` then loads `GameConfiguration.mockForTesting` (two ready teams and words), skipping manual setup.

Run a single test by target/suite/function:

```bash
xcodebuild ... test -only-testing:HatGameTests/HatGameTests/skippingDisabledKeepsCurrentWord
```

## Multiplayer specifics

- **Firebase config gating:** online code must check `Networking.isConfigured` (or `FirebaseService.shared.isAvailable`) before any read/write. Both require a non-empty `DATABASE_URL` in `GoogleService-Info.plist`; without it the SDK fails silently. `Networking.configure()` runs at launch and logs actionable diagnostics if the plist or URL is missing.
- **Room codes:** six characters from `A–Z` / `2–9` (no ambiguous `0`/`1`/`O`/`I`). The database security rules in `database.rules.json` validate this shape.
- **Nearby requirements:** `Info.plist` must keep `NSLocalNetworkUsageDescription`, `NSBluetoothAlwaysUsageDescription`, and `NSBonjourServices` (`_hg-hat-game._tcp` / `._udp`). Removing them breaks discovery.
- **Logging:** `OSLog` with subsystem `com.khizanag.hat-game`.

## App Store configuration

- **Privacy manifest:** `HatGame/HatGame/PrivacyInfo.xcprivacy` declares the `UserDefaults` reason (`CA92.1`) and the data sent to Firebase. Update it, and the App Privacy answers in App Store Connect, whenever the app sends something new.
- **Permission prompts and display name:** localized in `HatGame/HatGame/InfoPlist.xcstrings` (English and Georgian).
- **App icons:** the primary `AppIcon` carries iOS and macOS sizes. The four alternates are iOS-only and compile through `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`; actool writes `CFBundleIcons`, so never add it to `Info.plist` by hand. Icons must have no alpha channel — run `swift Scripts/flatten-icons.swift <png>...` on new artwork.
- **Export compliance:** `ITSAppUsesNonExemptEncryption = NO` is set as a build setting.

## Build and run

No `.xcworkspace` — build with `-project` (local packages resolve automatically). The shared scheme `HatGame` is committed; it tests `HatGameTests` and `HatGameUITests` and gathers coverage for the app target. Use an iOS 26 destination.

```bash
xcodebuild -project HatGame/HatGame.xcodeproj -scheme HatGame \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

xcodebuild -project HatGame/HatGame.xcodeproj -scheme HatGame \
  -destination 'platform=iOS Simulator,name=iPhone 17' test

xcodebuild -project HatGame/HatGame.xcodeproj -scheme HatGame \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build

swiftlint lint --strict
```

## Git workflow

- Imperative commit subjects under ~72 characters; explain the *why* in the body only when non-obvious.
- **No AI attribution** in commits or PRs — no "Generated with" footers, no `Co-Authored-By` trailers.
- Solo repo: commit directly to `main` and push. No feature branches or PRs.
- Commit `GoogleService-Info.plist` (it is not a secret); the only sensitive value is the `FIREBASE_SERVICE_ACCOUNT` GitHub Actions secret used to deploy database rules.

## Continuous integration

Two GitHub Actions workflows:

- `.github/workflows/ci.yml` — on push to `main` and on demand: `swiftlint lint --strict`, `HatGameTests` on an iOS 26 simulator with the newest Xcode 26, and an unsigned macOS build.
- `.github/workflows/firebase-database-rules.yml` — deploys `database.rules.json` to Firebase when it changes on `main`.
