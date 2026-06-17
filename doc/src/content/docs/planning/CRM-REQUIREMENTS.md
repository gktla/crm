# Goalkeeper Group CRM — Requirements (reverse-engineered)

> **Status:** Extracted from the v2 vibe-coded prototype in this repo (`sam-crm`, package `goalkeeper-crm-v2`).
> **Method:** Read of the data model (`supabase/migrations/0001_schema.sql`, `src/lib/data/*`, `src/lib/store.ts`),
> every page under `src/app/crm/*`, components, and the project docs (`SUPABASE.md`, `outreach-templates.md`).
> **Purpose:** A backend-agnostic spec of *what the CRM must do*, so it can drive a build-vs-adopt decision
> (see the companion research doc).

> **🟢 Status update (16 Jun 2026 tech review):** Direction ratified — **adopt Atomic CRM** on **Supabase**, the
> prototype is **retired**, and the schema will be modelled on the company's **Coda** app. New requirements
> (integrations, feedback feature, Google OAuth/RBAC, centralized single-DB design) are captured in
> **[§8 Post-review updates](#8-post-review-updates--16-jun-2026-meeting)**, which extends the baseline below.
> Stack = Atomic CRM + Supabase Cloud + **Vercel** at **crm.goalkeeper.com**; build sequencing (v1 = M0–M3) lives in
> the **[project backlog](./CRM-BACKLOG.md)** — see [§10](#10-release-plan--backlog).

---

## 1. Context & vision

**Goalkeeper Group** is a multi-brand goalkeeping company. This product is its internal sales/operations
**"Command Centre"** — a single CRM that runs the commercial pipeline across **four distinct brands**, each with
its own buyers, sales motion, and revenue model:

| Brand | Key | Accent | What it sells | Buyer / market | Revenue model |
|-------|-----|--------|---------------|----------------|---------------|
| **Goalkeeper xG** | `xg` | Magenta `#FF0092` | Goalkeeper analytics platform (post-shot xG, shot-stopping above expected, sweeping, distribution, benchmarked across leagues) + data/API licences | Pro football clubs — Sporting Directors, Heads of Recruitment, Heads of Data/Insights, GK Coaches; agencies; leagues | High-value B2B subscriptions / licences (£5k–£250k) |
| **Onesport** | `onesport` | Maroon `#9B1B30` | **Multi-sport** kit & equipment (all sports) | B2B **& D2C**: sports clubs, schools, universities, grassroots, + UK Police / Ambulance / Fire / Prison sports sections | B2B orders + D2C Shopify |
| **Calma Goalkeeping** | `calma` | Gold `#CEAD54` | Goalkeeper gloves | D2C consumers | Shopify D2C |
| **Goalkeeper.com** | `gkcom` | Green `#00F07B` | Parent brand / content / web | Mixed | Mixed |

> **Brand accents** updated 17 Jun 2026 to the official palette (see [§9.1](#91-brand-accent-colours-updated)).

It is a **single-tenant internal tool** for a very small team (currently the founder/sales lead, "Sam Guthrie").
Every authenticated team member gets full access — there is no per-record ownership or multi-tenant isolation
(confirmed by the RLS policy: `for all to authenticated using (true)`).

The defining characteristic — and the main reason an off-the-shelf CRM is non-trivial — is that this is a
**football-industry, multi-brand CRM** with a bespoke prospecting/intelligence layer, not a generic B2B sales CRM.

---

## 2. Core domain entities

These are the objects the system manages (names/shape taken from the SQL schema, TS types, and Zustand store).

### 2.1 Account
A customer or prospect organisation (mostly football clubs, plus universities, police FCs, agencies, leagues).
- Identity: `id`, `name`, `crest`, `type`, `tier` (league/competition), `country`, `city`
- Commercial: `brands[]` (which product lines apply), `ltv` (lifetime value), `contract_end`
- Football-specific: `coach` (GK coach), `keeper_count` (keepers in squad)
- Workflow: `next_action`, `next_due`, `last_contact`
- **Requirement:** an Account may relate to **multiple brands** and hold **multiple deals**.

### 2.2 Deal (opportunity)
- `id`, `brand`, `account_id`, `name`, `value` (£), `stage` (index into the brand's stage list), `prob` (%),
  `owner`, `close` (expected close date)
- Extended: `clientName`, `contactNumber`, `organization`, `lastContact`, `notes`
- **xG modules (17 Jun):** xG deals carry a **multi-select `modules[]`** — `Ongoing Support`, `Transfer Market Support`,
  `Opposition Analysis`, `API` — chosen/updated through the sales cycle. *(See [§9.3](#93-xg--deal-modules-new).)*
- **Requirement:** each deal belongs to exactly one brand; **stage sets are per-brand** (see §3.1);
  weighted value = `value × prob%`.

### 2.3 Club (scouting universe / directory)
A reference directory of **~170 clubs** that is *broader than the customer list* — the addressable market.
- `id`, `name`, `crest`, `tier` (league), `country`
- **Requirement:** the club directory is a distinct dataset from Accounts; clubs get "promoted" into the
  pipeline as deals when worked.

### 2.4 Contact intelligence (per club)
Keyed by club/account — the decision-maker map for football clubs.
- `sd` (Sporting Director), `hor` (Head of Recruitment), `gk_coach` (Goalkeeper Coach), `notes` (free-text intel)
- `linkedin`: map of *person name → verified LinkedIn profile URL*
- **Requirement:** a club has named role-holders (often `TBC`), rich free-text intel notes (manager, data
  contact, recent moves, "verified <date>"), and verified LinkedIn links per person.

### 2.5 Club email intelligence (`CLUB_EMAILS`)
Email-discovery support per club.
- `domain`, `pattern` (house email format, e.g. `{first}.{last}`, `{f}{last}`),
  `contacts[]` (name, role, email, mobile) — a contacts-on-file list (≈2023 vintage, "verify names")
- **Requirement:** the system must **derive a likely email** from `person name + house pattern + domain`,
  and surface known on-file contacts.

### 2.6 Service (Onesport B2B target)
UK emergency-services sports sections — Onesport's B2B target market (~20 seeded).
- `id`, `name`, `type` (`Police` / `Ambulance` / `Fire` / `Prison`), `region`, `country`,
  `sports_secretary`, `email`, `sports`, `status` (`Prospect` …), `notes`
- **Requirement:** a separate prospect vertical with its own type taxonomy and status.
- **Onesport tagging (17 Jun):** Onesport supplies **all sports** (not just GK) to a market **wider than emergency
  services** — sports **clubs, schools, universities, grassroots** too. The unit is a **Team** with a single
  **level** (Grassroots / School / University / Club) and **one or more sports** — see [§2.12](#212-team-onesport-unit)
  and [§9.2](#92-onesport--all-sports-tagging--organisation-level-new).

### 2.7 Shopify order
D2C order records for Onesport + Calma (top orders imported from "v1").
- `id`, `store` (`Onesport` / `Calma`), `cust`, `items`, `total`, `when_label`, `signal` (e.g. `High-value`)

### 2.8 Outreach log (activity)
Append-only activity per account.
- `account_id`, `status`, `contact`, `note`, `logged_at`
- **Requirement:** immutable activity trail; `status` is an outreach stage
  (`not_started`/`emailed`/`called`/`linkedin`/`responded`/`meeting`/`demo`/`proposal`/`won`/`dead`).

### 2.9 Task
- `id`, `title`, `due` (date), `done`, `type` (`follow_up` | `manual`), optional `dealId`, optional `league`
- **Requirement:** tasks can be linked to a deal or a league; follow-ups are auto-generated (see §3.5).

### 2.10 League log
Outreach logged at **league level** (e.g. "SD email blast — 20 clubs").
- `league`, `contact`, `note`, `completed` (date), `followUpDays`
- **Requirement:** logging a league outreach **auto-creates a follow-up task** `completed + followUpDays` days out.

### 2.11 Contact override
User edits to a club's contact record (SD/HoR/GK coach/email/phone/notes), merged over the static directory,
flagged as "edited" with `updatedAt`.

### 2.12 Team (Onesport unit)
*Added 17 Jun 2026.* The unit Onesport supplies kit to. Each Team belongs to a parent organisation (a club, school,
university, grassroots group, or service) and has:
- `level` — **exactly one of** Grassroots / School / University / Club
- `sports[]` — **one or more** sports (multi-select; all-sports taxonomy)
- **Requirement:** an organisation can field **multiple teams** across multiple sports (nested hierarchy), so Team is
  a first-class record under the org — not just tags on the company. Detail: [§9.2](#92-onesport--all-sports-tagging--organisation-level-new).

---

## 3. Functional requirements (by capability)

### 3.1 Multi-brand pipeline (Kanban) — `/crm/pipeline`
- **FR-PIPE-1** Per-brand Kanban board; brand switcher (xG / Onesport / Calma / Goalkeeper.com).
- **FR-PIPE-2** Each brand has its **own ordered stage set**, e.g.
  - xG (8): Target → Initial Conversation → Re Engage → Demo → Qualified To Buy → Proposal Sent → Decision Maker Bought-In → Closed Won
  - Onesport/Calma (6): Prospect → Contact made → Sample sent → Quote issued → PO received → Shipped / Won
  - Goalkeeper.com (6): Lead → Qualified → Meeting booked → Proposal sent → Negotiation → Closed Won
- **FR-PIPE-3** **Drag-and-drop** a deal card between stages; persist the new stage.
- **FR-PIPE-4** Per-column totals; board summary: **Closed Won** sum and **Weighted Pipeline** (Σ `value × prob%` of open deals).
- **FR-PIPE-5** Create / edit / delete a deal via a modal (name, client, contact number, organization, brand,
  stage, value, probability, last-contact date, expected close, notes; live weighted-value preview).

### 3.2 Accounts — `/crm/accounts` and `/crm/accounts/[id]`
- **FR-ACC-1** Master account list = club directory + non-club extras (universities, police FCs, agencies).
- **FR-ACC-2** Search (name/city/tier), brand filter, "with deals only" filter, sort by LTV or name.
- **FR-ACC-3** Per row: brand badge, tier, current deal stage + probability (or "Add deal"), **LTV**
  (curated value, else Σ won-deal value), GK contact, next action + due, last touch.
- **FR-ACC-4** Account detail page: overview (location, keeper count, LTV), **key contacts** (SD/HoR/GK coach
  with email), active deal with **stage-progress bar**, notes/intel, next action, and an all-deals table.

### 3.3 Outreach tracker — `/crm/outreach`
The prospecting cockpit. Two fully separate segments: **Pro Clubs · xG** and **Services · Onesport**.
- **FR-OUT-1** Unified prospect rows from the club directory (xG) and services DB (Onesport), with contact name,
  best email, and verified LinkedIn link.
- **FR-OUT-2** Status derived from the prospect's best pipeline deal: **Target / In Pipeline / Won**;
  filter by status; **coverage %** = worked ÷ total.
- **FR-OUT-3** **"Batches of 10"** workflow: prospects partitioned into stable teams of 10, ordered by
  **send-readiness** (named lead + email > named lead > needs research); each batch shows progress (e.g. `7/10`, ✓).
  Media/analytics orgs and national federations are excluded from club outreach batches.
- **FR-OUT-4** **Log-outreach modal** that **promotes a Target into the pipeline**: pick stage (probability
  auto-derived from stage position), contact (name/email), date, optional deal value, note, and a
  **follow-up reminder** (None/3/7/14/30 days) that creates a task. Existing deals are updated in place.
  Surfaces the club's intel note inline.
- **FR-OUT-5** **Export the current view to CSV.**

### 3.4 Leagues — `/crm/leagues`
- **FR-LG-1** League directory derived from the club directory, with per-league **team count** and **contact-coverage** count.
- **FR-LG-2** Per-league team table showing SD / HoR / GK coach, with:
  - derived/clickable email (`mailto:`) from the club's house format,
  - verified LinkedIn link per person,
  - phone (`tel:`), email-format hint, and a "+N contacts on file" expander.
- **FR-LG-3** **Edit a team's contacts inline** (SD/HoR/GK coach/email/phone/notes) — stored as an override,
  badged "edited".
- **FR-LG-4** **Log outreach at league level** → auto-creates a follow-up task; per-league **outreach history** list.

### 3.5 Tasks & follow-up automation — `/crm/tasks`
- **FR-TASK-1** Quick-add tasks with a due date.
- **FR-TASK-2** Auto-grouped: **Overdue / Today / Upcoming / Completed**; toggle done; delete.
- **FR-TASK-3** Distinguish **follow-up** (auto-generated) from **manual** tasks; show linked league.
- **FR-TASK-4 (automation):** Logging an outreach (account or league level) **auto-creates a follow-up task**
  due `date + N days`. This is the core workflow automation of the product.

### 3.6 Contacts directory — `/crm/contacts`
- **FR-CON-1** Flattened people directory across all clubs (SD/HoR/GK coach) and services (sports secretary).
- **FR-CON-2** Filter by brand and by role; search name/org/league/email.
- **FR-CON-3** Per person: best **email** (on-file → derived from house format → parsed from notes), **phone**,
  **verified LinkedIn**; coverage stats (emails / LinkedIn / phones).
- **FR-CON-4** **Export to CSV.**

### 3.7 Revenue — `/crm/revenue`
- **FR-REV-1** KPI cards: Combined YTD, xG Closed-Won, Onesport (Shopify), Calma (Shopify).
- **FR-REV-2** Monthly Shopify revenue chart (grouped bar) + store split trend line (Onesport vs Calma).
- **FR-REV-3** xG closed-won deals breakdown table with total.

### 3.8 Shopify (D2C) — `/crm/shopify`
- **FR-SHOP-1** KPI tiles: combined net, per-store net, order counts, average order value.
- **FR-SHOP-2** Order table (store filter, search) with a **high-value signal** flag.
- **FR-SHOP-3 (future):** live Shopify order sync for Onesport + Calma (currently manual import).

### 3.9 Services database — `/crm/services`
- **FR-SVC-1** Directory of UK Police / Ambulance / Fire / Prison sports sections (Onesport target market).
- **FR-SVC-2** Filter by type (with counts) + search; show sports secretary, email, sports, status, intel notes.

### 3.10 Club database — `/crm/clubs`
- **FR-CLUB-1** Full ~170-club directory; search (name/country/SD/GK coach) + league/tier filter.
- **FR-CLUB-2** Show SD / HoR / GK coach + intel notes; "with contact intel" count.

### 3.11 Dashboard — `/crm`
- **FR-DASH-1** KPI cards (combined YTD revenue, xG pipeline value, per-brand YTD).
- **FR-DASH-2** **Hot Deals** widget: top active deals (stage > 0, not won) by probability then value, click-to-edit.
- **FR-DASH-3** Activity feed of recent commercial events.
- **FR-DASH-4** Shopify revenue chart.

### 3.12 Settings — `/crm/settings`
- **FR-SET-1** Profile (name, role); default currency = **GBP £**.
- **FR-SET-2** **Toggle active brands** (which product lines appear across the CRM).
- **FR-SET-3** Notification toggles: hot-deal movement, actions due, new Shopify orders, weekly summary email.
- **FR-SET-4** Data/integration status (Supabase, Shopify sync).

### 3.13 Auth — `/login`
- **FR-AUTH-1** Email/password sign-in restricted to Goalkeeper Group team members.
- **FR-AUTH-2** All `/crm/*` routes gated behind login (session middleware).

---

## 4. Cross-cutting / domain-specific requirements

These are the things a generic CRM does **not** give you for free, and that make this product specific:

- **XR-1 Multi-brand by design.** Four product lines, each with **independent pipeline stages**, colour identity,
  separate revenue tracking, and a global brand switcher/filter. xG and Onesport prospect lists are kept fully separate.
- **XR-2 Football data model.** Clubs carry `tier`/league, `keeper_count`, `contract_end`; decision-makers are
  modelled by football role (Sporting Director, Head of Recruitment, GK Coach). A **scouting-universe directory**
  (~170 clubs across leagues) is distinct from the customer/account list.
- **XR-3 Email intelligence.** Per-club **house email-format patterns** (`{first}.{last}@domain` etc.) used to
  **derive likely emails**; plus a contacts-on-file list and verified LinkedIn profile URLs per person.
- **XR-4 Emergency-services vertical.** UK Police/Fire/Prison/Ambulance sports sections as a first-class B2B
  prospect type for Onesport, with their own taxonomy and statuses.
- **XR-5 Outreach-first prospecting.** Batch ("teams of 10") working of a large cold list, readiness scoring,
  coverage %, and **Target → pipeline promotion** as the primary funnel-entry action.
- **XR-6 Follow-up automation.** Logging activity (account or league) auto-schedules a dated follow-up task.
- **XR-7 D2C + B2B in one tool.** Shopify D2C revenue (Onesport, Calma) reported alongside the B2B pipeline.
- **XR-8 League-level outreach.** Activity and follow-ups can be logged against a whole league, not just one account.
- **XR-9 CSV export** of any list view (outreach, contacts).
- **XR-10 Click-to-act contact data.** `mailto:`/`tel:` links and LinkedIn deep links throughout.

---

## 5. Non-functional requirements

- **NFR-1 Single tenant, small team.** No per-user record ownership; any authenticated user has full read/write
  (matches current RLS). **Update (16 Jun):** launch this way, then add **Google OAuth** (restricted to
  `@goalkeeper.com`) + **role-based access control** — see [§8.6](#86-auth--access-refines-nfr-1) and research doc §5.
- **NFR-2 Data model is the priority.** The value is in the bespoke schema (clubs, intel, email patterns,
  multi-brand stages), so easy **custom objects/fields and custom pipelines** are the most important platform trait.
- **NFR-3 Look & feel.** Dark "Command Centre" UI, brand-accent colours, GBP throughout, dense tables, Kanban,
  charts, modals. (Current stack: Next.js 16 App Router, React 19, Tailwind v4, Zustand for client state,
  Recharts, dnd-kit, lucide icons.)
- **NFR-4 Backend.** Postgres + Auth intended via **Supabase** (schema + RLS + SSR auth middleware already
  scaffolded in `supabase/` and `src/lib/supabase/*`). Currently pages read **static seed data**; live wiring is TBD.
- **NFR-5 Self-hostable / low cost.** Internal tool for a small company; should run cheaply (Supabase / single VM).
- **NFR-6 Integrations (current + planned).** Shopify (Onesport, Calma) order sync; email (mailto today, possibly
  sending later); LinkedIn (links today); optional "AI Intelligence" surface (a button exists, unimplemented).
- **NFR-7 Import.** Must ingest the existing seed datasets (clubs, contacts, club emails, services, deals,
  Shopify orders) — generator at `scripts/gen-seed.ts` → `0002_seed.sql`.

---

## 6. Current implementation state (gap to "done")

> **Decision (16 Jun 2026):** this prototype is **retired** as a build base — it is a front-end-only presentation
> layer with hardcoded data. Its *screens and requirements* remain the reference for what to build; the *code* is
> superseded by Atomic CRM as the production backend. The state below documents what was inspected to derive this spec.

What exists is a **front-end prototype with a scaffolded but unconnected backend**:

- ✅ All 13 screens built and navigable; Kanban DnD; deal CRUD; outreach/league logging; follow-up automation;
  CSV export; charts — **all against static data + browser `localStorage`** (Zustand `persist`).
- ✅ Supabase schema (7 tables + RLS), seed generator, browser/server clients, and auth middleware are written.
- ⛔ **Not wired:** login is a static form that just navigates to `/crm`; pages still import `src/lib/data/*`
  instead of querying Supabase; outreach/pipeline changes live only in `localStorage`, not Postgres;
  account-detail data is mostly mocked (only 2 accounts have full detail).
- ⛔ No real Shopify sync, no email sending, no AI features, no multi-user accounts/permissions, no reporting
  beyond the hard-coded revenue figures.

This gap is precisely why adopting a proven CRM as the base is attractive (see companion research doc).

---

## 7. Requirements checklist (for evaluating any base CRM)

| # | Requirement | Must / Should |
|---|-------------|---------------|
| R1 | Custom objects/entities (Club, Service, Contact-intel, Email-pattern, Shopify-order) | **Must** |
| R2 | Multiple **independent pipelines** with custom stages per brand | **Must** |
| R3 | Kanban board with drag-and-drop + weighted-pipeline rollups | **Must** |
| R4 | Accounts ↔ multiple deals ↔ multiple contacts, with football roles | **Must** |
| R5 | Activity logging + **dated follow-up task automation** | **Must** |
| R6 | Tasks with due-date grouping (overdue/today/upcoming) | **Must** |
| R7 | Large prospect/"lead" list with filtering, search, batch working, CSV export | **Must** |
| R8 | Self-hostable, low-cost, small-team auth | **Must** |
| R9 | Email-pattern derivation + LinkedIn fields per contact | Should (custom) |
| R10 | Dashboards / revenue reporting across brands | Should |
| R11 | Shopify (e-commerce) revenue + order sync | Should |
| R12 | Modern, customisable UI (dark, brand-accented) close to current stack (TS/React/Postgres) | Should |
| R13 | Workflow/automation engine (notifications, weekly digest) | Nice-to-have |
| R14 | AI/enrichment surface | Nice-to-have |

This checklist is the scoring rubric used in the companion CRM research document.

---

## 8. Post-review updates — 16 Jun 2026 meeting

Decisions and new requirements from the Tech review (Brendan Roslund, Sam Guthrie, Agustín José). These **extend** the
baseline above; the baseline FRs still hold unless noted.

### 8.1 Confirmed direction
- **Replace HubSpot** — the team is moving off HubSpot, which can't meet these requirements.
- **Adopt Atomic CRM** (MIT) as the base; build the remaining ~40% in-house. The **prototype is retired**
  (front-end-only) — Atomic provides the production backend.
- **Single centralized Supabase Postgres database** (one schema) to prevent "information entropy"; Docker for local/dev.
- **Hosting:** Supabase Cloud (backend; one project per env) + **Vercel** (frontend), domain **crm.goalkeeper.com**
  via GoDaddy; **Google OAuth** (`@goalkeeper.com`), RBAC after launch (research doc §4–§5).

### 8.2 Schema congruency with Coda (new)
- **NFR-8 — model the schema on the existing Coda app** (and the XG app) so data stays congruent across systems.
  Coda tracks **clubs, positions, goalkeepers, and competition levels** with **nested hierarchies** and
  **multi-business mapping**. Coordinate org hierarchies with **Diego**.
  *(Dependency: Coda access/structure is needed before the schema is finalised.)*
- Candidate new entities beyond §2: **Goalkeeper / Player**, **Position**, **Competition level / hierarchy** —
  confirm which belong in the CRM vs the xG product database.

### 8.3 Centralized data model & multi-business mapping (new / refines XR-1, R4)
- **R15 — single DB, relational design.** Core tables: `contacts`, `companies`, `services`
  (police / fire / ambulance / prison), `clubs`, plus the football-domain tables.
- **R16 — many-to-many via junction tables.** A contact or company can belong to **multiple brands/clubs/businesses**
  (xG / Calma / Onesport / Goalkeeper.com) without duplication. This is the structural answer to multi-brand.

### 8.4 Integrations to eliminate manual entry (new — promotes XR-7 / NFR-6 to must-have)
- **R17 — Shopify** auto-sync (Onesport + Calma); replaces Sam's manual "upload report to Claude" flow; enables
  flexible **weekly / monthly** reporting timelines.
- **R18 — Gmail** integration (log / sync email into the activity timeline).
- **R19 — WhatsApp Business** integration — **requires a WhatsApp Business API key**.
- *(Workflow mapping/automation assigned to Agustín.)*

### 8.5 Feedback feature (new — Brendan)
- **R20 — in-app feedback feature with a visibility toggle switch** to control who can see submitted feedback.

### 8.6 Auth & access (refines NFR-1)
- **R21 — Google OAuth** sign-in restricted to `@goalkeeper.com`; **role-based access control** (Supabase RLS + JWT
  role claims). Launch simple (all team = full access), add RBAC after. Feasibility confirmed (research doc §5).

### 8.7 Adjacent (non-CRM) decision
- A **centralized team wiki** will be set up to fix documentation gaps — out of scope for the CRM build but part of
  the same data-centralization goal.

### 8.8 Open questions / dependencies
- **Coda structure & hierarchy rules** (with Diego) — blocks final schema design.
- **Scope of player/goalkeeper data** in the CRM vs the xG product DB.
- **Supabase Cloud vs self-hosted** to start — recommended: **Cloud** (research doc §4).
- **Integration credentials:** WhatsApp Business API key/number; Gmail (personal vs Workspace) and Shopify API access.

---

## 9. Requirements feedback — 17 Jun 2026

Feedback aimed directly at this requirements doc. **Supabase is confirmed** as the host; **Vercel** for the frontend.

### 9.1 Brand accent colours (updated)
The §1 accents are updated to the official brand palette:

| Brand | Key | Accent |
|-------|-----|--------|
| Goalkeeper xG | `xg` | **`#FF0092`** (magenta) |
| Onesport | `onesport` | **`#9B1B30`** (maroon) |
| Calma | `calma` | **`#CEAD54`** (gold) |
| Goalkeeper.com | `gkcom` | **`#00F07B`** (green) |

*Heads-up:* `#00F07B` (now the **.com** accent) is the same green the prototype currently uses as its **primary UI
accent** (buttons, "won", positive states). When theming the real build, keep brand colour and primary-action colour
distinct so they don't collide. *(Docs updated; the prototype code is not yet re-themed — say the word and I'll apply
the four hex changes to `BRAND_META` + the CSS variables.)*

### 9.2 Onesport — all-sports tagging + organisation level (new)
Onesport sells kit across **all sports** (not just goalkeeping). The unit is a **Team** (see [§2.12](#212-team-onesport-unit)):
each Team has **one level** and **one or more sports**.
- **R23 — Team level (single-select, exactly one):** **Grassroots · School · University · Club**. The four
  mutually-exclusive kinds of team — *Club* simply means the team belongs to a **sports club**, as opposed to a
  **school**, **university**, or informal **grassroots** team. *(Confirmed 17 Jun: a plain level, not a
  formality/affiliation ranking.)*
- **R22 — Sport(s) (multi-select):** one or more sports per Team, from a comprehensive all-sports taxonomy.
  **Reference only — the concrete list (the BBC Sport "all sports" set) is sourced during development;** the exact
  enum isn't fixed now.

### 9.3 xG — deal modules (new)
- **R24 — xG module selection (multi-select), logged during the sales cycle:**
  **Ongoing Support · Transfer Market Support · Opposition Analysis · API**. A deal can have one or more; the
  selection is recorded and updated as the deal progresses (drives scoping, pricing, and reporting). Added to the
  Deal entity (§2.2).

### 9.4 Onesport D2C — confirmed already covered
Yes. Onesport is tracked as **both B2B and D2C**: the §1 table lists "B2B orders + D2C Shopify", and the Shopify
module (FR-SHOP, §3.8) covers **Onesport + Calma** D2C orders/revenue. No change needed.

### 9.5 Email integration → create / update deals (extends R18)
- **R25 — the Gmail/email integration must not only log email, but parse it to *create new deals* and *update
  existing deals*** (stage, contact, value, notes) directly from inbound/outbound mail, cutting manual pipeline
  upkeep. This strengthens **R18** (§8.4); likely AI-assisted parsing with a human confirm step before writing.

---

## 10. Release plan & backlog

Build sequencing is tracked in **[CRM-BACKLOG.md](./CRM-BACKLOG.md)** (organised as milestones M0–M7). Recommended
cut (17 Jun, from Sam's handover priorities):

| Release | Milestones | Scope |
|---|---|---|
| **v1** | M0 Foundation · M1 Data & migration · M2 Core surfaces · M3 Outreach loop | Auth + schema + crown-jewel data + Pipeline/Accounts/Contacts + outreach→task loop, live on `crm.goalkeeper.com` |
| **v1.1** | M4 | Shopify live sync, Dashboard, Revenue, Club/Services surfaces, Onesport Team tagging UI, **feedback feature**, Settings |
| **v1.2** | M5 · M6 | Gmail email→deal, WhatsApp Business, notification digests; **RBAC** |
| **Later** | M7 | AI surface, email templates, pricing catalog, advanced reporting, mobile |

**Critical path:** the Coda schema walkthrough (with Diego) gates M1 — see [§8.8](#88-open-questions--dependencies).
The full **v1 acceptance criteria** are defined at the end of Milestone M3 in the backlog.
