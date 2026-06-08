# Play Modes

Hat Game can be played three ways. The **rules of play are identical** in all of them — the hat, the three rounds, timed turns, and one point per word (see [Overview](overview.md)). What differs is how players are gathered and how words are collected.

## Pass-and-play (one device)

The classic party setup: everyone shares a single device.

- Played entirely on one device, **fully offline** — no network or account needed.
- Setup happens on the device: teams are created, then the device is passed from player to player so each can privately add their words. See [Setup](setup.md).
- During play, the device is handed to the active team each turn.
- This is the flow documented in [Setup](setup.md) and [Game Flow](game-flow.md).

## Online

Play with people on their own devices, anywhere with an internet connection. Game state is synchronized through Firebase Realtime Database.

- A **host creates a room** and receives a **six-character code** (letters and digits, with visually ambiguous characters like `0`, `1`, `O`, and `I` omitted).
- Other players **join with the code** from their own devices.
- In the **lobby**, players are organized into teams.
- **Each player submits their own words** privately on their device. The host can also **auto-fill** words for everyone from the built-in database.
- When everyone is ready, the host starts the game. The current team, explainer, current word, scores, and round are kept **in sync across every device**.
- A player who is neither the explainer nor a guesser on the active team sees a **spectator view** of the turn in progress.
- Requires an internet connection and the app's Firebase configuration.

## Nearby

The same shared-room experience as online, but over the local network instead of the internet — built on Apple's MultipeerConnectivity.

- Works over **the same Wi-Fi or Bluetooth**, with **no internet and no account** required.
- The **host advertises** a session; nearby players **browse and join** it.
- After that, it behaves like the online mode: a lobby, per-player word submission, and synchronized play.
- Best when everyone is in the same room.

## Choosing a mode

| | Pass-and-play | Online | Nearby |
|---|---|---|---|
| Devices | One shared | One per player | One per player |
| Network | None | Internet | Same Wi-Fi / Bluetooth |
| Account / service | None | Firebase | None |
| Words entered | On the shared device | Each player's device | Each player's device |
| Best for | Same room, one device | Remote players | Same room, many devices |

In every mode the game is the same three rounds — no restrictions, one word only, then gestures only — scored one point per guessed word, with the highest total after Round 3 winning.

## See also

- [Overview](overview.md)
- [Setup](setup.md)
- [Game Flow](game-flow.md)
