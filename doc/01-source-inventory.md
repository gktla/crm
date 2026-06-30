# 01 · Source inventory

Canonical source inventory for the Goalkeeper Group CRM. Four origins: **(A)** production Atomic CRM, **(B)** Coda CSV exports, **(C)** the vibecoded prototype, and **(D)** GPS — an external system the CRM links to, not a source to merge. See doc 07 for the GPS relationship.

> The CRM keeps `companies`/`clubs` as **sales targets**; GPS keeps `organisations` as **paying tenants**. They reconcile through a single link field (§D). Link, do not merge — there is no shared org table and `companies` is not reshaped for GPS.

---

## A. Current Atomic CRM tables

Read from `~/projects/crm/supabase/schemas/01_tables.sql`. **Verify against the running schema before M1.** One block per table: key facts first, then the column list.

**`companies`** · PK `id` (bigint identity) · FK `sales_id→sales`
Columns: name, sector, size, linkedin_url, website (citext), phone_number, address, zipcode, city, state_abbr, country, description, revenue (text), tax_identifier, logo (jsonb), context_links (json), sales_id, created_at.
*No `updated_at`. `website` is citext.*

**`contacts`** · PK `id` · FK `company_id→companies` (cascade), `sales_id→sales`
Columns: first_name, last_name, gender, title, background, avatar (jsonb), first_seen, last_seen, has_newsletter, status, **tags (bigint[])**, **company_id (single)**, sales_id, linkedin_url, email_jsonb, phone_jsonb.
*email/phone = `[{email,type}]`/`[{number,type}]`. `tags` is an array.*

**`contact_notes`** · PK `id` · FK `contact_id→contacts` (cascade)
Columns: contact_id, text, date, sales_id, status, attachments (jsonb[]).
*Free-text / activity backbone.*

**`deals`** · PK `id` · FK `company_id→companies`, `sales_id→sales`
Columns: name, company_id, **contact_ids (bigint[])**, category, **stage (text)**, description, amount (bigint), created_at, updated_at, archived_at, expected_closing_date, sales_id, **index**.
*stage/category = slugs validated vs configuration. No brand, no probability.*

**`deal_notes`** · PK `id` · FK `deal_id→deals`
Columns: deal_id, type, text, date, sales_id, attachments (jsonb[]).

**`sales`** · PK `id` · FK `user_id→auth.users`
Columns: first_name, last_name, email (citext), administrator, user_id (uuid), avatar, disabled.
*App users. Auth = Google OAuth on Supabase (decision A); no `entra_oid`.*

**`tags`** · PK `id`
Columns: name, color.
*Referenced by `contacts.tags[]` (array, no real FK).*

**`tasks`** · PK `id` · FK `contact_id→contacts` (cascade), `sales_id→sales`
Columns: **contact_id (NOT NULL)**, type, text, due_date, done_date, sales_id.
*Links to a contact only, today.*

**`configuration`** · PK `id=1` (singleton)
Columns: config (jsonb) — branding, currency, dealStages, dealCategories, noteStatuses, taskTypes.
*RLS admin-only write.*

**`favicons_excluded_domains`** · PK `id`
Columns: domain. *Utility.*

