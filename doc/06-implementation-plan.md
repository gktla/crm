# 06 · Implementation plan

Build order for the org-centric schema, no SQL yet. Aligns with `CRM-BACKLOG.md`. Respects: don't rewrite Atomic's historical migrations, don't touch prod, verify in `gk-crm-dev` first. See doc 03 (schema), doc 05 (principles + decisions), doc 07 (GPS).

## 0. Rollout principles

- **Additive, never destructive.** New migrations on top of Atomic's history; existing structures aren't rewritten.
- **CRM and GPS are separate systems** (doc 05 §0). No shared tables; integration = standardized vocabulary + the optional `clubs.gps_org_id`. **GPS tenant provisioning is manual** (decision K): on deal-won, someone creates the GPS org and fills `gps_org_id` by hand.
- **Auth = Google OAuth on Supabase** (decision A). No Entra, no `entra_oid`.
- **Two environments only:** `gk-crm-dev`, `gk-crm-prod`. No staging. Flow: branch → PR → dev → merge → backup + verify → controlled migration to prod. Nothing hits prod during this work.
- **Each block:** migration (RLS+policies+grants, §0.1) → idempotent seed/import → react-admin resource → update `*_summary`/`activity_log` views if companies/contacts/deals changed → verify in dev.

## 0.1. RLS in every migration (decision 10)
Every create-table migration includes its own `enable row level security` + policies (`to authenticated using(true) with check(true)`) + grants. Never leave a table unprotected. A final audit migration verifies RLS and leaves a roles placeholder for RBAC (M6). Launch = single-tenant; **RBAC at M6 is our own simple model** fit to the CRM's purpose (decision B'), not GPS's 4-layer.

## 1. Logical order
- **Base catalogs (no deps):** brands, pipeline_stages, org_types, nations, sports, target_lists. *(Leagues are NOT a catalog — they are orgs.)*
- **Org core:** extend `companies` (kind, slug, ltv, updated_at, ext ids) + `company_org_types` (multi-type) + `org_relationships` (the web) + `clubs` (1:1, `league_company_id`, nullable `gps_org_id`) + `competitions` (1:1 for league-orgs) + `company_brands`.
- **People:** extend `contacts` + `company_contacts` (roles incl. agent) + contact_social_profiles.
- **Deals:** extend `deals` (brand_id, stage_id, probability) + deal_modules.
- **Activity:** `activities` (targets company/contact/deal/player) + extend `tasks` (nullable contact_id + FKs) + follow-up automation.
- **Players:** `players` (8 funnel cols) + `player_org_assignments` + `player_citizenships` + `player_representations` + `player_social_profiles`.
- **Onesport / lists:** teams/team_sports + org_target_lists + player_target_lists.
- **Views:** companies_summary, contacts_summary, activity_log, **current_squad** (decision C).

## 2. Migrations (new files, in order)

| # | Migration | Content | Depends |
| --- | --- | --- | --- |
| 1 | `…_gk_catalogs` | brands, pipeline_stages (UNIQUE(brand_id, id)), **org_types**, nations, sports, target_lists + RLS/grants + seeds (4 brands; stage sets; org-type vocabulary standardized with GPS; sports TBD) | — |
| 2 | `…_gk_orgs` | ALTER companies (kind, slug, ltv, updated_at, coda_row_id, legacy_ref); CREATE **company_org_types**, **org_relationships**, clubs (1:1, `league_company_id`→companies, nullable `gps_org_id`, `clubs_gps_org_idx`), **competitions** (1:1), company_brands + RLS/grants | 1 |
| 3 | `…_gk_contacts_relations` | ALTER contacts (updated_at, ext ids); CREATE company_contacts (is_primary, partial uniques, checks, role incl. `agent`), contact_social_profiles + RLS/grants; sync trigger contacts.company_id ← primary link | 2 |
| 4a | `…_gk_deals_brand_stage_nullable` | ALTER deals: brand_id/stage_id **nullable**, probability, ids; CREATE deal_modules + RLS/grants | 1,2 |
| 4b | `…_gk_deals_backfill` | Backfill brand_id/stage_id (§2.1); **explicit fail** if any ambiguous | 4a |
| 4c | `…_gk_deals_constraints` | FK brand_id→brands; composite FK (brand_id, stage_id)→pipeline_stages(brand_id, id); slug↔stage_id trigger; NOT NULL if clean | 4b |
| 5 | `…_gk_activities_tasks` | CREATE activities (targets company/contact/deal/player — **no league_id**); ALTER tasks (nullable contact_id + deal/company/activity_id + CHECK + partial unique); follow-up trigger | 3,4c |
| 6 | `…_gk_players` | CREATE players (**8 boolean funnel cols** + derived status), player_org_assignments (`org_id`→companies, club/national-team), player_citizenships, player_representations (`agency_company_id`→companies, `agent_contact_id`→contacts; normalize `agent_expiry`), player_social_profiles, player_target_lists + RLS/grants | 2 |
| 7 | `…_gk_teams_targets` | CREATE teams, team_sports, **org_target_lists** (company_id→companies) + RLS/grants | 1,2 |
| 8 | `…_gk_views` | REPLACE companies_summary/contacts_summary; extend activity_log; CREATE **current_squad** (decision C) | 2-6 |
| 9 | `…_gk_rls_audit` | Audit RLS on all new tables; roles placeholder for RBAC (M6, own model) | 1-7 |

Atomic regenerates `schemas/*.sql` from migrations — keep both consistent; confirm the flow in the repo makefile before M1-1.

## 2.1. Safe backfill of `deals.brand_id`/`stage_id`
Create brands + pipeline_stages with seeds → add columns nullable → explicit fallback mapping (default brand `xg`; map each Atomic `deals.stage` slug → a stage of that brand; vibecoded deals carry a brand) → backfill → **verify, fail explicitly** if any deal is null/unresolved → simple + composite FKs → NOT NULL if clean. `deals.stage` slug synced from `stage_id`.

