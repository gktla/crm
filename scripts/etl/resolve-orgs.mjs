/* eslint-disable no-console -- CLI dry-run reporter: console output is the point */
// Entity-resolution DRY-RUN (no DB writes).
// Matches Coda `DB_Clubs` names against the vibecoded org directory
// (gk_vibecoded.clubs) by normalized name, and classifies every org into:
//   auto-match (1:1)  ·  ambiguous (needs review)  ·  coda-only  ·  vibecoded-only
// Prints a summary and writes the full review list to REVIEW_OUT.
//
// Usage:
//   node scripts/etl/resolve-orgs.mjs [codaClubsCsv] [vibeDbUrl] [reviewOut]

import { readFileSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import Papa from "papaparse";
import { orgKey } from "./lib/normalize.mjs";

const CODA_CLUBS_CSV =
  process.argv[2] || "/home/amanda/Downloads/gk_backup (3)/../DB_Clubs (1).csv";
const VIBE_DB =
  process.argv[3] ||
  "postgresql://postgres:postgres@127.0.0.1:54322/gk_vibecoded";
const REVIEW_OUT = process.argv[4] || "/tmp/org-match-review.json";

function parseCsv(text) {
  return Papa.parse(text.trim(), { header: true, skipEmptyLines: true }).data;
}

// --- Load Coda clubs (dedup by Club Row ID; skip blank names) ---
const codaRows = parseCsv(readFileSync(CODA_CLUBS_CSV, "utf8"));
const codaByRowId = new Map();
for (const r of codaRows) {
  const name = (r["Club"] || "").trim();
  const rowId = (r["Club Row ID"] || "").trim();
  if (!name || !rowId) continue;
  if (!codaByRowId.has(rowId)) codaByRowId.set(rowId, { rowId, name });
}
const coda = [...codaByRowId.values()];

// --- Load vibecoded org directory via psql ---
const vibeCsv = execFileSync(
  "psql",
  [VIBE_DB, "--csv", "-t", "-c", "select id, name from clubs order by id"],
  { encoding: "utf8" },
);
const vibe = parseCsv("id,name\n" + vibeCsv).filter((r) => r.name);

// --- Group by normalized key ---
const codaKeys = new Map();
for (const c of coda) {
  const k = orgKey(c.name);
  if (!codaKeys.has(k)) codaKeys.set(k, []);
  codaKeys.get(k).push(c);
}
const vibeKeys = new Map();
for (const v of vibe) {
  const k = orgKey(v.name);
  if (!vibeKeys.has(k)) vibeKeys.set(k, []);
  vibeKeys.get(k).push(v);
}

const allKeys = new Set([...codaKeys.keys(), ...vibeKeys.keys()]);
const autoMatch = [];
const ambiguous = [];
const codaOnly = [];
const vibeOnly = [];

for (const k of allKeys) {
  const c = codaKeys.get(k) || [];
  const v = vibeKeys.get(k) || [];
  if (c.length && v.length) {
    if (c.length === 1 && v.length === 1) {
      autoMatch.push({ key: k, coda: c[0], vibe: v[0] });
    } else {
      ambiguous.push({ key: k, coda: c, vibe: v });
    }
  } else if (c.length) {
    codaOnly.push({ key: k, coda: c });
  } else {
    vibeOnly.push({ key: k, vibe: v });
  }
}

// --- Report ---
console.log("=== ENTITY RESOLUTION DRY-RUN (no writes) ===\n");
console.log(`Coda clubs (distinct Row ID): ${coda.length}`);
console.log(`Vibecoded orgs (clubs dir):   ${vibe.length}\n`);
console.log(`Auto-match (1:1):   ${autoMatch.length}`);
console.log(`Ambiguous (review): ${ambiguous.length}`);
console.log(`Coda-only:          ${codaOnly.length}`);
console.log(`Vibecoded-only:     ${vibeOnly.length}`);
console.log(
  `\nUnique real orgs after merge: ${autoMatch.length + ambiguous.length + codaOnly.length + vibeOnly.length}\n`,
);

console.log("--- Sample auto-matches (first 15) ---");
for (const m of autoMatch.slice(0, 15)) {
  console.log(`  "${m.coda.name}"  ⟷  "${m.vibe.name}"  [${m.vibe.id}]`);
}

console.log("\n--- Ambiguous (needs your review) ---");
for (const a of ambiguous) {
  const c = a.coda.map((x) => `${x.name}#${x.rowId}`).join(" | ");
  const v = a.vibe.map((x) => `${x.name}[${x.id}]`).join(" | ");
  console.log(`  key="${a.key}"  coda={ ${c} }  vibe={ ${v} }`);
}

writeFileSync(
  REVIEW_OUT,
  JSON.stringify({ autoMatch, ambiguous, codaOnly, vibeOnly }, null, 2),
);
console.log(`\nFull review list written to: ${REVIEW_OUT}`);
