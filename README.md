# Hat Game (iOS)

A SwiftUI party game. Players explain words to their teammates against a timer across three rounds. Play on one device passed around the room, online with friends anywhere, or with people on the same Wi-Fi network.

> For technical detail and conventions, see [DEVELOPMENT.md](DEVELOPMENT.md). For an agent-oriented quick reference, see [CLAUDE.md](CLAUDE.md).

## Game rules

### Setup

1. Create teams (default 2 players each, configurable; 2–6 teams).
2. Provide words — either each player types their own, or the host fills them automatically from the bundled word database. Default 10 words per player.
3. Start the game with the first team.

### A turn

1. One player on the active team explains; teammates guess.
2. A correct guess marks the word and reveals the next one.
3. Skipping the current word is allowed by default (configurable per game).
4. The turn ends when the timer runs out (default 60 seconds) or the hat is empty.

### Rounds

The same words are played three times, each round with a different explaining style (describe, then a shorter hint, then mime). Teams rotate after every turn until the hat is empty, which ends the round. The team that empties the hat carries into the next round.

### Special rules

- **Time preservation:** a team that takes the last word of a round with time left starts the next round with that remaining time.
- **Team continuity:** teams do not reset between rounds.

After all three rounds, the highest total score wins.

## Play modes

| Mode | How it works |
|---|---|
| **Pass-and-play** | Single device handed around the table. No network needed. |
| **Online** | Host creates a room and shares a 6-character code; players join from anywhere. Synced through Firebase Realtime Database. |
| **Nearby** | Same-Wi-Fi multiplayer over MultipeerConnectivity — no internet or account required. |

## Features

- Three play modes (pass-and-play, online, nearby).
- Configurable per game: words per player, round duration, number of teams, players per team, skipping on/off, manual vs automatic words.
- Real-time scoring and round-by-round standings.
- Pause and resume during a turn.
- Five app icons (Classic, Sunset, Neon, Vintage, Minimal).
- Light / Dark / System appearance.
- Localized in English and Georgian, switchable in-app.
- Left- and right-handed layouts.
- Time-up sound, allow-duplicate-words, and a built-in feedback form.

## Technical overview

- **Platform:** iOS 26.0+
- **UI:** SwiftUI with the Observation framework (`@Observable`); Swift Concurrency throughout.
- **Multiplayer:** Firebase Realtime Database (online) and MultipeerConnectivity (nearby).
- **Modularization:** three local Swift packages — `Navigation`, `Networking`, `DesignBook`.

The only third-party dependency is the Firebase iOS SDK, pulled in by the `Networking` package. `GoogleService-Info.plist` is committed (Firebase project `hat-game-e050f`), so online play works without extra setup.

## Project structure

```text
HatGame-iOS/
├── HatGame/
│   ├── HatGame.xcodeproj
│   └── HatGame/
│       ├── HatGameApp.swift
│       ├── Configuration/   # AppConfiguration, AppIcon, AppColorScheme, AppLanguage, Handedness
│       ├── Manager/         # GameManager, HistoryManager, GameConfiguration, WordDatabase, SoundPlayer, ...
│       ├── Model/           # Team, Player, Word, GameRound, PlayCompletionReason
│       ├── Navigation/      # App destinations as Page factories
│       ├── View/
│       │   ├── Home/ Setup/ Game/ Play/ Settings/ Developer/ Feedback/ Component/
│       │   ├── Online/      # Firebase multiplayer screens
│       │   └── Local/       # Nearby (Multipeer) multiplayer screens
│       ├── Extensions/
│       ├── Localization/    # Localizable.xcstrings (en, ka)
│       └── Assets.xcassets/
├── Navigation/              # Local package — Navigator, Page<Content>, NavigationView
├── Networking/              # Local package — Firebase + Multipeer transports
├── DesignBook/              # Local package — design tokens + color assets
├── database.rules.json      # Firebase Realtime Database security rules
└── firebase.json / .firebaserc
```

## Getting started

```bash
git clone https://github.com/Khizanag/HatGame-iOS.git
cd HatGame-iOS
open HatGame/HatGame.xcodeproj
```

Select an iOS 26 simulator (or a device) and run with ⌘R. Xcode resolves the three local packages automatically; there is no `.xcworkspace`.

## License

See [LICENSE](LICENSE).

## Author

Giga Khizanishvili.
