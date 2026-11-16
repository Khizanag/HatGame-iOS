// Replays a rules scenario (see RulesScenarioExport.swift) against the
// Realtime Database emulator over REST, as an unauthenticated client — which
// is what the app is. Each step must be allowed or denied as recorded.
//
// Usage: node check.mjs <scenario.json>
// Started by run.sh inside `firebase emulators:exec`, which sets
// FIREBASE_DATABASE_EMULATOR_HOST.

import { readFile } from "node:fs/promises";

const [scenarioPath] = process.argv.slice(2);
if (!scenarioPath) {
  console.error("usage: node check.mjs <scenario.json>");
  process.exit(2);
}

const host = process.env.FIREBASE_DATABASE_EMULATOR_HOST ?? "127.0.0.1:9000";
const namespace = process.env.RULES_CHECK_NAMESPACE ?? "demo-hatgame-default-rtdb";
const steps = JSON.parse(await readFile(scenarioPath, "utf8"));

let failures = 0;
for (const [index, step] of steps.entries()) {
  const init = { method: step.method, headers: { "Content-Type": "application/json" } };
  if (step.body !== undefined) init.body = JSON.stringify(step.body);
  const response = await fetch(`http://${host}/${step.path}.json?ns=${namespace}`, init);
  const detail = await response.text();
  const outcome = response.ok ? "allow" : "deny";
  const passed = outcome === step.expect;
  if (!passed) failures += 1;
  const number = String(index + 1).padStart(2);
  const line = `${passed ? "PASS" : "FAIL"} ${number} ${step.expect.padEnd(5)} ${step.method.padEnd(6)} ${step.path} — ${step.name}`;
  console.log(passed ? line : `${line}\n          got ${response.status}: ${detail.slice(0, 200)}`);
}

console.log(`\n${steps.length - failures}/${steps.length} steps behaved as expected`);
process.exit(failures === 0 ? 0 : 1);
