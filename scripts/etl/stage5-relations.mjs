// Stage 5 — player_org_assignments. Current club from DB_PlayerCRM.Club, plus
// owned/loaned/target from the DB_Clubs list columns (only for the ~64 known
// players). Player names matched by nameKey; unknown names skipped.
//
// Usage: node scripts/etl/stage5-relations.mjs <playerCsv> <clubsCsv> > stage5.sql

import { readFileSync } from "node:fs";
import Papa from "papaparse";
import { orgKey, nameKey } from "./lib/normalize.mjs";
import { sqlStr, slugify } from "./lib/sql.mjs";

const [PLAYER_CSV, CLUBS_CSV] = process.argv.slice(2);
const parse = (t) =>
  Papa.parse(t.trim(), { header: true, skipEmptyLines: true }).data;

const LIST_COLS = [
  ["Owned Players", "owned"],
  ["Current Players", "current"],
  ["Players Loaned In", "loaned_in"],
  ["Players Loaned Out", "loaned_out"],
  ["Target Players", "target"],
];

// known players: nameKey -> coda_row_id
const players = parse(readFileSync(PLAYER_CSV, "utf8"));
const playerByName = new Map();
const assignments = new Map(); // `${rowId}::${slug}::${type}` -> {rowId, slug, type}
for (const p of players) {
  const name = (p["Player"] || "").trim();
  const rowId = (p["PlayerCRM Row ID"] || "").trim();
  if (!name || !rowId) continue;
  playerByName.set(nameKey(name), rowId);
  const club = (p["Club"] || "").trim();
  if (club) {
    const slug = slugify(orgKey(club));
    assignments.set(`${rowId}::${slug}::current`, {
      rowId,
      slug,
      type: "current",
    });
  }
}

// list columns from DB_Clubs
const clubs = parse(readFileSync(CLUBS_CSV, "utf8"));
for (const c of clubs) {
  const club = (c["Club"] || "").trim();
  if (!club) continue;
  const slug = slugify(orgKey(club));
  for (const [col, type] of LIST_COLS) {
    const cell = (c[col] || "").trim();
    if (!cell) continue;
    for (const raw of cell.split(",")) {
      const rowId = playerByName.get(nameKey(raw));
      if (rowId)
        assignments.set(`${rowId}::${slug}::${type}`, { rowId, slug, type });
    }
  }
}

const out = ["-- Stage 5: player_org_assignments (generated)", "begin;"];
if (assignments.size) {
  const v = [...assignments.values()]
    .map((a) => `(${sqlStr(a.rowId)}, ${sqlStr(a.slug)}, ${sqlStr(a.type)})`)
    .join(",\n  ");
  out.push(`with asg_src(coda_row_id, slug, rel) as (values\n  ${v}\n)
insert into public.player_org_assignments (player_id, org_id, relationship_type, is_current)
select p.id, co.id, s.rel, true
from asg_src s
  join public.players p on p.coda_row_id = s.coda_row_id
  join public.companies co on co.slug = s.slug
on conflict (player_id, org_id, relationship_type) where is_current do nothing;`);
}
out.push("commit;");
out.push(`-- counts: assignments=${assignments.size}`);
process.stdout.write(out.join("\n\n") + "\n");
