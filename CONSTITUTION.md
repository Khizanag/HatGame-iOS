# Hat Game constitution

What Hat Game adds to the shared [iOS constitution](../iOS-Constitution/CONSTITUTION.md), and where it departs from it. The shared articles bind everything not named here. Conforms as of the shared changelog's 2026-11-24 entry.

## Identity marks

Article 6 keeps the accent rare and lets an app name the few marks its identity rests on. Hat Game's identity is the hat and its teams:

- **The hat:** the hero hat's glow, its disc's rim, the upturned hat's opening glow, and the brand gradient behind Home.
- **Team colours:** a team's fills, dots, rings, and the tint of its turn. They are a data palette (article 5), and text in a team's colour always goes through `DesignBook.Color.teamText(for:)`.
- **Progress:** the bar under words being added or drawn, the turn-length slider, and the word steps' current step.
- **A chosen item's edge:** the checkmark and ring of a picked word source, starting team, explainer, or app icon, as a picker's checkmark does.
- **Settings tiles and How to Play discs:** a glyph on its own tinted tile (article 7).

## Articles of its own

### Article 101: a team is known by its colour

Every team has one colour, picked from the palette or by hand, and it marks that team wherever the team appears: its card, its turn, its score, its confetti. Colour never stands alone (article 8): the team's name is always beside it.

### Article 102: a game is never lost by accident

Leaving a game in progress asks first and offers Save and Exit; Home offers to resume a saved game and asks before a new one replaces it. A multiplayer room is left only through the Leave control, which confirms; Back never leaves a player silently in a room.

### Article 103: the words stay secret

No screen shows the words in the hat before they are played. Fill the Hat flies sample words from the word list, never the players' words, and the shuffle's slips are blank.

### Article 104: the turn answers the keyboard

On a single-device turn, → is Got It, ← is Skip, and Esc pauses and resumes. Online turns have no pause, so Esc is Give Up.

### Article 105: one shared device

The in-app Language and Appearance settings deliberately repeat the system's, since one phone is passed around a party. Georgian has no letter case, so uppercase eyebrows go through `eyebrowUppercase()`, never `.textCase(.uppercase)`.

## Exceptions

### Article 20: the hat is an illustration

The 🎩 on Home, in the word draw, and as the upturned hat is the app's emblem, drawn as an illustration and hidden from VoiceOver. It is not copy. Every other emoji in the interface is an SF Symbol.

### Articles 4 and 11: covers close, they don't swipe

The game, online, and nearby flows are full-screen covers that leave through Close, which confirms whenever progress is at stake (article 102), rather than a swipe down that would drop a game or a room without asking.

### Article 11: the turn keeps its controls in the content

The turn is one fixed screen with Got It and Skip at the bottom of the content, above the hat's progress, so the explainer's thumbs stay on them. The turn scrolls only at the largest text sizes.

### Articles 15 and 28: decorative heroes and status screens

Decorative heroes (the hat discs, the target, the trophy) keep their size at every text size and are hidden from VoiceOver; the text beside them scales. Status screens with no reading to do (waiting for players, a spectator's turn, a room's state, the two multiplayer menus) centre their hero and short message, as `ContentUnavailableView` does.

## Not yet conforming

Open work from the adoption audit on 2026-11-24. Remove an entry when it lands.

- **Article 18, the audit.** `AccessibilityAuditUITests` runs every deep-linkable screen at the default and largest text sizes and fails on any new issue. Still expected there, by screen: contrast of text on glass cards over the brand gradient (Home, Fill the Hat, App Icon, Starting Team at accessibility sizes, Developer); Dynamic Type flags on Form rows (Default Game Settings, Developer, App Icon); text clipped in Settings and Default Game Settings; "potentially inaccessible text" on Fill the Hat and Default Game Settings.
- **Article 30, the turn's roles.** `TeamRolesCard` (single device) and the online next-team roles card draw the explainer and guessers separately, because they take different player models. One card over a shared role model replaces both.
- **Article 12, online teams.** A lobby team's long press offers only the host's Delete; it has no preview and no shared modifier like `teamActions`.
- **Article 5, gradients.** The brand, primary, and celebration gradients are built from raw RGB in `DesignBook+Gradient.swift`, with no Dark or Increase Contrast variants.
- **Article 15, team names.** Several result and online headers shrink a long team name to fit one line (`minimumScaleFactor(0.5)`) instead of letting it wrap.
- **Article 27, on a device.** Every change of the adoption still needs the owner's check on a phone, feeling each haptic once.
