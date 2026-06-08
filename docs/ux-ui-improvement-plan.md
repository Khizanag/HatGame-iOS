# UX/UI Improvement Plan

A research-backed roadmap for elevating Hat Game from a well-built app to an Apple-Design-Award-grade party game. It is organized as phases so it can be delivered incrementally — each phase ships value on its own.

## How this was researched

Five specialist passes audited the real codebase in parallel — onboarding and setup, gameplay and game feel, the visual system and Liquid Glass, multiplayer UX, and accessibility and localization — then the findings were reconciled, fact-checked against the code, and prioritized through an iOS 26 Human Interface Guidelines lens. Recommendations cite the actual files and components.

> Note on grounding: the analysis is code-based, plus visual confirmation of Home, Settings, Defaults, and App Icon (captured with `Scripts/snapshot.sh`). Gameplay and multiplayer screens have not yet been visually captured — extending the snapshot harness to those screens (via the existing test mode) is recommended as the first verification step, and is itself listed below.

## Where the app stands today

The foundation is genuinely strong, and the plan builds on it rather than replacing it:

- **Design-token discipline** is excellent through the core gameplay loop — `DesignBook` colors, fonts, spacing, motion, and haptics are used semantically.
- **Haptics and motion are first-class** — twelve named haptic events, four named springs, and a `respectingReducedMotion` utility.
- **Reduce Motion is consistently honored** across the main game loop, and the two most important materials have Reduce Transparency fallbacks.
- **Liquid Glass is placed correctly in gameplay** — glass on the action buttons, opaque content on the word card.
- **Settings was just rebuilt natively** (inset-grouped `List` with menu pills) and is the reference pattern for the rest of the app.
- **Georgian localization is essentially complete** (395 of 404 keys translated).

The gaps are not structural — they are about **party-game speed**, **dramatic moments**, **multiplayer resilience**, **visual cohesion at the edges** (Setup and Online flows lag the polished core), and **finishing the accessibility commitments the app already makes**.

## Guiding direction

Three principles should steer every change:

1. **Party speed.** A party game lives or dies on time-to-first-word and time-to-rematch. Remove every non-essential tap between "let's play" and "go."
2. **Earn the drama.** The game's identity is the round-rule shift (describe → one word → mime) and the moment the hat empties. These beats currently pass almost silently. Give them ceremony.
3. **Cohesive Liquid Glass.** Keep extending the iOS 26 grammar already used well in gameplay: **glass on controls and navigation, brand color and gradients on the content layer, restraint everywhere.** The Setup and Online flows should be brought up to the standard the core loop and Settings already set.

Accessibility is not a phase to bolt on — it is a constraint on every item. Several of the highest-value quick wins below are accessibility fixes.

## The ten highest-leverage moves