## 3. Atomic tables extended (and risk)

| Table | Extension | Risk | Mitigation |
| --- | --- | --- | --- |
| companies | universal org: +kind/slug/ltv/updated_at/ids; multi-type via company_org_types | low-med | update companies_summary; `kind` mirrors primary type |
| contacts | +ids/updated_at; rich link via company_contacts | low-med | keep company_id; update contacts_summary |
| deals | +brand_id/stage_id/probability/modules; targets any org | **med-high** | brand-aware board (M2-1); slug↔stage_id trigger |
| tasks | contact_id nullable +FKs (no league_id) | **med-high** | review nb_tasks, task components, pending-only trigger |

## 4. New tables
Catalogs (brands, pipeline_stages, org_types, nations, sports, target_lists); org core (company_org_types, org_relationships, clubs [+gps_org_id], competitions, company_brands); people (company_contacts, contact_social_profiles); deals (deal_modules); activity (activities); players (players, player_org_assignments, player_citizenships, player_representations, player_social_profiles); Onesport/lists (teams, team_sports, org_target_lists, player_target_lists). Justified in doc 03.

## 5. Import order (B-P*) — bounded to the available sources
Idempotent (ON CONFLICT/upsert + count reporting; adapt `scripts/gen-seed.ts`). No automatic migration — single controlled loads.
- Catalogs + **org_types** seed → **leagues as orgs** (`League` strings → `companies` type=league + `competitions`) → **Club directory** (167 → companies+clubs, link `league_company_id`, B-P4) → **Contact intelligence** (crown jewel, B-P1) → **Email intelligence** (B-P3) → **LinkedIn** (B-P2) → **Pipeline & accounts** (B-P5/B-P7) → **Players** (bounded to the Coda CSVs: `DB_PlayerCRM` + the `DB_Clubs` list columns → player_org_assignments; decision H) → **HubSpot gaps**.
- **Source precedence (decision I):** intel/email → vibecoded · players/staff/relations → Coda · pipeline → vibecoded.
- **Import by `coda_row_id`, never by name** — club/player names are not unique (337 distinct of 352 clubs). Dedup staff by (name + club).

## 6. Frontend views per block
companies+clubs+competitions+brands → Accounts / Club DB / Services DB · pipeline_stages+deals+modules → per-brand Pipeline + xG Revenue · contacts+company_contacts+social → Contacts directory · activities+tasks → Outreach tracker + Tasks + follow-up loop · players+org_assignments+reps → Player CRM (post-v1) · org_relationships → org hierarchy views (post-v1) · teams+sports → Onesport tagging · target_lists → Hit list/targets.

## 7. Rollout risks
- **Per-brand Kanban (`deals.stage`):** biggest change over Atomic; isolate in M2-1 with e2e board tests.
- **`tasks.contact_id` nullable:** may break nb_tasks/MobileTasksList/pending-only trigger → tasks regression suite first.
- **`*_summary` views:** update them or new columns are silently invisible → per-migration checklist.
- **Data cleanup (real findings — flag a cleanup phase, don't block the schema):**
  - `xg_status` uniformly `Pending` → no enum; `*_status` fields stay **free text + normalized on import** (case/trim; decision J).
  - `agent_expiry` mixed formats → normalize to `date`; **month-only → last day of month** (decision 10).
  - `Nation` codes dirty (Aberdeen=ENG) → clean against `nations`.
  - `Insta Status` case dup (Private/PRIVATE); `Relationship` labels → normalize.
  - corrupt email domains, `contract_end`/`close` as text → date, multi-currency Shopify totals, Age without DOB.
- **Native arrays vs junctions:** keep `tags`/`contact_ids` as arrays.
- **GPS link non-enforced:** `clubs.gps_org_id` is a nullable, optional logical reference (no FK); filled manually on deal-won if useful (doc 05 §0).
- **Interim RLS `using(true)`:** fine at launch; own RBAC at M6.

## 8. Verify in `gk-crm-dev` first
Branch → migrations; push **only to dev**. Register `<Resource>` + full-text; smoke test list/create/edit/show. Run the idempotent importer; **count report** vs targets (167/83/51/103/88/7); re-run for idempotency. Per-block checks: Kanban persists stage + correct per-brand forecast + stage belongs to brand; backfill leaves zero null/incoherent; outreach→deal→**one** follow-up; company_contacts primary/mirror correct (incl. a coach at a club **and** a national-team org); player owned+current+national-team coexist; `current_squad` coherent; org_relationships render the league pyramid / rights-holder geo-split. Green e2e → merge. Backup prod + verify → controlled migration to prod.

## 9. Sequence → milestones
- **M0:** infra + **Google OAuth on Supabase** + theming + M0-9 (Coda walkthrough with Diego — now scoped to **standardizing vocabulary**, the schema decision is made) + source inventory.
- **M1:** migrations 1-9 + imports (catalogs → leagues-as-orgs → clubs → intel → email → LinkedIn → pipeline → players bounded to Coda) + count reconciliation.
- **M2:** per-brand Pipeline, Accounts, Contacts, CSV export.
- **M3:** Outreach + batches + promote-to-pipeline + follow-up automation → **v1**.
- **M4:** Shopify sync (+ shopify_orders, M4-1), Dashboard, Revenue, Club/Services UI, Teams tagging, Feedback, Settings.
- **M5/M6:** Gmail/WhatsApp → deal, digests; **RBAC** (own simple model, replaces `using(true)`).

> `shopify_orders` is outside the relational core of v1 (M4-1: store, optional FK to company/contact, numeric total + currency, order_date, high-value signal).
