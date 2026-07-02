// Stage 6 — pipeline. Vibecoded deals → deals (brand_id + stage_id resolved
// from brands/pipeline_stages by brand key + position; slug set from the stage;
// company via legacy_ref). Idempotent on legacy_ref (= vibecoded d##).
//
// Usage: node scripts/etl/stage6-pipeline.mjs <vibeDbUrl> > stage6.sql

import { execFileSync } from "node:child_process";
import Papa from "papaparse";
import { sqlStr, sqlInt } from "./lib/sql.mjs";

const VIBE_DB = process.argv[2];
const cols = [
  "id",
  "brand",
  "account_id",
  "name",
  "value",
  "stage",
  "prob",
  "close",
];
const rows = Papa.parse(
  cols.join(",") +
    "\n" +
    execFileSync(
      "psql",
      [VIBE_DB, "--csv", "-t", "-c", `select ${cols.join(",")} from deals`],
      {
        encoding: "utf8",
      },
    ),
  { header: true, skipEmptyLines: true },
).data;

const deals = rows
  .filter((r) => (r.id || "").trim() && (r.name || "").trim())
  .map((r) => ({
    legacyRef: r.id.trim(),
    brand: (r.brand || "").trim(),
    position: r.stage,
    name: r.name.trim(),
    amount: r.value,
    prob: r.prob,
    close: (r.close || "").trim() || null,
    acct: (r.account_id || "").trim() || null,
  }));

const out = ["-- Stage 6: pipeline / deals (generated)", "begin;"];
const v = deals
  .map(
    (d) =>
      `(${sqlStr(d.legacyRef)}, ${sqlStr(d.brand)}, ${sqlInt(d.position)}, ${sqlStr(d.name)}, ${sqlInt(d.amount)}, ${sqlInt(d.prob)}, ${d.close ? `date ${sqlStr(d.close)}` : "null"}, ${sqlStr(d.acct)})`,
  )
  .join(",\n  ");
out.push(`with deal_src(legacy_ref, brand_key, position, name, amount, prob, close, acct_ref) as (values\n  ${v}\n)
insert into public.deals (legacy_ref, name, amount, probability, expected_closing_date, company_id, brand_id, stage_id, stage)
select s.legacy_ref, s.name, s.amount, s.prob, s.close, co.id, b.id, ps.id, ps.slug
from deal_src s
  join public.brands b on b.key = s.brand_key
  join public.pipeline_stages ps on ps.brand_id = b.id and ps.position = s.position
  left join public.companies co on co.legacy_ref = s.acct_ref
on conflict (legacy_ref) do update set
  name = excluded.name, amount = excluded.amount, probability = excluded.probability,
  expected_closing_date = excluded.expected_closing_date, company_id = excluded.company_id,
  brand_id = excluded.brand_id, stage_id = excluded.stage_id, stage = excluded.stage,
  updated_at = now();`);
out.push("commit;");
out.push(`-- counts: deals=${deals.length}`);
process.stdout.write(out.join("\n\n") + "\n");
