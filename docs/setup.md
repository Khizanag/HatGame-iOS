# Setup

Before play begins, a game is configured in a fixed sequence of steps. This page describes the pass-and-play (single-device) setup; the [online and nearby modes](play-modes.md) collect the same information but spread it across each player's own device.

## Setup steps, in order

1. **Teams and players** — create the teams and their members.
2. **Timer settings** — turn length, whether skipping is allowed, and what a skip costs.
3. **Fill the hat** — how many words each player contributes, and whether players type them or the app picks them.
4. **Add words** — every player fills the hat (manual), or the app fills it (automatic).
5. **Randomize** — shuffle the words and choose which team starts.

## 1. Teams and players

- A game has **2 to 6 teams**.
- Each team needs at least **2 players** (one to explain, at least one to guess) and may have up to **6**. The default is **2 players per team**.
- Each team has a name and a color used throughout the game.

## 2. Timer settings

- **Turn length** — how long each timed turn lasts. Default is **60 seconds**; configurable from 5 to 120 seconds in 5-second steps.
- **Allow skipping** — whether players may pass on a word and return it to the hat during a turn. **On by default.** See [A Turn](turn.md#skipping).
- **Skip penalty** — points a team loses for each word it skips: none, 1, 2, or 3. **1 by default.** Shown only while skipping is allowed. See [Scoring](scoring.md#points).

## 3. Fill the hat

One screen sets the hat's size and where its words come from. The total — *players × words-per-player* — is shown as it changes.

- **Words per player** — each player contributes the same number of words. Default is **10**; configurable from 3 to 20. Lowering it after words were typed keeps each player's first words up to the new count.
- **Where the words come from:**
  - **Write Our Own** — each player types in their own words, in secret.
  - **Pick for Us** — the app chooses words automatically from a built-in word database, with no typing. If players already typed words, the app asks before replacing them.

## 4. Add words

### Manual entry

- The device is passed from player to player. Each player privately adds their allotted number of words, then hands off to the next.
- An **auto-fill** option can complete a player's remaining words from the built-in database.
- Whether the same word may be added by more than one player is governed by the **Allow Duplicate Words** default setting. A player can never add the same word twice.
- Words are compared ignoring capitalization and accents, so "Apple", "apple", and "Äpple" count as the same word.
- Going back and saving a player's words again replaces them; it never adds a second copy.
- The step is complete once every player has entered their words.

### Automatic generation

- The app fills the hat directly from the built-in word database — enough words for the whole game — so no one types anything.
- The database matches the app language: Georgian words for Georgian, English words for every other language. The same list powers auto-fill during manual entry.
- If the word list can't be loaded, the app says so and offers manual entry instead of starting with an empty hat.

## 5. Randomize and start

- The collected words are shuffled into a random order.
- You choose which team takes the first turn, or let the app pick a **starting team** at random.
- Starting the game hands the first turn to that team. See [A Turn](turn.md) and [Game Flow](game-flow.md).

## Defaults summary

| Setting | Default | Range |
|---|---|---|
| Teams | 2 | 2–6 |
| Players per team | 2 | 2–6 |
| Words per player | 10 | 3–20 |
| Turn length | 60 seconds | 5–120 (step 5) |
| Allow skipping | On | On / Off |
| Skip penalty | 1 point | None–3 |

Defaults can be changed in the app's settings and are applied to each new game.

## See also

- [A Turn](turn.md)
- [The Three Rounds](rounds.md)
- [Game Flow](game-flow.md)
