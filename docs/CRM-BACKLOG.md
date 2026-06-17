# Goalkeeper Group CRM — Project Backlog

> **Source of truth for the build.** Derived from [CRM-REQUIREMENTS.md](./CRM-REQUIREMENTS.md),
> [CRM-BASE-RESEARCH.md](./CRM-BASE-RESEARCH.md), the 16 Jun tech review, the 17 Jun requirements feedback, and
> **Sam's CRM Handover** (Part A: 13 components ranked P1–P13; Part B: 10 data sources ranked B-P1–B-P10 with a
> recommended migration order).
> **Date:** 17 Jun 2026 · **Status:** approved, prepared for Linear import.

## How to read this

- Work is organised into **milestones** (M0–M7), each a shippable increment with a goal, dependencies, and **exit criteria**.
- Each **task** is a self-contained unit ready to become a Linear issue. Format:
  - `#### ID · Title` — the issue title.
  - **meta line** — `Labels · Estimate · Depends on · Refs`.
  - **Description** — what and why.
  - **Execution** — concrete steps / technical approach.
  - **Acceptance** — checkable "done" criteria.
- **Releases:** **v1 = M0–M3**, **v1.1 = M4**, **v1.2 = M5–M6**, **Later = M7**.
- **Refs** map to Sam's handover (`A-P*`, `B-P*`) and the requirement docs (`R*`, `FR-*`, `NFR-*`, `XR-*`, `§*`).
- **Estimates:** `S` ≤1 day · `M` 2–3 days · `L` ~1 week · `XL` >1 week (split before starting).
- **Labels:** `infra` `backend` `frontend` `data-migration` `auth` `integration` `automation` `design` `discovery` `docs`.
- **Confirmed stack:** Atomic CRM (React/TS/react-admin/shadcn) · **Supabase Cloud** (Postgres + Auth + Edge Functions),
  one project per env · **Vercel** frontend (approved) · domain **crm.goalkeeper.com** (GoDaddy DNS).

### ⚠️ Critical-path dependency
The **Coda app structure** (with Diego) and the **CRM-vs-xG data scope line** must be settled in M0 — the schema (M1)
is modelled on Coda (NFR-8) and everything downstream hangs off M1. Book this first (task **M0-9**).

---

## Release map

| Release | Milestones | Theme | Exit |
|---|---|---|---|
| **v1** | M0 · M1 · M2 · M3 | Spine + crown-jewel data, live on `crm.goalkeeper.com` | Team works real pipeline in Supabase; no localStorage; HubSpot retired |
| **v1.1** | M4 | E-commerce revenue + exec visibility + config + feedback | Shopify auto-syncs; dashboards live; feedback shipped |
| **v1.2** | M5 · M6 | Kill manual entry + lock down access | Email/WhatsApp → deals; RBAC enforced |
| **Later** | M7 | AI, templates, pricing catalog, mobile | — |

---

## M0 · Foundation & Infrastructure
**Release:** v1 · **Goal:** a deployed, empty Atomic CRM across three environments with Google sign-in working — the platform everything is built on. · **Depends on:** nothing (start immediately).
**Exit:** empty Atomic CRM live at staging; Google login restricted to the domain; 3 envs + CI green; signed-off Coda schema notes in hand.

### M0-1 · Fork & scaffold Atomic CRM
`infra` `frontend` · **Est:** M · **Depends:** — · **Refs:** research §3.1
**Description:** Stand up the Atomic CRM codebase as our base and confirm it runs against a Supabase backend, then set the branch model for three environments.
**Execution:**
- Fork `marmelab/atomic-crm` into the Goalkeeper org; clone; install (Node 18+, npm).
- Run the local Supabase stack via Docker (`make start` / `npx supabase start`); boot the app and confirm the demo (login, Deals Kanban, Contacts) works.
- Set the branch model: `main`→prod, `staging`→staging, feature branches→PR previews; enable branch protection + required checks on `main`/`staging`.
- Remove the demo seed we won't use; keep the schema/migration scaffolding and the resource structure.
**Acceptance:**
- [ ] App runs locally against local Supabase; can sign in and browse resources.
- [ ] Repo in Goalkeeper org with the 3-branch model + protection.

### M0-2 · Provision Supabase Cloud (dev / staging / prod)
`infra` `backend` · **Est:** S · **Depends:** — · **Refs:** NFR-4
**Description:** Three isolated Supabase projects so staging and prod never share data.
**Execution:**
- Create three Supabase Cloud projects: `gk-crm-dev`, `gk-crm-staging`, `gk-crm-prod`.
- Record URLs + anon/service keys in the team secret store (1Password/Vault), not in git.
- Set connection-pooling mode and project region (EU/UK for proximity); enable Point-in-Time-Recovery on prod if on Pro.
- Link the repo to each project (`supabase link --project-ref …`) via env-scoped config.
**Acceptance:**
- [ ] Three projects exist; keys stored securely; repo can target each via env.

