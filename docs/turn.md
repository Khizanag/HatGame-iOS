# A Turn

A turn is one team's single timed attempt to clear words from the hat. Teams alternate taking turns until the hat is empty, which ends the [round](rounds.md). This page describes what happens during one turn.

## Choosing the explainer

Before a team's turn, one player is designated the **explainer**; the rest are **guessers**.

- The **first time a team plays**, you choose its explainer — either pick a specific player ("Who will explain?") or let the app pick a random one.
- After that first turn, the team's roles are **locked**: the explainer is no longer chosen by hand. Instead it **rotates automatically** to the next player each time the team is timed out (see [Rotation](#explainer-rotation)).

## The timer

- A turn is timed. The default length is **60 seconds** (configurable; see [Setup](setup.md#3-timer-settings)).
- A turn normally starts with a **full** timer. The exception: a team that ended the previous round by emptying the hat resumes with its **carried-over leftover time** for its first turn of the new round. See [The Three Rounds](rounds.md#carrying-over-between-rounds).
- In the final seconds the device gives **urgency haptics**, and a sound plays when time runs out.
- If the app goes to the background mid-turn, the turn **auto-pauses** so the clock can't run down unseen; the player resumes manually.

## Playing the word

The explainer sees the **current word** and conveys it to the guessers under the current round's rule. Each turn offers these actions:

- **Got It** — the word was guessed. It scores **one point** for the team, leaves the hat, and the next random word from the hat appears.
- **Skip** — pass on the current word (see [Skipping](#skipping)).
- **Pause / Resume** — stop and restart the clock.
- **Give Up** — end the turn early (after a confirmation). This is treated the same as the timer running out.

The screen also shows the active team, the round, how many words have been guessed this turn, the countdown, and overall progress through the hat.

## Skipping

Skipping lets the explainer pass on a hard word and come back to it later in the same round.

- Skipping is **allowed by default** but can be turned off per game in [timer settings](setup.md#3-timer-settings).
- A skipped word **stays in the hat** — it is *not* scored and *not* removed. A different random word is shown instead.
- Skipping is only possible when **more than one word remains** in the hat (otherwise there is nothing to swap to). When skipping is off, or only one word is left, the skip action is unavailable.

## How a turn ends

A turn ends in one of two ways:

- **Time's Up** — the timer reached zero, or the team gave up. The hat still has words, so the round continues: the explainer rotates and the **next team** takes its turn.
- **All Words Guessed** — the last word in the hat was guessed. This empties the hat and therefore **ends the round**. The screen celebrates, and the team keeps any leftover time for the next round.

Either way, the turn is followed by the **turn results** screen.

## Turn results

After every turn, a results screen shows:

- Whether the turn ended on "Time's Up" or "All Words Guessed."
- How many words the team guessed **this turn** (and the list of them, or a note that none were guessed).
- **Check Standings** — open the current [round and total standings](scoring.md) without leaving the flow.
- **Continue** — hand off to the next team's turn, or, if the third round just ended, go to the [final results](scoring.md#final-results).

## Explainer rotation

- When a turn ends on the **timer** (or give up), that team's explainer **rotates** to the next player for the team's next turn.
- When a team ends a round by **emptying the hat**, its explainer does **not** rotate — the same player continues explaining into the next round. See [The Three Rounds](rounds.md).

## See also

- [The Three Rounds](rounds.md)
- [Scoring and Winning](scoring.md)
- [Setup](setup.md)
