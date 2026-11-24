# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Constitution

Every screen obeys [`../iOS-Constitution/CONSTITUTION.md`](../iOS-Constitution/CONSTITUTION.md),
with this app's additions and recorded exceptions in [`CONSTITUTION.md`](./CONSTITUTION.md).
Read both before any UI change, and check a change against article 27 before calling it done.
On what a person sees, the constitution outranks the conventions below. Conforms as of the 2026-11-24 entry.

## What this is

Hat Game — a SwiftUI party game (explain words to teammates against a timer, 3 rounds). One app target plus three local Swift packages. Three independent play modes: single-device pass-and-play, online multiplayer (Firebase Realtime Database), and same-network multiplayer (MultipeerConnectivity).

Stack: SwiftUI, `@Observable` (Observation framework, never `@ObservableObject`), Swift Concurrency. All targets build in Swift 6 language mode with default `MainActor` isolation and `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES` — a warning fails the build. Bundle id `com.khizanag.hat-game`, Firebase project `hat-game-e050f`.

Multiplatform: one target supporting iOS, macOS, and visionOS — deployment target 26.0 on all three (`TARGETED_DEVICE_FAMILY` 1,2,7). Platform differences are centralized in `Extensions/CrossPlatform.swift` (`#if os(...)` view shims — inline titles, edit mode, list styles); `HatGameApp` adds macOS window sizing (560×880 phone-like default, resizable) and a native Settings scene (Cmd-,). On macOS the game flows present as a `.page`-sized sheet (see `HatGame-Navigation/Sources/Navigation/FlowNavigationView.swift`). `DEVELOPMENT_TEAM` is intentionally empty (the previous team id was wrong) — don't re-add one.

Canonical game rules (teams, the hat, 3 rounds, turns, scoring, the three modes) are documented in `docs/` — read `docs/README.md` first when behavior questions come up.

## Commands

The Xcode project has **no workspace** — it references the three packages as local SPM references, so always build with `-project` (never `-workspace`). Scheme is `HatGame`, committed as a shared scheme (`HatGame.xcodeproj/xcshareddata/xcschemes/`) that tests both test targets with app-target coverage on; the deployment target is iOS 26, so a destination on an iOS 26 simulator is required.

