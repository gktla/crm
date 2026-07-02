// Stage 7 — services (Onesport). Vibecoded services → companies(kind=service)
// + company_org_types + sports_secretary contact + company_contacts link.
// (teams/sports skipped: sports catalog is empty in Phase 1.)
//
// Usage: node scripts/etl/stage7-services.mjs <vibeDbUrl> > stage7.sql

import { execFileSync } from "node:child_process";
import Papa from "papaparse";
import { orgKey } from "./lib/normalize.mjs";
import { sqlStr, slugify } from "./lib/sql.mjs";

const VIBE_DB = process.argv[2];
const cols = [
  "id",
  "name",
  "type",
  "region",
  "country",
  "sports_secretary",
  "email",
  "notes",
];
const rows = Papa.parse(
  cols.join(",") +
    "\n" +
    execFileSync(
      "psql",
      [VIBE_DB, "--csv", "-t", "-c", `select ${cols.join(",")} from services`],
      {
        encoding: "utf8",
      },
    ),
  { header: true, skipEmptyLines: true },
).data;

const orgs = [];
const secs = [];
const links = [];
for (const r of rows) {
  const id = (r.id || "").trim();
  const name = (r.name || "").trim();
  if (!id || !name) continue;
  const slug = "svc-" + slugify(orgKey(name));
  orgs.push({
    id,
    slug,
    name,
    country: (r.country || "").trim() || null,
    notes: (r.notes || "").trim() || null,
  });

  const sec = (r.sports_secretary || "").trim();
  if (sec && !sec.toLowerCase().startsWith("tbc")) {
    const parts = sec.split(/\s+/);
    const ref = `svc-sec:${id}`;
    const email = (r.email || "").trim() || null;
    secs.push({
      ref,
      first: parts[0],
      last: parts.slice(1).join(" ") || null,
      email,
    });
    links.push({ ref, svcId: id });
  }
}

const out = ["-- Stage 7: services (generated)", "begin;"];

const ov = orgs
  .map(
    (o) =>
      `(${sqlStr(o.id)}, ${sqlStr(o.slug)}, ${sqlStr(o.name)}, ${sqlStr(o.country)}, ${sqlStr(o.notes)})`,
  )
  .join(",\n  ");
out.push(`with svc_src(legacy_ref, slug, name, country, notes) as (values\n  ${ov}\n)
insert into public.companies (legacy_ref, slug, name, kind, country, description)
select legacy_ref, slug, name, 'service', country, notes from svc_src
on conflict (legacy_ref) do update set
  name = excluded.name, kind = 'service', country = coalesce(excluded.country, public.companies.country),
  description = coalesce(excluded.description, public.companies.description), updated_at = now();`);

out.push(`insert into public.company_org_types (company_id, org_type_id)
  select c.id, ot.id from public.companies c join public.org_types ot on ot.code='service'
  where c.kind='service' on conflict do nothing;`);

if (secs.length) {
  const sv = secs
    .map(
      (s) =>
        `(${sqlStr(s.ref)}, ${sqlStr(s.first)}, ${sqlStr(s.last)}, ${s.email ? sqlStr(JSON.stringify([{ email: s.email, type: "Work" }])) : "null"})`,
    )
    .join(",\n  ");
  out.push(`with sec_src(legacy_ref, first_name, last_name, email_jsonb) as (values\n  ${sv}\n)
insert into public.contacts (legacy_ref, first_name, last_name, email_jsonb)
select s.legacy_ref, s.first_name, s.last_name, s.email_jsonb::jsonb from sec_src s
where not exists (select 1 from public.contacts c where c.legacy_ref = s.legacy_ref);`);

  const lv = links
    .map((l) => `(${sqlStr(l.ref)}, ${sqlStr(l.svcId)})`)
    .join(",\n  ");
  out.push(`with link_src(person_ref, svc_ref) as (values\n  ${lv}\n)
insert into public.company_contacts (company_id, contact_id, role, is_primary, is_current)
select co.id, ct.id, 'sports_secretary', true, true
from link_src s
  join public.contacts ct on ct.legacy_ref = s.person_ref
  join public.companies co on co.legacy_ref = s.svc_ref
on conflict (company_id, contact_id, role) where is_current do nothing;`);
}

out.push("commit;");
out.push(`-- counts: services=${orgs.length} secretaries=${secs.length}`);
process.stdout.write(out.join("\n\n") + "\n");
