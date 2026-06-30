# 05 · Closed & open decisions

Three sections: **(0) Guiding principles**, **(1) Closed decisions** (the index), and **(2) Resolved decisions — rationale** (the *why* behind the ones that were open). All decisions are now closed. See doc 07 for GPS.

## 0. Guiding principles (the "why" behind the decisions)

These are the criteria applied throughout. When a specific decision below seems arbitrary, it usually follows from one of these.

- **CRM and GPS are separate systems.** They have different purposes, different functionality, and do not even share a host. Forcing them to be one-to-one or identical would add unnecessary complexity to **both**. So they stay independent; the only point of contact is **standardizing the shared vocabulary** (org-type names, the `organisation` term, conventions), plus one **soft, optional link** (`clubs.gps_org_id`, nullable). The CRM models the football world the way *selling* needs it; GPS models it the way its product needs it.
- **Low-cost, possibly-useful columns are kept nullable rather than omitted.** E.g. `gps_org_id`: costs nothing to carry, lets the team start without GPS and add the link later if it helps — and if it never helps, it simply stays null. (Application of the principle above.)
- **Additive, never destructive.** New migrations on top of Atomic's history; existing structures aren't rewritten.
- **Don't invent enums.** Status/category values stay free text until the real values are inventoried; closed CHECKs only over confirmed, stable sets.
- **No premature automation.** v1 has no automatic data migration; choose the import-simplest option when it doesn't cost correctness (e.g. the player funnel as 8 columns rather than a dated steps table).
- **One source of truth per fact.** Mirrors (e.g. `contacts.company_id`, `companies.kind`) are derived/synced, never authoritative.

## 1. Closed decisions

