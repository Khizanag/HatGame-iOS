# Overview

Hat Game is a team word-guessing party game. Every player secretly contributes words into a shared "hat." Teams then take turns trying to make their teammates guess as many of those words as possible against a timer — three times over, with the explaining getting harder each round.

## Objective

Score the most points across three rounds. A team earns **one point for every word its teammates correctly guess**. After the third round, the team with the highest total wins.

## The shape of a game

1. **Setup** — create teams, then every player fills the hat with words. See [Setup](setup.md).
2. **Three rounds** — the same words are played three times. Each round keeps the same words but tightens the rule for how the explainer may convey them. See [The Three Rounds](rounds.md).
3. **Turns** — within a round, teams alternate taking timed turns until the hat is empty, which ends the round. See [A Turn](turn.md).
4. **Result** — points are tallied per round and overall; the highest total wins. See [Scoring and Winning](scoring.md).

## Key terms

- **The hat** — the shared pool of every word added during setup. At the start of each round the hat is refilled with the full set of words.
- **Word** — a single entry a player added to the hat. Guessing one is worth one point.
- **Team** — a named, colored group of players (2–6 teams, each with 2 or more players).
- **Player** — a member of a team. On any given turn a player is either the explainer or a guesser.
- **Explainer** — the one player on the active team who conveys the current word to their teammates.
- **Guessers** — the remaining players on the active team, who call out guesses.
- **Round** — one full pass through all the words. There are three, each with a stricter explaining rule.
- **Turn** — one team's single timed attempt (the code calls this a "play"). A turn ends when the timer runs out or the hat empties.
- **Score** — the number of words a team has guessed, tracked per round and in total.
- **Standings** — the ranking of teams by points, available per round and as a running total.

## Distinctive rules worth knowing early

- The **same words repeat** in all three rounds — only the explaining rule changes.
- The team that **empties the hat** to end a round keeps its leftover time and its current explainer when the next round begins; every other team starts fresh. See [The Three Rounds](rounds.md).
- **Skipping** a word (returning it to the hat) is allowed by default but can be turned off per game. See [A Turn](turn.md).

## See also

- [Setup](setup.md)
- [Game Flow](game-flow.md)
- [Play Modes](play-modes.md)