```bash
# Build (prefer XcodeBuildMCP tools in this environment when available).
# NOTE: a plain "iPhone 16" simulator is iOS 18.6 here; the deployment target is
# iOS 26, so use a generic destination or an iOS 26 device (iPhone 17 / 16e).
xcodebuild -project HatGame/HatGame.xcodeproj -scheme HatGame \
  -destination 'generic/platform=iOS Simulator' build

# macOS build (the target is multiplatform)
xcodebuild -project HatGame/HatGame.xcodeproj -scheme HatGame \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build

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

### Local Swift packages (repo-root siblings: `HatGame-Navigation/`, `HatGame-Networking/`, `HatGame-DesignBook/`)

Each directory and `Package.swift` name carries the `HatGame-` prefix; the library product and target names do not, so imports stay `import Navigation` / `import Networking` / `import DesignBook`.

- **HatGame-Navigation** — the navigation system; module name stays `Navigation`. `Page<Content: View>` is a typed, `id`-keyed view factory; `AnyPage` type-erases it for the stack; `Navigator` (`@MainActor @Observable`) exposes `push`/`present`/`dismiss`/`popToRoot`. App-specific destinations are static factories in `HatGame/Navigation/Page.swift` (`extension Page`). swift-tools 6.2.
- **HatGame-Networking** — both multiplayer transports; module name stays `Networking`. Online: `FirebaseService` (singleton, Realtime Database under `/rooms/$roomId`), `RoomManager`, `GameSyncManager`, and `Online*` models (`GameRoom`, `OnlinePlayer`, `OnlineTeam`, `OnlineWord`, `OnlineGameState`, `Feedback`). Local: `LocalMultipeerService` (Bonjour `_hg-hat-game`), `LocalRoomManager`, `LocalGameSyncManager`, `LocalMessage`. Depends on firebase-ios-sdk 11+. swift-tools 6.0.
- **HatGame-DesignBook** — design tokens namespace + color assets bundle. Module name stays `DesignBook`. swift-tools 6.2.

## Conventions (enforced by SwiftLint custom rules — see `.swiftlint.yml`)

This project predates / diverges from the generic personal-org house pattern. **Follow what this repo does, not the generic `AppCoordinator`/`DesignSystem` convention** from global rules:

- **Navigation:** never `NavigationLink`; never `.navigationDestination(for:)` outside the flow views' own `NavigationStack`. Navigate with `navigator.push(.somePage)` / `navigator.present(...)` / `navigator.presentSheet(...)`, where pages are the `Page` static factories; each flow's root presents the sheet (constitution article 13), so a screen never calls `.sheet` itself. (rules: `no_navigation_link`, `no_navigation_destination`, `no_on_tap_gesture_navigation`)
- **Design tokens:** use `DesignBook.*` (`DesignBook.Spacing.md`, `DesignBook.Color.Text.primary`, `DesignBook.Font.headline`, `DesignBook.Size.*`, also `Gradient`/`Shadow`/`Opacity`/`Motion`/`Haptics`). Never raw `.font(.system(size:))`, never raw `.white`/`.black` foreground/background. (rules: `no_inline_font`, `no_raw_*_white_black`)
  - Font tokens are named for the text style they scale with (`title2` scales with `.title2`); display sizes are `displayLarge/Medium/Small`, plus `heroNumber`/`heroScore`/`timer`/`roomCode`.
  - Contrast: every colorset ships Any, Dark, and High Contrast; text ≥ 4.5:1. Team colors never tint text directly — use `DesignBook.Color.teamText(for:)`; raw team colors are for fills, dots, and rings. Prominent buttons tint with `Status.successFill`/`errorFill`; `Status.success`/`warning`/`error` are for text and glyphs. `DesignBook.Contrast` has the math.
- **Human Interface Guidelines (checked against the HIG on 2026-11-16 — keep it that way):**
  - Bottom actions use `.actionBar { … }` (system `safeAreaBar` + soft scroll edge; inline at the end of content on macOS) with **at most two buttons**; tertiary actions go in the toolbar. Never a hand-rolled gradient or opaque footer.
  - Modals close with `CloseToolbarItem { … }` (leading, `role: .close`, Esc); sheet forms confirm with `ConfirmToolbarItem(title:canConfirm:action:)` (trailing) — never a floating button over the form. No `.plain`/tinted/`foregroundStyle` toolbar items. Toolbar actions are symbols, written `Label(title, systemImage:)` + `.help(title)` so the title still reaches VoiceOver, the tooltip, and toolbar customization; text only where no symbol says it (Edit, Give Up, a sheet's confirm). Leaving a flow is the standard Close (`CloseToolbarItem(accessibilityLabel:)`), confirming when progress is at stake — never a text End/Leave item. A text item and a symbol item in the same corner are split by `ToolbarSpacer(.fixed, …)`.
  - Intentional exits confirm with `.confirmationDialog` and offer the non-destructive option (Save and Exit, Keep Editing); `.alert` is for unexpected conditions and `errorAlert` requires a specific `title:` — never "Error". Input that would be lost on close → `.interactiveDismissDisabled(hasChanges)` + discard confirmation.
  - Text fields use `.hatFieldStyle(label:…)` (whole box tappable, ≥ 44 pt, real VoiceOver label, keyboard/content type). Validate on submit or focus-leave, not per keystroke. In-content icon buttons are ≥ 44 pt with a label that names the target.
  - Multiplayer session pages hide the system back button; the only exit is the Leave control in `MultiplayerSessionView`, which confirms and calls `leaveRoom()`. Back must never leave a player silently in a room.
  - Haptics follow constitution article 23: only `.haptic(_:trigger:when:)` (`Extensions/View+Haptic.swift`, a `.sensoryFeedback` that honours the Haptics setting) on the view whose state changed. Got It and adding or saving = `.success`, Skip and any pick or take-back = `.selection`, a confirmed delete, discard, end, or give-up = `.warning`, a refused entry or failed action = `.error` (`errorAlert` plays it). Nothing on navigation, appear, timers (countdown, time-up), or changes the person didn't make; nothing on top of a system control's own.
  - Liquid Glass is for controls and navigation, never content. A card that only shows content is a `GameCard`; a card that is itself a control — it opens a mode, picks a choice, or folds open — is glass: `.buttonStyle(.glassCard)` when the whole card is the button (`.glassCard(selection:)` tints and rings the picked choice), a card that reveals reading content when it folds open (`FoldableCard`) stays an opaque `GameCard` with a plain header row. A callout or banner is the shared `Callout(tone:)` (tinted system glass). Never a `.plain` button over an opaque card standing in for a button. In-content controls use system glass, not hand-drawn capsules or circles: `glassButtonStyle()` / `glassProminentButtonStyle()` (capsule chips: `.buttonBorderShape(.capsule)` + `.controlSize(.large)`), round icon buttons `glassIconButtonStyle(isProminent:)`, floating surfaces `glassSurface(in:)`. Neighbouring glass controls share a `GlassContainer`; a control that turns into another morphs with `glassMorphID(_:in:)` inside one container. Never dim glass with `.opacity` (disabled glass styles itself). A sheet at a partial detent sets `.environment(\.showsScreenBackground, false)` so the system glass shows through.
  - Georgian has no case: never `.textCase(.uppercase)` directly — use `eyebrowUppercase()`.
  - Turn keyboard: → Got It, ← Skip, Esc pause/resume on single-device play (online turns have no pause; Esc there is Give Up). The in-app Language and Color Scheme settings deliberately duplicate system settings (one shared party device).
- **View structure:** private view-returning `func`/computed `var` inside a `View` body get moved into a `private extension <ViewName>` block at the bottom of the file. Every `extension` is preceded by a `// MARK: -`. No empty line after a MARK or doc comment.
- **Sheets:** never `.presentationDragIndicator(...)` — the system shows the grabber on multi-detent sheets. View-only sheets offer `[.medium, .large]`.
- **Misc:** trailing commas mandatory in multiline collections; no 3+ stacked unclosed `(` on one line; `Package.swift` URLs have no trailing `.git` and use `from:` not `.upToNextMajor(from:)`.