| # | Move | Phase | Effort |
|---|---|---|---|
| 1 | Fix the empty `common.error` key (error alerts currently render the literal text "common.error") | 0 | S |
| 2 | Make the game playable with VoiceOver — add Got It / Skip accessibility actions to the word card | 0 | S |
| 3 | Gate the six repeating `symbolEffect` pulses behind Reduce Motion | 0 | S |
| 4 | "Quick Start" — one tap from Home to a sensible-default game | 1 | M |
| 5 | Pass-the-phone privacy interstitial during manual word entry (words are supposed to be secret) | 1 | M |
| 6 | Same-teams **and same-words** rematch from the results screen | 1 | M |
| 7 | Round-transition ceremony that reveals the new rule (the game's signature beat) | 2 | M |
| 8 | Decouple celebration from "time up" + a signature "hat emptied" win moment | 2 | M |
| 9 | Multiplayer resilience: disconnect detection, connect-timeout escape, Local Network permission surfacing | 3 | S–M |
| 10 | Shareable post-game result card (`ImageRenderer` + `ShareLink`) | 6 | M |

## Phase 0 — Correctness and polish fixes

Small, high-confidence fixes for real defects. Ship first.

| Item | Where | Fix |
|---|---|---|
| Error alerts show the raw key | `common.error` has no en/ka value; used as alert titles across Online views | Add localized en + ka values (e.g. "Something went wrong"). |
| VoiceOver users cannot play | `WordCard` is one button with only a hint; the swipe is invisible to VoiceOver | Add `.accessibilityAction(named:)` for Got It and Skip (gate Skip on `isSkipEnabled`). |
| Repeating pulses ignore Reduce Motion | `GamePausedOverlay`, `LocalRoomBrowser`, `OnlineWaitingView`, `OnlineSpectatorView`, `RoomLobbyView`, `RandomizationView`, `LocalSessionView`, `OnlineGameFlowView` | Pass `isActive: !reduceMotion` to each `.symbolEffect(..., .repeating)`. |
| Online turn/round screens brick on a failed write | `try?` swallows errors in `OnlineNextTeamView`, `OnlineTurnResultsView`, `OnlineRoundResultsView`; `isLoading` never resets | Use `do/catch`, reset `isLoading` in `catch`, surface a retry alert. |
| Timer keeps "breathing" while paused | `CircularTimerView` urgency `scaleEffect` keyed only on `isUrgent` | Gate on `isUrgent && !isPaused && !reduceMotion`. |
| Confetti is stale on re-entry | `ConfettiView` one-shot; returning from the standings sheet shows no confetti | Add a `retriggerId` and reset each piece `.onChange`. |
| Settings reset on re-visit | `WordSettingsView` / `TimerSettingsView` load defaults in `.onAppear`, overwriting edits when popped back to | Initialize `@State` from `AppConfiguration` directly. |
| Non-button tap target | `RandomizationView` team row uses `.onTapGesture` (also a SwiftLint violation) | Wrap in a `Button { ... }.buttonStyle(.plain)`. |
| Guest empty-teams state is blank | `lobby.noTeams.guest` is missing, so guests who arrive first see nothing | Add the key: "Waiting for the host to add teams." |
| Pause button announces the wrong thing | `GameView` toolbar label says "paused" while running | Announce the action ("Pause" / "Resume"). |
| Silent word-load failure | `OnlinePlayView` shows a blank card if `getWords()` throws | Add an error state with a "Try again" action. |
| Literal-key `Text` bypasses in-app language switch | `TeamSetupView` edit toggle, `RoomLobbyView` leave message and "leave team", etc. use `Text("some.key")` instead of `localized(...)` | Route through `localized(...)` so the in-app language toggle applies. |

## Phase 1 — Party-game speed (setup friction)

The single-device setup is six sequential screens before the first word. For a party game, that is the biggest UX liability.

| Item | Impact | Effort | Detail |
|---|---|---|---|
| **Quick Start** | High | M | A primary action on Home that applies sensible defaults (2 teams, 2 players, 10 words, 60 s, automatic words) and jumps straight to Randomization after team naming. The biggest single cut to time-to-first-word. |
| **Pass-the-phone privacy interstitial** | High | M | Manual word entry currently flashes the previous player's words during handoff. Insert a "Pass to [Name] — don't peek" cover screen with an "I'm ready" button between players. This is a *correctness* issue: the words are meant to be secret. |
| **Same-teams + same-words rematch** | High | M | `resetForNewGame()` clears words, forcing full re-entry. Snapshot the last word list and offer "Play again (same words)" alongside "Play again (new words)." |
| **Collapse Word + Timer settings** | Med | S–M | Merge into one "Game Rules" screen (words-per-player and timer side by side). Removes a mandatory screen and a hop. |
| **Setup progress indicator** | Med | S | A compact step indicator across the setup screens so users can orient and see the end is near. |
| **Players-per-team control** | Med | M | `playersPerTeam` is hardcoded to 2 and invisible. Expose a 2–6 stepper on Team Setup before teams are created. |
| **Expand How-to-Play on first launch** | Low | S | Default the Home instructions card open on genuine first run (track via `@AppStorage`), then auto-collapse. |

## Phase 2 — Game feel and drama

Amplify the moments that make the game memorable.

| Item | Impact | Effort | Detail |
|---|---|---|---|
| **Round-transition ceremony** | High | M | The describe → one-word → mime shift is the entire game design, yet it happens invisibly. Add a brief full-screen reveal of the new round's rule (animated icon + large rule text), optionally with a per-round gradient tint. |
| **Decouple celebration from "time up"** | High | M | A team that guessed 8/10 then ran out of time gets the same sad hourglass as a team that guessed nothing. Celebrate whenever `guessedWords.count > 0`; reserve the bare state for zero. |
| **Signature "hat emptied" moment** | High | M | The peak beat — last word guessed — fires a single haptic. Give it a team-color confetti burst + a choreographed triple-pulse haptic + the chime. |
| **Mid-game standings** | High | M | Players can't see who's ahead. Add an inline mini-standings (team dots + scores) to `NextTeamView` from `getSortedTeamsByTotalScore()`. |
| **Countdown tick sound** | High | S | The 3/2/1 s urgency is haptic-only and inaudible in a noisy room. Add a short tick at each, gated by the existing sound setting. |
| **Readable timer** | High | S | `MM:SS` always shows `00:NN` for sub-minute turns. Render bare seconds when `totalSeconds < 60` so the hero numeral is larger and scannable. |
| **Per-word success feedback** | High | M | Add a score-badge pulse and a checkmark `symbolEffect` on Got It so the explainer sees confirmation before the card exits. |
| **Score-reveal staging** | Med | M | On results, stage trophy → winner name → counting score rather than revealing all at once. |
| **Prepared haptics** | Low | S | Cache and `prepare()` the impact generators at turn start to remove the ~10 ms latency on every "Got It." |
| **Pause overlay entrance** | Low | S | Add a scale+opacity entrance with a slight stagger using `DesignBook.Motion`. |

## Phase 3 — Multiplayer resilience

Online and nearby work in the happy path but strand users when anything goes wrong.

| Item | Impact | Effort | Detail |
|---|---|---|---|
| **Disconnect / host-left detection** | High | S | `RoomManager.isConnected` flips false but no view observes it; guests spin forever when the host leaves. Add an `.onChange` alert with "Return to menu." |
| **Connect/join timeout escape** | High | M | The joining and connecting spinners have no timeout. Add a ~15 s "Something went wrong — retry" with an escape route. |
| **Local Network permission surfacing** | High | M | Nearby browsing fails silently if permission is denied. Surface a `ContentUnavailableView` with a "Check Settings" link. |
| **Active-player-backgrounded fallback** | High | M | If the explainer backgrounds the app at turn results, everyone waits forever. Add a host nudge / auto-advance after a timeout. |
| **Per-host connect state + timeout** | Med | M | `LocalRoomBrowser` disables the whole list on one tap with no timeout. Make it per-host with a 15 s reset and inline error. |
| **Actionable, localized errors** | Med | M | `RoomError`/`NetworkingError` strings are English and developer-facing. Localize (en + ka) and add a next step per case. |
| **Edit words after submit** | Med | M | `OnlineWordInputView` makes submitted words permanent. Add an "Edit words" path before the game starts. |
| **Rejoin after crash/dismiss** | Med | L | Use the stable `deviceId` to re-attach instead of rejecting non-`waiting` rooms; offer "Rejoin last game." |
| **Pull-to-refresh nearby browser** | Low | S | Add `.refreshable` to re-scan for hosts. |
| **Reconnecting banner** | Med | M | Show a discreet "Reconnecting…" banner during play when the listener drops, instead of looking functional while stale. |

## Phase 4 — Visual cohesion and design system

Bring the edges up to the core's standard and tighten the token system.

| Item | Impact | Effort | Detail |
|---|---|---|---|
| **Inline-font sweep** | High | M | ~27 unsuppressed `.font(.system(size:))` sites in Online/Setup approximate existing tokens. Map each to a token; add named `heroDisplay` / `monospaceDisplay` tokens for the genuinely unique ones; fix the `IconFont.large` (32pt) vs emoji-size naming mismatch. |
| **Hero card radius token** | High | S | The word card and its placeholder hardcode `cornerRadius: 32` (a third radius value, also repeated in `OnlinePlayView`). Add `Size.heroCardCornerRadius` and use it. |
| **Celebration colors → tokens** | High | S | `ResultsView`/`OnlineResultsView` rebuild the celebration gradient's gold/coral as `Color(red:...)` literals. Expose `Color.Celebration.gold/coral` from `Gradient.celebration`. |
| **Adaptive shadows** | Med | M | `Shadow.small/medium/large` use opaque black, invisible on dark backgrounds. Make them adaptive (or use label color) so cards keep depth in dark mode. |
| **Fix `Shadow.accent`** | Med | S | It is a hardcoded cold blue that clashes with the purple gradient end. Base it on `Color.Text.accent`. |
| **`GameCard` continuous corners** | Med | S | Replace deprecated `.cornerRadius()` (circular) with `.clipShape(RoundedRectangle(... style: .continuous))` to match every other card. |
| **`NavigationCard` press feedback** | Med | M | `.plain` on an opaque card gives no press state. Use `.glass` so controls read as controls (glass = control layer). |
| **`FoldableCard` motion** | Med | S | Replace bare `.easeInOut` with a `DesignBook.Motion` token gated by Reduce Motion. |
| **Typography naming** | Med | M | `callout` (22pt) is larger than `headline` (20pt), inverting Apple's mental model. Rename and document the scale top-to-bottom. |
| **Cohesive glass grammar** | Med | M | Use `GlassEffectContainer` for related control pairs (as `RoomLobbyView` already does for copy/share) and apply the "glass control floats over brand content" pattern consistently across lobbies and Home. |
| **Per-round gradient tints** | Med | S | Add `Gradient.round1/2/3` to power the round-transition ceremony and subtly tint each round's screens. |

## Phase 5 — Accessibility completion and reach

Finish the commitments the app already makes, then extend reach.

| Item | Impact | Effort | Detail |
|---|---|---|---|
| **Dynamic Type on the word card** | High | M | The hero word is a fixed 56pt that *shrinks* (not grows) for large-text users. Use `@ScaledMetric` relative to `.largeTitle`. |
| **Dynamic Type across Online** | Med | M | Nine Online screens use fixed `.system(size:)` for room codes, the active word, and score reveals. Map to tokens or `@ScaledMetric`. |
| **Missing labels/titles** | Med | S | `GameProgressFooter` has no VoiceOver label; `TeamTurnResultsView`/`NextTeamView` have no `navigationTitle` (announced blank). Add both. |
| **`onAccent` contrast token** | Med | S | Replace literal `.white` on team-colored badges/trophies (fails contrast on light team colors) with an adaptive `Color.onAccent`. |
| **Reduce Transparency fallback** | Med | S | `WordInputView`'s `.ultraThinMaterial` card needs the opaque fallback already used in `GamePausedOverlay`. |
| **VoiceOver game narration** | Med | M | Post `.announcement`s at state transitions and at the 3/2/1 countdown, so the game is followable without sight. A genuine delight + inclusion win. |
| **Color-blind team cues** | Med | M | Add a secondary shape cue (alongside color) to team indicators so red/green teams are distinguishable. |
| **Third language** | Med | M | The catalog is clean and the pipeline proven — Russian is the highest-ROI next language for the audience. |

## Phase 6 — Growth and ambition

Higher-effort moves that drive retention and virality.

| Item | Impact | Effort | Detail |
|---|---|---|---|
| **Shareable result card** | High | M | Composite the winner + scores into an image (`ImageRenderer`) with a `ShareLink`. The single highest-leverage viral loop; the visual ingredients already exist. |
| **Per-player stats / MVP** | Med | M | Track explainer performance to surface a "MVP: [name], 12 words" line on results — social texture and bragging rights. |
| **QR + deep-link join** | Med | M | A `hatgame://join?code=…` Universal Link and a QR code in the lobby remove all typing for same-room joins. |
| **Streak / comeback narrative** | Med | M | A hot-streak indicator and "2 words from the lead" micro-labels add in-game tension from data already held. |
| **Live presence in the lobby** | Med | M | Avatar chips that spring in/out as players join/leave make the lobby feel alive. |
| **Nearby host-row game preview** | Low | S | Advertise words/duration/skip in `discoveryInfo` so guests see the rules before joining. |

## Recommended first sprint

A two-week slice that ships visible quality fast and de-risks the rest:

1. **All of Phase 0** — these are defects, mostly small, and several are accessibility-critical.
2. **Quick Start + same-words rematch + pass-the-phone interstitial** (Phase 1) — the three biggest party-speed wins.
3. **Round-transition ceremony + decoupled celebration + tick sound + readable timer** (Phase 2) — the game finally *feels* like the game it is.
4. **Disconnect detection + connect timeout** (Phase 3) — stops multiplayer sessions from silently dying.

Then alternate a "feel/feature" phase with a "foundation" phase (4/5) so visible delight and underlying quality advance together.

## Verifying as you go

The snapshot harness (`Scripts/snapshot.sh` / `--verify`) is the natural quality gate for this work: capture a baseline before a change, make it, and diff. Extending the `-uiTestScreen` hook to deep-link gameplay and results screens (via the existing test mode and `GameConfiguration.mockForTesting`) is a small task that unlocks visual regression coverage for every item in Phases 2, 4, and 5 — worth doing early.