| Ref | Decision | Resolution | Reflected in |
| --- | --- | --- | --- |
| DF | Follow-up tasks | **Extend `tasks`** (contact_id nullable + deal/company/league/activity_id + CHECK). No `follow_ups` table. | 03, 02 §9, 06 |
| DF | Stages per brand | **`pipeline_stages` table**; `deals.stage_id` = truth; slug for compat only. | 03, 04 |
| 2 | brand↔stage integrity | **Composite FK** deals(brand_id, stage_id) → pipeline_stages(brand_id, id) + UNIQUE(brand_id, id). slug synced by trigger. | 03, 04, 06 |
| 3 | Backfill before NOT NULL | Phased: nullable → fallback mapping → backfill → fail-if-ambiguous → FKs → composite → NOT NULL. | 06 §2.1 |
| 4 | Current employer | **`company_contacts` is the source of truth**; `contacts.company_id` mirrors the primary+current link (trigger); one primary per contact. | 03, 02 §3 |
| 5 | company_contacts unique/history | No global unique; partial unique `where is_current` + date checks (allows re-joining). | 03, 02, 04 |
| 6 | player_org_assignments + org ref | No global unique; partial unique `where is_current`; `org_id`/`org_target_lists.company_id` → **companies** (club or national-team org). | 03, 02, 04 |
| 8 | tasks↔activities | `tasks.activity_id` nullable + partial unique (one follow-up/activity); targets CHECK includes activity_id. | 03, 04 |
| 9 | activities multi-target | CHECK `num_nonnulls(...) >= 1` = at least one, not exactly one. | 03, 04 |
| 10 | RLS per migration | Each new table enables RLS + policies + grants in its own migration; single-tenant at launch, RBAC at M6. | 03, 06 §0.1 |
| 11 | Multi-deal per company/brand | No unique on (company_id, brand_id); duplicates controlled in UI/reports. | 03, 02 §4 |
| 13 | companies.kind | `kind` is a **sales-target classifier**. CHECK with documented values or `company_kinds` lookup. | 03 |
| 14 | Club Coda Row ID | Single source of truth = **clubs.coda_row_id**. `companies.legacy_ref` = vibecoded `a##`; `companies.coda_row_id` = generic, usually-null slot. There is no shared/general org table (link, don't merge). | 03, 02, 04 |
| 15 | notes / activities / tasks | notes = free text; activities = structured dated interaction; tasks = future action. No auto-convert. | 03 |
| E | Social media | Normalized: `contact_social_profiles(platform, url)` unique (contact_id, platform, url); LinkedIn in `contacts.linkedin_url`; statuses in `company_contacts`. | 02/03, Phase 2 |
| G | nations | Lookup: `nations(code, name)` + FK `clubs.nation_id`. Real codes dirty → clean on import. | 03, Phase 1 |
| 3b | Brand/stage backfill mapping | Default brand = `xg` for legacy Atomic deals; legacy→xG stage map; **explicit fail** on lost/delayed/unknown. Pending the read-only audit of gk-crm-dev (§I). | 06 §2.1, Phase 4b |
| B | GPS club reconciliation | A **link field** `clubs.gps_org_id` (nullable, set on deal-won). Not a shared table, not a real FK (separate DB). Closed by Diego's recommendation. | 03, 04, 07 §5 |
| L | Football org world-model = CRM scope | **Agreed with Diego.** The CRM models the football org world-model in its own useful shape — `companies` is the universal org, with `company_org_types` (multi-type), `org_relationships` (nesting/governance/broadcast rights), leagues/federations/national teams/broadcasters as orgs (deal-able), agents/agencies as first-class, and player national-team/citizenship. **GPS integration = standardization** (shared naming/vocabulary + the `gps_org_id` link), **not** a structural merge. | 03, 04, 07 |
| A | CRM auth | **Google OAuth on Supabase.** No Entra, no `entra_oid`. CRM and GPS are separate databases. | 03, 06 |
| K | GPS provisioning | **Manual** — on deal-won someone creates the GPS org and fills `gps_org_id` by hand (no automation in v1). | 06, 07 |
| Gx | `gps_org_id` link | Kept **nullable & optional** (principle §0): low-cost soft link; fill it if useful for reconciliation, leave null otherwise. | 03, 04, 07 |
| B' | RBAC at M6 | **Own simple model**, fit to the CRM's job (registering clients) — not the GPS 4-layer (separate systems). | 06 |
| H | Player load scope | Load **exactly what the Coda CSVs carry** (`DB_PlayerCRM` + club-list assignments). Tables keep full shape; the load is bounded. | 02, 06 |
| C | Player `current` | **Stored** as an assignment row (faithful to Coda) + a `current_squad` view. | 03, 04 |
| D | Player funnel | **8 boolean columns** + derived `status` (CSV has no per-step dates; manual one-off load). | 03, 02 §6 |
| I | Source precedence | intel/email → vibecoded · players/staff/relations → Coda · pipeline → vibecoded. | 06 §5 |
| J | `*_status` values | **Free text in v1** + normalize on import (case/trim). No CHECK/lookup until values inventoried + Settings exist. | 03, 06 |
| 10 | `agent_expiry` day | Month-only Coda values → **last day of the month**. | 02, 06 |
| 11 | `sports` taxonomy | Seed later (M1-4), not now. | 03, 06 |

**Partially resolved (#12 — statuses):** `xg_status`/`relationship_status`/`instagram_status`/`linkedin_status` stay **text without CHECK** (don't invent enums). How to finalize → §J.

---

## 2. Resolved decisions — rationale

All previously-open decisions are now closed (indexed in §1). The reasoning is kept here so the *why* survives, not just the *what*.

- **A · auth:** Google OAuth on Supabase, **not** Entra. Chosen because CRM and GPS stay separate systems (principle §0) — sharing identity would couple them for little gain. `sales.entra_oid` is dropped.
- **K · GPS provisioning:** manual on deal-won. No premature automation in v1; revisit if the hand-off becomes frequent.
- **`gps_org_id`:** kept **nullable & optional**. It's a low-cost soft link — fill it if it helps reconcile against GPS, leave it null if it doesn't. Follows directly from §0: the two systems have different purposes and hosts, so forcing a one-to-one tie would add complexity to both; we standardize language instead.
- **B' · RBAC (M6):** our own simple model fit to the CRM's job (registering clients), not GPS's 4-layer — importing GPS's authz complexity would buy nothing for an internal single-tenant tool.
- **H · player scope:** load exactly the Coda CSVs. The tables keep their full shape; only the *load* is bounded. (No automatic migration in v1.)
- **C · player `current`:** store the assignment row (faithful to Coda) **and** expose a `current_squad` view — keeps both the raw data and a coherent read.
- **D · player funnel:** 8 boolean columns + derived `status`. The CSV has no per-step dates and the load is a manual one-off, so the simple, faithful option wins. If dated per-step audit is ever needed, migrate to a `player_outreach_steps` table then.
- **I · source precedence:** intel/email → vibecoded · players/staff/relations → Coda · pipeline → vibecoded.
- **J · `*_status` fields:** free text in v1 + a normalization pass on import (case, trims). No enum or lookup until the real values are inventoried and Settings exists (don't-invent-enums principle).
- **10 · `agent_expiry`:** month-only values (e.g. "Dec 2024") → last day of the month.
- **11 · `sports` taxonomy:** seeded later (M1-4).

### L. Football org world-model: CRM scope vs GPS — ✅ RESOLVED

Settled with Diego (see closed decision **L**). The CRM **does** model the football org world-model, in a shape useful for selling; GPS integration is **standardization + link**, not merge. Each relation Brendan raised is now in the schema (03/04):

- **Multi-type orgs** → `org_types` + `company_org_types` (N–N); `companies.kind` mirrors the primary.
- **Nested leagues / governance / broadcast rights** → `org_relationships` (typed, with `region` for the geo-split).
- **Leagues / federations / national teams / broadcasters as deal targets** → they are `companies`; `deals.company_id` targets any org.
- **Player ↔ national team** → `player_org_assignments.org_id` references a club **or** national-team org.
- **Player multiple citizenship** → `player_citizenships` (N–N).
- **Agents / agencies** → agency = `companies(type=agency)`, agent = `contacts` (via `company_contacts.role='agent'`), both linked from `player_representations`.

Remaining detail for Diego (standardization, not scope): agree the shared **org-type vocabulary** and the `org_relationships.relationship_type` set so the CRM and GPS use the same names.

> **Multi-tenancy (doc 07, question 1):** the CRM is **internal/single-tenant**; no `user_organisations` equivalent is needed unless external partners ever get scoped logins. Revisit only if that changes.