**Views:** `activity_log` (UNION of created events — Atomic's "activity" is derived, not stored) · `companies_summary` (+nb_deals, nb_contacts) · `contacts_summary` (+company_name, nb_tasks, FTS) · `init_state`.

**Default configuration:** dealStages (6 global slugs: opportunity, proposal-sent, in-negociation, won, lost, delayed) · dealPipelineStatuses = `["won"]` · taskTypes include follow-up/call/meeting/demo/email · noteStatuses cold/warm/hot/in-contract · defaultCurrency `USD` → **change to GBP**.

**RLS / triggers:** RLS on every table, uniform `to authenticated using(true)` + per-table delete; configuration writes restricted to `is_admin()`. Edge Functions: postmark inbound email→note, merge_contacts, users, update_password.

---

## B. Coda exports — measured from the actual CSVs

### `DB_Clubs.csv` — 352 rows, 13 columns
Columns: Hit List, Club, Notes, League, Nation, Owned Players, Players Loaned In, Players Loaned Out, Current Players, Target Players, Staff, Club Row ID, XG Status.

- **Names are not unique:** 352 rows, **337 distinct names**; 14 duplicated (Aberdeen, Barnet, Blyth Spartans, Crown Legacy, Eastbourne Borough, Gateshead, Livingston, Maidstone United, Rhode Island FC, Weymouth, Woking, Wolves, Wrexham, York City) + blank-name rows. **`Club Row ID` is the real key.**
- **`Hit List`** = boolean (~175 true / 177 false).
- **`League`** (21 incl. blank): Argentina Primera, Championship, Conference North/South, Eredivisie, League One/Two, Liga MX, MLS (E/W), MLS Next Pro (E/W), National League, Others, Premier League, SPL, Scottish Championship, Serbian SuperLiga, USL (E/W).
- **`Nation`** codes: ARG, CAN, ENG, MEX, NED, SCO, SER, USA + blank. **Dirty** — e.g. an Aberdeen row tagged `ENG`; clean on import.
- **`XG Status`** is **uniformly `Pending`** (352/352) → free text, no CHECK enum.
- **`Target Players`** is **empty** in this export.
- `Owned / Loaned In / Loaned Out / Current Players` = comma-separated player-name lists; `Staff` = comma-separated staff names. Resolve to junctions, not stored lists.

### `DB_PlayerCRM.csv` — 64 rows, 20 columns
Columns: Player, Age, Club, League, Representation Name, Agent Expiry, REP, REP (Temp Column), Social Media, Status, FOLLOW BACK (1)…CONTRACT (8), Notes, PlayerCRM Row ID.

- **`Age`** is an int — **no date of birth**.
- **`Agent Expiry` is dirty:** `25/07/2024`, `Dec 2024`, `Feb 24`, `June 2024` → normalize to `date`; month-only values need a day convention.
- **`Status`** = funnel step; the 8 booleans `(1)…(8)` encode the same funnel → `Status` is derivable. Distribution: Step 2 (37), Step 6 (10), blank (6), Step 4 (4), Step 5 (3), Step 7 (2), Step 1 (1), Step 8 (1).
- **`REP (Temp Column)`** = codes `DR`/`RL`/`ZY`; **`Representation Name`** mostly empty (`Octagon` seen). Temp Column discardable.
- **`Social Media`** empty in sample → confirm format.

### `DB_ClubStaff.csv` — 238 rows, 8 columns
Columns: Club, Name, Title, Social Media URLs, Insta Status, Relationship, Preferred Contact, Notes. Keyed by (Club name, Name).

- **`Title`:** Goalkeeper Coach (114), **blank (50)**, Sporting Director (21), Academy Coach (19), Manager (18), Scout (9), Analyst (3), Head of Goalkeeping (2), CEO (2) → normalize to a role set, allow null.
- **`Insta Status`:** No Insta (107), Followed Back (59), blank (50), Following (20), Private (1), `PRIVATE` (1) — case duplicate to normalize.
- **`Relationship`:** mostly blank (192), Very Contactable (36), Moderate Contact (7), Limited Contact (3).
- **`Preferred Contact`** = boolean, mostly null (blank 224, false 11, true 3).
- **`Social Media URLs`:** 81 non-empty, one URL per row, mostly Instagram.
- **To add (explicit request):** LinkedIn URL + LinkedIn status (not in the export).

### "Details" views
`Player Details` / `Club Details` are **detail views, not tables** — their fields land in main/related tables, computed fields or SQL views. No `player_details` / `club_details`.

---

## C. Vibecoded prototype (third source)

Retired as a build base (front rebuilt on Atomic; data migrated). **Re-confirm during migration.**

- **Account ⊆ Club** — same `a##` namespace → unified under `companies` (+ `clubs`).
- **Contact intelligence** (sd / hor / gkCoach / notes / linkedin) + **email intelligence** (domain / pattern / contacts) — crown-jewel data; never in SQL.
- **Deals** — hardcoded brand enum, stage as positional index, persisted probability, broken FK (pointed at clubs).
- **Services** (Police/Fire/Prison/Ambulance) = Onesport vertical (`svc##`).
- **Tasks / LeagueLog / ContactOverride** — only in Zustand/localStorage.
- **Shopify orders** — multi-currency string totals, free-text customer.
- **xG modules** (Ongoing / Transfer / Opposition / API) + **Onesport teams** (level + sports) — from requirements §9.2/§9.3.

---

## D. GPS — external system, link not merge

GPS is **not** a data source for this DB. It is a separate multi-tenant product on a separate host, read-only over an ETL feed. The only CRM-side touchpoints are additive and tiny:

- `organisations` (GPS tenant) ↔ `clubs` (sales target) → **link field** `clubs.gps_org_id` — **nullable & optional**, filled by hand on deal-won if useful. No shared table.
- `users` (Entra-linked) ↔ `sales` (staff) → **no link** — CRM auth is Google OAuth on Supabase (decision A).
- `roles` / `entitlements` (4-layer RBAC) ↔ RBAC at M6 → **our own simple model** (decision B'), not GPS's 4-layer.
- `org_features` (what they bought) ↔ `company_brands` / `deal_modules` (what we sold) → parallel only.

GPS decisions are resolved (doc 05 §A/§K/§L, doc 07): separate systems, standardized vocabulary + the optional `gps_org_id` link.

---

## Cross-cutting: views & computed fields

| Calculation | Destination |
| --- | --- |
| activity_log | keep + extend with activities/tasks |
| nb_deals / nb_contacts / nb_tasks | keep `*_summary`; recompute when extended |
| weighted pipeline (Σ value×prob) | view/app calc — don't persist |
| account LTV | curated field + Σ-won view |
| derived email (name+pattern+domain) | Postgres function / app helper — don't persist |
| probability per stage | default from `pipeline_stages` + override on deal |
| player `Status` | derive from funnel steps |
| player `League` | derive from the club |
| player age | prefer `date_of_birth`; `Age` as imported snapshot |

---

## Still open / not resolvable from these files

- **Target Lists** (named lists), **Preferred Contact at club level**, and the "Details" columns aren't in the CSVs — model from names + requirements; validate against Coda with Diego (M0-9).
- **Source-of-truth precedence** (decision I): intel/email → vibecoded · players/staff/relations → Coda · pipeline → vibecoded.
- **Player load scope** (decision H): bounded to the Coda CSVs (`DB_PlayerCRM` + the `DB_Clubs` list columns); tables keep full shape.
- **Atomic schema, vibecoded repo, `Contact 2026.xlsx`** facts are taken from the cited files; verify against the running systems.