### M0-3 · Vercel project + environment mapping
`infra` `frontend` · **Est:** S · **Depends:** M0-1, M0-2 · **Refs:** C1
**Description:** Host the SPA on Vercel with git-driven environments and per-env configuration.
**Execution:**
- Create the Vercel project from the repo; set framework preset (Vite) and build command.
- Map deployments: `main`→Production, `staging`→a Staging environment, PRs→Preview.
- Add per-environment env-vars: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, Google OAuth client IDs — scoped to prod/staging/preview.
**Acceptance:**
- [ ] Pushing to each branch deploys to the correct Vercel environment with the right Supabase project wired.

### M0-4 · Domain & SSL (crm.goalkeeper.com)
`infra` · **Est:** S · **Depends:** M0-3 · **Refs:** C1
**Description:** Point the company subdomains at Vercel with automatic TLS.
**Execution:**
- In Vercel add domains `crm.goalkeeper.com` (prod) and `staging.crm.goalkeeper.com` (staging).
- In GoDaddy DNS add CNAME `crm`→`cname.vercel-dns.com` (and `staging.crm`); leave the apex `goalkeeper.com` untouched.
- Verify Vercel auto-provisions SSL; force HTTPS.
**Acceptance:**
- [ ] Both subdomains resolve over HTTPS and serve the correct environment.

### M0-5 · Google OAuth (restricted to @goalkeeper.com)
`auth` `backend` · **Est:** M · **Depends:** M0-2, M0-4 · **Refs:** R21, FR-AUTH-1, research §5
**Description:** Sign-in via Google Workspace, limited to company accounts.
**Execution:**
- Create a Google Cloud OAuth client (Workspace); set authorized redirect URIs to the Supabase auth callback for each env + the Vercel domains.
- Enable the Google provider in each Supabase project; pass the `hd=goalkeeper.com` hint from the login flow.
- Enforce the domain server-side: a **Supabase "before user created" / pre-signup auth hook** (or trigger on `auth.users`) that rejects emails not ending `@goalkeeper.com`.
- Replace Atomic's stub/login with the Supabase Google sign-in.
**Acceptance:**
- [ ] A `@goalkeeper.com` Google account signs in on all envs; a non-domain account is rejected.