## Testing Lab (debug builds)

The [TestingLab](https://github.com/Khizanag/TestingLab-iOS) package (remote, `from: 1.1.0`, everything inside `#if DEBUG`) is the developer screen. Hat Game's part lives in `View/TestingLab/`: `HatGameBuildNotes` (this build's changes; rewrite it for every build handed over for testing), `HatGameLabSections` (the app's tools), and `LabRoutes` (where notes and shortcuts go, on the app's **root** navigator).

- **Hosts:** a sheet can't open over a full-screen flow from below it, so the lab is hosted on Home (`.hatGameTestingLab(isRoot: true)`, which stands aside while a flow is presented) and on the root of each flow view (`GameFlowView`, `OnlineFlowView`, `LocalFlowView`, outside the flow's own navigator). A new full-screen flow gets `.hatGameTestingLab()` the same way.
- **Ways in:** shake (iOS), Settings ▸ Developer Info ▸ Testing Lab (every platform), ⌥⌘T (macOS menu), `-openTestingLab YES` at launch.
- **Routes:** opening a flow leaves the stack alone. Popping the stack while a flow zooms open crashes UIKit's zoom transition.
- The lab is English only and kept out of the String Catalog: wrap its text in `lab("…")` or `Text(verbatim:)`.

## Localization

All UI strings live in `HatGame/Localization/Localizable.xcstrings` (English + Georgian). No hardcoded user-facing strings. Use dot-notation keys (`home.title`, `wordInput.addWord`). In-app language switching is driven by `AppLanguage` / `AppConfiguration.locale` (re-renders in place).

## Important notes / gotchas

- **`README.md` and `DEVELOPMENT.md` are current** (updated 2026-11-16): product overview and the longer technical reference. When code and docs disagree, trust the code and fix the doc — game rules live in `docs/`.
- **A turn never scrolls at the default text size.** The word card takes the height the turn leaves it (`wordCardFrame()`, between `wordCardMinHeight` and its square-ish shape), so the turn fits one screen. A fixed aspect ratio made it a little taller than an iPhone, and `ViewThatFits` fell back to its `ScrollView`, which the owner sent back. The scroll stays only for accessibility sizes (article 15).
- **Commit/PR messages must NOT include AI attribution.** Solo repo: commit directly to `main` and push — no feature branches or PRs.
- **App Store configuration:** `HatGame/PrivacyInfo.xcprivacy` declares the `UserDefaults` reason (`CA92.1`) and the data sent to Firebase — update it when the app sends anything new. `HatGame/InfoPlist.xcstrings` localizes the display name and permission prompts (en + ka). Alternate icons compile via `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` (iOS SDKs only); never hand-write `CFBundleIcons` in `Info.plist`. Icon PNGs must have no alpha channel — `swift Scripts/flatten-icons.swift <png>...`.
- **Firebase gating:** `GoogleService-Info.plist` is committed, so online play works out of the box. Online code paths must gate on `Networking.isConfigured` / `FirebaseService.shared.isAvailable` (both require a non-empty `DATABASE_URL` in the plist) before reads/writes. Test mode (a Testing Lab switch): `AppConfiguration.shared.isTestMode` makes `GameManager` load `GameConfiguration.mockForTesting`.
- **Multipeer requires** `NSLocalNetworkUsageDescription`, `NSBluetoothAlwaysUsageDescription`, and `NSBonjourServices` (`_hg-hat-game._tcp`/`._udp`) — already in `Info.plist`; keep them if touching local multiplayer.
- **CI:** `.github/workflows/ci.yml` runs on push to `main` (and on demand): `swiftlint --strict`, `HatGameTests` on an iOS 26 iPhone simulator, using the newest runner Xcode 26 that has one installed, and an unsigned macOS build. `firebase-database-rules.yml` deploys Realtime Database rules when `database.rules.json` / `firebase.json` / `.firebaserc` change on `main`. The `FIREBASE_SERVICE_ACCOUNT` GitHub secret is the only real secret.
- Logging uses `OSLog` with subsystem `com.khizanag.hat-game`.
