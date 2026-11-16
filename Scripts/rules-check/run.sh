#!/bin/bash
#
# run.sh - check database.rules.json against every write the app makes.
#
# Exports the scenario from the GameCore test target (the payloads come from
# the same RoomWrites/FirebaseCoding the app sends), then replays it against
# the Realtime Database emulator with the rules in firebase.json. Exits 1 if
# any write is allowed that should be denied, or the other way round.
#
# Needs firebase-tools and Java. Uses a demo- project id, so no login.
#
# Usage:
#   Scripts/rules-check/run.sh
#

set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
scenario="$(mktemp -d)/scenario.json"

echo "Exporting the scenario from GameCore…"
(cd "$root/HatGame-Networking" \
    && HATGAME_RULES_SCENARIO="$scenario" swift test --filter RulesScenarioExport >/dev/null)
test -s "$scenario" || { echo "The scenario export produced nothing" >&2; exit 1; }

echo "Replaying it against the Realtime Database emulator…"
cd "$root"
firebase emulators:exec --only database --project demo-hatgame \
    "node Scripts/rules-check/check.mjs '$scenario'"