### M0-6 · Baseline access model (single role)
`auth` `backend` · **Est:** S · **Depends:** M0-5 · **Refs:** NFR-1
**Description:** Launch simple — any authenticated team member has full access; real RBAC comes in M6.
**Execution:**
- Keep RLS enabled with an "authenticated full access" policy on all tables (mirrors the prototype's `for all to authenticated using (true)`).
- Document that this is intentional interim posture; leave a `roles` placeholder for M6.
**Acceptance:**
- [ ] Signed-in users have full read/write; anonymous access is blocked by RLS.

### M0-7 · CI/CD pipeline
`infra` · **Est:** M · **Depends:** M0-2, M0-3 · **Refs:** NFR-4
**Description:** Automated build, migration, and deploy per environment.
**Execution:**
- GitHub Actions: lint + typecheck + tests on PRs; on merge to `staging`/`main` run `supabase db push` against the matching project and deploy the frontend via Vercel.
- Deploy Edge Functions (`supabase functions deploy`) in the same workflow.
- Gate deploys on green checks; surface migration failures loudly.
**Acceptance:**
- [ ] Merge to `staging` migrates + deploys staging automatically; same for `main`→prod; failed checks block deploy.

### M0-8 · Backups & restore runbook
`infra` `backend` · **Est:** S · **Depends:** M0-2 · **Refs:** —
**Description:** Ensure data is recoverable before real data lands.
**Execution:**
- Confirm Supabase automated daily backups (+ PITR on prod if available); set retention.
- Write a short restore runbook; perform one test restore on dev.
**Acceptance:**
- [ ] Backups confirmed on all envs; a test restore on dev succeeded and is documented.

### M0-9 · Coda structure walkthrough & schema scope (with Diego) — GATING
`discovery` `backend` · **Est:** M · **Depends:** — · **Refs:** NFR-8, §8.2, §8.8
**Description:** Capture the Coda data structure and nested hierarchies so the M1 schema is congruent across systems, and draw the CRM-vs-xG-product data boundary.
**Execution:**
- Get access to the Coda app; walk it with Diego. Document entities and hierarchy (org → team; club / position / goalkeeper / competition level) and how they nest.
- Decide explicitly which player/goalkeeper data lives in the CRM vs the xG product DB.
- Produce an ERD draft + entity/field list to feed M1-1; flag any many-to-many relationships for junction tables.
**Acceptance:**
- [ ] Written schema notes + ERD draft signed off by Diego and Sam; scope line recorded.

### M0-10 · Data-source inventory & HubSpot exit plan
`discovery` `data-migration` · **Est:** M · **Depends:** — · **Refs:** A3, §8.8
**Description:** Catalogue every data source, owner, and shape so migration tasks (M1) are concrete, and plan the HubSpot decommission.
**Execution:**
- Inventory: HubSpot, Coda, `Contact 2026.xlsx`, prototype `src/lib/data/*`, Shopify — for each note owner, format, record counts, and target table.
- Define the HubSpot export (what to pull that isn't already captured) and an archive/cutover date.
**Acceptance:**
- [ ] Inventory doc with owner + shape + target table per source; HubSpot export + decommission plan agreed.

### M0-11 · Theming: brand accents on Atomic
`design` `frontend` · **Est:** M · **Depends:** M0-1 · **Refs:** NFR-3, §9.1
**Description:** Apply the brand palette to Atomic's shadcn theme; defer a full "Command Centre" re-skin.
**Execution:**
- Define brand accents as theme tokens: xG `#FF0092`, Onesport `#9B1B30`, Calma `#CEAD54`, .com `#00F07B`.
- Pick a distinct **primary-action** colour so it doesn't collide with the `.com` green (`#00F07B`).
- Set app title/logo via Atomic's configuration; wire brand colour into deal/brand chips.
**Acceptance:**
- [ ] Brand accents applied across the app; primary-action colour is visually distinct from `#00F07B`.

---

## M1 · Data model & crown-jewel migration
**Release:** v1 · **Goal:** the centralized schema for all four brands + every high-value data source migrated and reconciled (Sam's build steps 1–3). · **Depends on:** M0 (esp. M0-9).
**Exit:** schema on all 3 envs; all source data imported and **counts reconciled; zero loss vs prototype**; HubSpot data exported.

### M1-1 · Centralized schema (single Postgres DB)
`backend` `data-migration` · **Est:** L · **Depends:** M0-9 · **Refs:** A-P1, R15, NFR-8
**Description:** Model the whole domain in one schema, congruent with Coda — the foundation every other table joins to.
**Execution:**
- Author `supabase/migrations/*.sql` for: `companies`/orgs, `contacts`, `clubs`, `services`, `deals`, `outreach_logs`, `tasks`, plus football-domain tables from M0-9. Reuse the prototype's `supabase/migrations/0001_schema.sql` as a starting spec.
- Define keys, foreign keys, indexes, and enums; keep timestamps + `created_at`.
- Register matching **react-admin resources** in Atomic (`<Resource>` per table) with the Supabase data provider.
**Acceptance:**
- [ ] Migrations apply cleanly to dev/staging/prod; resources list/show/edit in the app.

### M1-2 · Multi-business mapping (junction tables)
`backend` · **Est:** M · **Depends:** M1-1 · **Refs:** R16, XR-1
**Description:** Let a contact or company belong to multiple brands/clubs/businesses without duplication.
**Execution:**
- Add junction tables (e.g. `contact_companies`, `company_brands`, `contact_clubs`) with composite keys + roles.
- Expose them in Atomic as reference/many-to-many inputs (react-admin `<ReferenceManyField>` / array inputs).
**Acceptance:**
- [ ] A single contact can be linked to multiple orgs/brands/clubs and surfaces under each.

### M1-3 · Per-brand pipeline stages (config-driven)
`backend` `frontend` · **Est:** M · **Depends:** M1-1 · **Refs:** XR-1, FR-PIPE-2
**Description:** Four brands with different stage sets, driven by config rather than hardcoded.
**Execution:**
- Store stage definitions per brand (xG 8 / Onesport 6 / Calma 6 / .com 6) in a config table or Atomic's configuration context.
- Make `deals.stage` + `deals.brand` resolve against the right set; derive probability from stage position (preserve the brand→stage→probability convention).
**Acceptance:**
- [ ] Switching brand shows that brand's stages; probability auto-derives correctly.

### M1-4 · Team entity (level + sports) + sport taxonomy
`backend` · **Est:** M · **Depends:** M1-1 · **Refs:** R22, R23, §2.12
**Description:** The Onesport unit — a Team with one level and one or more sports, nested under an org.
**Execution:**
- Add `teams` table: `org_id` FK, `level` enum (Grassroots/School/University/Club, single), and a `team_sports` junction for multi-select sports.
- Seed the all-sports taxonomy (pull the BBC Sport "all sports" list during this task) into a `sports` lookup table.
**Acceptance:**
- [ ] Teams nest under orgs; level is single, sports multi; taxonomy seeded.

### M1-5 · xG deal modules
`backend` · **Est:** S · **Depends:** M1-1 · **Refs:** R24
**Description:** Multi-select modules captured on xG deals.
**Execution:**
- Add a `deal_modules` junction (or array column) with values `Ongoing Support`, `Transfer Market Support`, `Opposition Analysis`, `API`.
- Constrain to the xG brand; UI wiring lands in M2-2.
**Acceptance:**
- [ ] An xG deal can hold one or more modules, persisted.

### M1-6 · Contact-intelligence & email-pattern models
`backend` · **Est:** M · **Depends:** M1-1 · **Refs:** XR-2, XR-3
**Description:** The bespoke football intel layer — decision-maker roles, notes, LinkedIn, and house email formats.
**Execution:**
- Model SD / Head of Recruitment / GK Coach roles on the club/contact relationship + free-text intel notes + per-person LinkedIn URL.
- Add an `email_patterns` table (`club_id`, `domain`, `pattern`); implement a derivation helper (`name + pattern + domain → email`), app-side or as a Postgres function.
**Acceptance:**
- [ ] Intel + patterns are queryable; email derivation returns correct addresses for sampled clubs.

### M1-7 · Migrate contact intelligence (crown jewel)
`data-migration` · **Est:** M · **Depends:** M1-6 · **Refs:** B-P1
**Description:** The hardest-to-recreate asset — months of manual research; migrate first.
**Execution:**
- Transform the prototype `src/lib/data/contacts.ts` (CONTACTS_DB) + verified records into the intel tables.
- Validate roles/notes; preserve "verified <date>" annotations.
**Acceptance:**
- [ ] 83 verified records across 75 clubs imported; spot-check matches source.

### M1-8 · Migrate club directory (167 clubs)
`data-migration` · **Est:** S · **Depends:** M1-1 · **Refs:** B-P4
**Description:** The foundational reference every table joins to.
**Execution:**
- Import `src/lib/data/clubs.ts` → `clubs` (id, name, tier, country, crest).
**Acceptance:**
- [ ] 167 clubs present with tier/country; counts reconciled.

### M1-9 · Migrate email intelligence (103 clubs)
`data-migration` · **Est:** M · **Depends:** M1-6 · **Refs:** B-P3
**Description:** Domain + naming pattern for 103 clubs (from `Contact 2026.xlsx`: 674 clubs / 1,707 contacts) to derive current-staff addresses.
**Execution:**
- Import `src/lib/data/club_emails.ts` patterns + on-file contacts into `email_patterns`/contacts.
- Verify derivation produces plausible addresses for the 103 clubs.
**Acceptance:**
- [ ] Patterns for 103 clubs imported; derivation verified on a sample.

### M1-10 · Migrate verified LinkedIn profiles
`data-migration` · **Est:** S · **Depends:** M1-7 · **Refs:** B-P2
**Description:** 51 decision-maker profiles across 42 clubs — direct routes to buyers.
**Execution:**
- Attach the LinkedIn URL map (from CONTACTS_DB `linkedin`) to the matching contacts.
**Acceptance:**
- [ ] 51 profiles linked to the right people across 42 clubs.

### M1-11 · Load live pipeline & account state
`data-migration` · **Est:** M · **Depends:** M1-1, M1-3 · **Refs:** B-P5, B-P7
**Description:** The actual working commercial data — preserve on migration.
**Execution:**
- Import `src/lib/data/deals.ts` + account overlay → `deals`/`companies` with stage, value, prob, owner, close.
- Include 88 Onesport grassroots leads (B-P7) and 7 xG LinkedIn leads.
**Acceptance:**
- [ ] Active xG deals, accounts, LTV + 88 Onesport + 7 xG leads imported; reconciled vs prototype.

### M1-12 · HubSpot export & archive
`data-migration` · **Est:** S · **Depends:** M0-10 · **Refs:** A3
**Description:** Pull anything in HubSpot not already captured and archive it before decommission.
**Execution:**
- Export HubSpot contacts/companies/deals; diff against migrated data; import any gaps; store the raw export read-only.
**Acceptance:**
- [ ] Export archived; gaps reconciled; HubSpot decommission scheduled.

### M1-13 · Migration tooling (idempotent importer)
`data-migration` `backend` · **Est:** M · **Depends:** M1-1 · **Refs:** NFR-7
**Description:** Re-runnable import so loads can be repeated safely as the schema settles.
**Execution:**
- Adapt `scripts/gen-seed.ts` to emit the new schema's SQL with `ON CONFLICT DO NOTHING`/upserts.
- Add a verification step that prints row counts per table vs expected.
**Acceptance:**
- [ ] Importer is idempotent; re-running doesn't duplicate; count report matches targets.

---

## M2 · Core CRM surfaces
**Release:** v1 · **Goal:** the everyday system of record — Pipeline, Accounts, Contacts (Sam's build step 4). · **Depends on:** M1.
**Exit:** per-brand kanban persists; accounts & contacts searchable/filterable with CSV; deal CRUD (incl. modules + club link) persists.

### M2-1 · Pipeline (Kanban) per brand
`frontend` · **Est:** L · **Depends:** M1-3 · **Refs:** A-P2, FR-PIPE-1/3/4
**Description:** The primary sales surface — a drag-drop board per brand with live forecasting.
**Execution:**
- Extend Atomic's Deals Kanban so stage columns switch by selected **brand** (using M1-3 config).
- Persist stage changes via the Supabase data provider on drop.
- Show board summary: Closed Won sum + Weighted Pipeline (Σ value×prob of open deals); per-column totals.
**Acceptance:**
- [ ] Stage moves persist to Supabase; brand switch reflows columns; forecast totals correct.

### M2-2 · Deal create/edit modal (club link + xG modules)
`frontend` · **Est:** M · **Depends:** M2-1, M1-5 · **Refs:** A-P2, R24, FR-PIPE-5
**Description:** Full deal CRUD with account linking and xG module selection.
**Execution:**
- Build the create/edit form (name, client, contact, org, brand, stage, value, prob, last-contact, close, notes) with a live weighted-value preview.
- Add the **club/account picker** (reference input) and the **xG modules** multi-select (visible for xG brand).
**Acceptance:**
- [ ] Create/edit/delete persists; modules + linked account saved and shown.

### M2-3 · Add-lead from club picker (multi-lead per club)
`frontend` · **Est:** S · **Depends:** M2-2 · **Refs:** A-P2
**Description:** Add a deal/lead from anywhere via a club picker; clubs can hold multiple leads.
**Execution:**
- Provide an "add lead" entry point that pre-fills the chosen club and lands the card on the board.
**Acceptance:**
- [ ] Adding from the picker creates a card under that club; multiple leads per club supported.

### M2-4 · Accounts list + detail
`frontend` · **Est:** L · **Depends:** M1-1 · **Refs:** A-P3, FR-ACC-1..4
**Description:** System of record for who we sell to.
**Execution:**
- List: search (name/city/tier), brand filter, "with deals" toggle, sort by LTV/name; one row per account with brand badge, stage, LTV, GK contact, next action, last touch.
- Detail page: overview (location, keeper count, LTV), key contacts (SD/HoR/GK + email), active deal with stage-progress bar, notes/intel, next action, all-deals table.
- Compute LTV from won-deal value (or curated value).
**Acceptance:**
- [ ] List filters/sorts correctly; detail page renders live data incl. all-deals table.

### M2-5 · Contacts directory
`frontend` · **Est:** M · **Depends:** M1-6 · **Refs:** A-P4, FR-CON-1..3
**Description:** The relationship layer — one row per person across clubs and services.
**Execution:**
- Flatten SD/HoR/GK + service secretaries into a contacts list; brand + role filters; search name/org/league/email.
- Surface email (on-file → derived from pattern), phone, and verified LinkedIn; show coverage stats.
**Acceptance:**
- [ ] Directory lists people with derived emails + LinkedIn; filters work.

### M2-6 · CSV export on directories
`frontend` · **Est:** S · **Depends:** M2-4, M2-5 · **Refs:** XR-9, FR-CON-4
**Description:** Preserve the prototype's "CSV export on every directory."
**Execution:**
- Use react-admin's exporter (custom column mapping) on Accounts, Contacts (and later directories).
**Acceptance:**
- [ ] Each directory exports a correctly-columned CSV of the current filtered view.

---

## M3 · Outreach growth loop  →  v1 release
**Release:** v1 · **Goal:** the differentiator — the closed outreach→pipeline→task loop and league prospecting (Sam's build step 5). · **Depends on:** M1, M2.
**Exit (v1 acceptance):** all of —
1. Google sign-in (`@goalkeeper.com`); data in Supabase, persists across devices; localStorage retired.
2. Data parity reconciled (167 clubs · 83 intel · 51 LinkedIn · 103 email-pattern clubs · live deals/accounts · 88 Onesport · 7 xG leads); zero loss; HubSpot archived.
3. Per-brand kanban drag-drop persists; weighted forecast correct; add-lead-from-club-picker works.
4. Outreach → pipeline → dated follow-up loop works end-to-end and persists.
5. Accounts/Contacts/Leagues searchable/filterable; emails/LinkedIn/phone surfaced; CSV export.
6. Deployed to `crm.goalkeeper.com` with a working staging env and automated backups.

### M3-1 · Outreach tracker (status + coverage)
`frontend` · **Est:** M · **Depends:** M2-1 · **Refs:** A-P5, FR-OUT-1/2
**Description:** Top-of-funnel tracker with derived status and coverage.
**Execution:**
- Build unified prospect rows (clubs=xG / services=Onesport) with contact + best email + LinkedIn.
- Derive status (Target / In-Pipeline / Won) from the prospect's best deal; add status filter and a coverage % stat (worked ÷ total), scoped per segment.
**Acceptance:**
- [ ] Status derives correctly; coverage % accurate; segments kept separate.

### M3-2 · "Batches of 10" working view
`frontend` · **Est:** M · **Depends:** M3-1 · **Refs:** A-P5, FR-OUT-3
**Description:** Work the cold list in stable teams of 10 ordered by send-readiness.
**Execution:**
- Partition prospects into batches of 10, ordered by readiness (named lead + email > named lead > needs research); exclude media/analytics + national federations from club batches.
- Show per-batch progress (e.g. 7/10, ✓ when fully worked).
**Acceptance:**
- [ ] Batches are stable across filters; progress reflects worked prospects.

### M3-3 · Log outreach → promote to pipeline
`frontend` `automation` · **Est:** M · **Depends:** M3-1, M2-2 · **Refs:** A-P5, FR-OUT-4
**Description:** The funnel-entry action — logging an outreach creates/updates the deal.
**Execution:**
- Modal: pick stage (probability auto-derived), contact (name/email), date, optional value, note.
- New target → create a pipeline deal; existing → update in place. Surface the club intel note inline.
**Acceptance:**
- [ ] Logging a Target creates a pipeline deal; logging an existing one updates it.

### M3-4 · Follow-up automation
`backend` `automation` · **Est:** M · **Depends:** M3-3 · **Refs:** A-P6, XR-6, FR-TASK-4
**Description:** The automation to replicate carefully — every logged outreach schedules a dated follow-up.
**Execution:**
- On outreach log (account *or* league), auto-create a `task` of type `follow_up` due `date + N` (N from a None/3/7/14/30 selector), linked to the deal/league.
- Implement as a Supabase trigger or in the log mutation; ensure it can't double-fire.
**Acceptance:**
- [ ] Logging creates exactly one dated follow-up task linked to the right record.

### M3-5 · Tasks view (grouped) + manual tasks
`frontend` · **Est:** S · **Depends:** M3-4 · **Refs:** A-P6, FR-TASK-1..3
**Description:** Keep the funnel moving with grouped, actionable tasks.
**Execution:**
- List grouped Overdue / Today / Upcoming / Completed; quick-add manual tasks; toggle done; delete; distinguish follow-up vs manual; show linked league/deal.
**Acceptance:**
- [ ] Grouping by due date correct; add/toggle/delete persist.

### M3-6 · Leagues view (master–detail + per-league logging)
`frontend` · **Est:** L · **Depends:** M1-8, M3-3 · **Refs:** A-P7, FR-LG-1..4
**Description:** The day-to-day prospecting workflow, league by league.
**Execution:**
- League list with team counts + contact-coverage; per-league team table (SD/HoR/GK with derived email, LinkedIn, phone, email-format hint).
- Inline editable contact **overrides** (badge "edited"); per-league "Log outreach" (auto follow-up) + per-league history.
**Acceptance:**
- [ ] League detail shows teams/contacts; overrides persist; per-league logging + history work.

---

## M4 · Commerce, reporting, settings & feedback  →  v1.1
**Release:** v1.1 · **Goal:** bring e-commerce revenue in, give exec visibility, ship config + feedback (Sam's build steps 6–7). · **Depends on:** M1–M3.
**Exit:** Shopify auto-syncs; dashboards & revenue live; Club/Services surfaces + Team tagging live; feedback feature & settings shipped.

### M4-1 · Shopify live-API sync
`integration` `backend` · **Est:** L · **Depends:** M1-1, M0-10 · **Refs:** A-P10, R17, B-P6
**Description:** Replace Sam's manual report upload with automatic order ingestion for both stores.
**Execution:**
- Register a Shopify custom app per store (Onesport, Calma); store API credentials securely.
- Build a Supabase **Edge Function on a schedule** (pg_cron) that pulls orders → a `shopify_orders` table (store, customer, items, total, date, signal).
- Backfill Jan–Jun 2026 (Onesport 342 orders / Calma 268) then run incrementally.
**Acceptance:**
- [ ] Orders sync automatically on schedule; backfill counts match; no manual upload needed.

### M4-2 · Dashboard
`frontend` · **Est:** M · **Depends:** M2-1, M4-1 · **Refs:** A-P8, FR-DASH-1..4
**Description:** The exec/overview surface, wired to live data.
**Execution:**
- KPI cards (combined YTD revenue, xG pipeline value, per-brand YTD); Hot Deals (active deals by probability, click-to-edit); activity feed; revenue chart.
**Acceptance:**
- [ ] Dashboard reflects live DB; Hot Deals open the deal modal.

### M4-3 · Revenue reporting (configurable period)
`frontend` `backend` · **Est:** M · **Depends:** M4-1 · **Refs:** A-P9, R17, FR-REV
**Description:** Commercial reporting across brands with flexible timelines.
**Execution:**
- Won + weighted-pipeline by brand and month; xG closed-won breakdown table; Shopify revenue by store.
- Add a **weekly/monthly** period selector driving the aggregates.
**Acceptance:**
- [ ] Reports recompute by selected period; brand splits correct.

### M4-4 · Club Database & Services DB surfaces
`frontend` · **Est:** S · **Depends:** M1-8 · **Refs:** A-P11, A-P12, FR-CLUB, FR-SVC
**Description:** Read-only reference directories (data already migrated in M1).
**Execution:**
- Club Database list (search, tier filter, SD/HoR/GK + intel); Services DB list (type filter + counts, secretary, email, status).
**Acceptance:**
- [ ] Both directories browsable/filterable from live data.

### M4-5 · Onesport Team tagging UI
`frontend` · **Est:** M · **Depends:** M1-4 · **Refs:** R22, R23
**Description:** Surface and edit Team level + sports; filter by them.
**Execution:**
- Add level (single-select) + sports (multi-select) inputs on Team/org records; add list filters by level and sport.
**Acceptance:**
- [ ] Level + sports editable; lists filter by both.

### M4-6 · Feedback feature (visibility toggle)
`frontend` `backend` · **Est:** M · **Depends:** M1-1 · **Refs:** R20
**Description:** In-app feedback capture with a switch controlling who can see submissions.
**Execution:**
- Add a `feedback` table + capture UI; a visibility toggle (e.g. private vs visible-to-team) enforced via RLS/field; confirm scope with Brendan (feedback about *what*).
**Acceptance:**
- [ ] Feedback can be submitted; the toggle controls visibility as specified.

### M4-7 · Settings
`frontend` · **Est:** S · **Depends:** M0-11 · **Refs:** A-P13, FR-SET
**Description:** Standard config — build last.
**Execution:**
- Profile (name/role), default currency GBP, brand toggles (which brands appear), notification prefs, integration status (Supabase/Shopify/Gmail/WhatsApp).
**Acceptance:**
- [ ] Settings persist and affect the app (e.g. brand toggles hide/show brands).

---

## M5 · Communication integrations  →  v1.2
**Release:** v1.2 · **Goal:** eliminate manual entry from inbox/chat. · **Depends on:** M1–M3.
**Exit:** email→deal create/update works with a confirm step; WhatsApp conversations captured; digests send.
> ⏱ **Start WhatsApp procurement early (in M0/M1)** — BSP/API approval has external lead time.

### M5-1 · Gmail — log email to timeline
`integration` `backend` · **Est:** M · **Depends:** M2-4 · **Refs:** R18, NFR-6
**Description:** Surface relevant email on the account/deal activity timeline.
**Execution:**
- Set up Gmail API OAuth (Workspace); a worker/Edge Function fetches messages and matches them to contacts/accounts by email/domain; store as activity/notes.
**Acceptance:**
- [ ] Matched emails appear on the relevant account/deal.

### M5-2 · Email → create/update deals (with confirm)
`integration` `automation` · **Est:** L · **Depends:** M5-1, M2-2 · **Refs:** R25
**Description:** Parse inbound/outbound mail to create new deals or update existing ones, with a human confirm step.
**Execution:**
- Parse email (LLM-assisted, e.g. Claude) to propose a deal create/update (stage, contact, value, notes).
- Present a confirm UI; only write on approval; link the source email.
**Acceptance:**
- [ ] A parsed email proposes a deal change; on confirm it writes correctly; nothing writes without confirm.

### M5-3 · WhatsApp Business integration
`integration` `backend` · **Est:** L · **Depends:** M1-1 · **Refs:** R19
**Description:** Capture WhatsApp Business conversations against contacts.
**Execution:**
- Provision the WhatsApp Business API (Meta Cloud API or a BSP, e.g. Twilio/360dialog) + verified business + API key.
- Receive messages via webhook (Edge Function) → store against the matching contact; support outbound where allowed.
**Acceptance:**
- [ ] Inbound (and permitted outbound) messages are captured against contacts.

### M5-4 · Notification & digest delivery
`automation` `backend` · **Est:** M · **Depends:** M4-7 · **Refs:** FR-SET-3, R13
**Description:** Deliver the alerts the Settings toggles promise.
**Execution:**
- Scheduled function: weekly summary email (pipeline + revenue digest) and due-action/hot-deal alerts, gated by user prefs.
**Acceptance:**
- [ ] Enabled digests/alerts send on schedule; disabled ones don't.

---

## M6 · Access control hardening  →  v1.2
**Release:** v1.2 · **Goal:** move from "all team = full access" to real roles. · **Depends on:** M0-5/M0-6.
**Exit:** roles enforced via RLS across all tables.

### M6-1 · Define roles & permissions matrix
`discovery` `docs` · **Est:** S · **Depends:** M0-10 · **Refs:** R21, NFR-1
**Description:** Decide the roles and what each may see/do.
**Execution:**
- With Sam/Brendan, list roles (e.g. admin, sales, viewer) and map CRUD per resource into a matrix.
**Acceptance:**
- [ ] Signed-off roles × permissions matrix.

### M6-2 · RBAC implementation (RLS + JWT claims)
`auth` `backend` · **Est:** L · **Depends:** M6-1 · **Refs:** R21, research §5
**Description:** Enforce least-privilege via Postgres RLS keyed on a role claim.
**Execution:**
- Add a `roles` table; a **Custom Access Token Auth Hook** injecting `user_role` into the JWT; rewrite RLS policies to read it (replacing blanket `using(true)`), with an `authorize()` helper.
- Test each role against each table.
**Acceptance:**
- [ ] RLS enforces the matrix; verified per role; no privilege leakage.

---

## M7 · Later / nice-to-have (unscheduled)
**Release:** Later · **Goal:** value-adds once the core is solid. *(Descriptions kept light until scheduled.)*

### M7-1 · AI Intelligence surface
`frontend` `integration` · **Est:** L · **Refs:** R14
Enrichment/summarisation surface (prototype had a button only) — e.g. summarise an account's intel/activity, suggest next actions.

### M7-2 · Email templates & merge fields
`frontend` · **Est:** M · **Refs:** B-P8
Manage outreach templates with merge fields (`{First}`/`{Club}`/`{Hook}`) in-app, from `outreach-templates.md`.

### M7-3 · Product & pricing catalog
`backend` `frontend` · **Est:** M · **Refs:** B-P8
xG Pricing Master / Onesport SKUs as structured products + prices, replacing free-text deal value.

### M7-4 · Advanced reporting
`frontend` · **Est:** M · **Refs:** R10
Time-in-stage, forecasting, cohort views beyond the v1.1 dashboards.

### M7-5 · Mobile-responsive / native polish
`frontend` `design` · **Est:** M · **Refs:** NFR-3
Responsive pass (and/or native shell) for on-the-road use.

### M7-6 · Full "Command Centre" re-skin
`design` `frontend` · **Est:** L · **Refs:** NFR-3
If Atomic's default + brand accents proves insufficient, a full dark "Command Centre" theme.

---

## Traceability — Sam's Handover → milestones

**Part A (components):** P1 schema → **M1** · P2 pipeline → **M2** · P3 accounts → **M2** · P4 contacts → **M2** ·
P5 outreach → **M3** · P6 tasks → **M3** · P7 leagues → **M3** · P8 dashboard → **M4** · P9 revenue → **M4** ·
P10 Shopify → **M4** · P11 club DB → **M4** (data in M1) · P12 services DB → **M4** (data in M1) · P13 settings → **M4**.

**Part B (data, migration order):** B-P1 contact intel → **M1** · B-P2 LinkedIn → **M1** · B-P3 email intel → **M1** ·
B-P4 club DB → **M1** · B-P5 live pipeline → **M1** · B-P6 Shopify → **M4** (live API) · B-P7 Onesport leads → **M1** ·
B-P8 pricing docs → **M7** · B-P9 brand/logo → **M0** (theming) · B-P10 LinkedIn history → **M1/M3** (notes).

**Meeting/feedback requirements:** R15/R16 → M1 · R17 → M4 · R18/R19 → M5 · R20 → M4 · R21 → M0 (OAuth) / M6 (RBAC) ·
R22/R23 → M1 (schema) / M4 (UI) · R24 → M1 (schema) / M2 (UI) · R25 → M5 · NFR-8 → M0/M1.

---

## Outstanding inputs (do not block starting M0)
- **Coda structure + CRM/xG scope** (Diego) — gates **M1** schema. *Highest priority — task M0-9.*
- **Roles & permissions list** — needed for **M6** (task M6-1); informs M0-6.
- **Integration credentials** — Shopify API (M4-1), Gmail/Workspace (M5-1), **WhatsApp Business API key/BSP** (M5-3, long lead).
- **All-sports list finalisation** — pulled during **M1-4**.
- **Feedback scope** (Brendan) — what feedback is about + exact visibility semantics (M4-6).
