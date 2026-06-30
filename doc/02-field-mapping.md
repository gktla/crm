# 02 · Field-by-field map

Mapping each source field to its canonical destination, in the org-centric model (`companies` = universal org). See doc 03 (schema), doc 05 (decisions), doc 07 (GPS).

- **Field** = `destination.field` (+ gloss). **Origin** = `A` Atomic · `Co` Coda CSV · `V` vibecoded · `Br` Brendan org model · `—` new. **Action** = Reuse · Rename · Extend · Create · Normalize · Convert-FK · Convert-junction · Convert-derived · Discard.
- IDs: PK = `bigint` identity. External refs (`coda_row_id`, `legacy_ref`, `gps_org_id`) are columns, never PKs. No `entra_oid` (auth = Google OAuth on Supabase, decision A).

---

## 1 · `companies` — the universal org (EXTEND)

Every football org (club, league, federation, national team, broadcaster, agency, media, service) lives here, so any of them can be a deal target.

| Field | Origin | Action | Notes |
| --- | --- | --- | --- |
| `id` | A·Co·V | Reuse | ext ids → `legacy_ref` |
| `name` | A·Co·V | Reuse | Coda names not unique |
| `kind` | A·V·Br | Create | **primary/display type**, mirror of `company_org_types` |
| `slug` | Br | Create | standardized handle (GPS-aligned vocabulary) |
| `website` | A | Reuse | |
| `country` | A·Co·V | Reuse | |
| `city` | A·V | Reuse | |
| `logo` | A | Reuse | club crest → `clubs.crest` |
| `linkedin_url` | A | Reuse | |
| `ltv` | V | Create | curated or Σ-won view |
| `updated_at` | — | Extend | add (Atomic lacks it) |
| `company_brands` (junction) | V | Convert-junction | brands array → bridge |

---

## 2 · Org types & relationships (NEW — Brendan org model)

| Field | Origin | Action | Notes |
| --- | --- | --- | --- |
| `org_types` (lookup) | Br | Create | club/league/federation/national_team/broadcaster/rights_holder/agency/… — extensible |
| `company_org_types` (junction) | Br | Convert-junction | N–N: an org can have **multiple types** (a league that's also a federation) |
| `org_relationships` | Br | Create | self-ref org↔org: `parent_of` (nested leagues), `governs` (FA→league/nat-team), `broadcasts` (+`region` geo-split), `affiliated_with`, `owns` |

---

## 3 · Clubs, leagues, nations

| Field | Origin | Action | Notes |
| --- | --- | --- | --- |
| `clubs.company_id` (PK/FK) | — | Create | 1:1 with companies |
| `clubs.league_company_id` | Co·Br | Convert-FK | the competition is a **league-org** (`companies`), not a lookup |
| `clubs.nation_id` | Co·V | Convert-FK | codes dirty (Aberdeen=ENG) → clean; `nations` lookup |
| `clubs.hit_list` | Co | Create | named lists via `target_lists` |
| `clubs.xg_status` | Co | Create | all `Pending` → text, no CHECK; normalize on import |
| `clubs.crest` | V | Create | |
| `clubs.contract_end` | V | Create | date; old free text → clean |
| `clubs.email_domain` / `email_pattern` | V | Create | clean corrupt domains |
| `clubs.notes` | Co·V | Create | free intel |
| `clubs.coda_row_id` | Co | Create | source of truth for the club's Coda id |
| `clubs.gps_org_id` | — | Create | **nullable & optional** GPS link; fill on deal-won if useful (doc 05 §0) |
| `clubs.keeper_count` | V | Create | |
| `competitions.company_id` (PK/FK) | Br | Create | 1:1 ext for league-orgs (level/format/season) |
| (league name) | Co | Convert-FK | `League` string → a league-org (`companies` type=league) |

---

## 4 · `contacts` (EXTEND) + `company_contacts` (NEW junction)

| Field | Origin | Action | Notes |
| --- | --- | --- | --- |
| `contacts.first/last_name` | A·Co·V | Reuse | split Coda name |
| `contacts.email_jsonb` / `phone_jsonb` | A·V | Reuse | |
| `contacts.linkedin_url` | A·V | Reuse | person's URL |
| `contacts.title` | A·Co | Reuse | 50 blanks in Coda |
| `contacts.company_id` | A·Co·V | Reuse (mirror) | not source of truth — mirror of primary link |
| `contacts.tags` | A | Reuse | native array |
| `cc.role` | Co·V·Br | Convert-junction | SD/HoR/gk_coach/head_coach/scout/manager/ceo/sports_sec/**agent**/other |
| `cc.is_primary` | — | Create | one active primary per contact |
| `cc.company_id, is_current, start/end` | — | Create | multi-org / history (coach at club **and** national team) |
| `cc.relationship_status` | Co | Create | Very/Moderate/Limited Contactable; text, normalize case |
| `cc.preferred_contact` | Co | Create | mostly null |
| `cc.instagram_status` / `linkedin_status` | Co·— | Create | text, normalize case (Private/PRIVATE) |
| `cc.verified_at` | V | Normalize | extract date from notes |
| `contact_social_profiles` | Co | Convert-junction | Instagram URL; 81 rows, one each |

`cc` = `company_contacts`.

---

## 5 · `deals` (EXTEND) — target any org

| Field | Origin | Action | Notes |
| --- | --- | --- | --- |
| `name` | A·V | Reuse | |
| `company_id` | A·V·Br | Convert-FK | any org (club/league/federation/broadcaster); old pointed at clubs → fix |
| `brand_id` | V | Convert-FK | → `brands`; composite FK with stage |
| `stage_id` (+ `stage` slug) | A·V | Convert-FK | composite `(brand_id, stage_id)`; slug synced by trigger |
| `probability` | V | Create | optional override; default from stage |
| `amount` | A·V | Reuse | |
| `expected_closing_date` | A·V | Reuse | old text → clean |
| `sales_id` | A·V | Convert-FK | initials → sales |
| `contact_ids` | A | Reuse | native array |
| `deal_modules` (junction) | V | Convert-junction | Ongoing/Transfer/Opposition/API; xG only |
| `index`, `archived_at`, `category` | A | Reuse | |

---

## 6 · `brands`, `pipeline_stages` (NEW)

| Field | Origin | Action | Notes |
| --- | --- | --- | --- |
| `brands` (id, key, name, accent_color) | A·V | Create | xg/onesport/calma/gkcom |
| `pipeline_stages` (rows) | A·V | Create | per brand, different counts |
| `pipeline_stages.default_probability` | V | Create | override on deal |
| `pipeline_stages.is_won/is_lost` | A·V | Create | replaces magic numbers |

---

## 7 · `players` (NEW)

| Field | Origin | Action | Notes |
| --- | --- | --- | --- |
| `full_name` | Co | Create | |
| `date_of_birth` / `age_imported` | Co | Normalize | no DOB in source |
| (league) | Co | Convert-derived | from the current club |
| `status` | Co | Convert-derived | from the 8 step columns |
| 8 funnel steps (`step_follow_back`…`step_contract`) | Co | Create | **8 boolean columns** (decision D) |
| `coda_row_id` | Co | Create | |

---

## 8 · `player_org_assignments` (NEW junction) — clubs **and** national teams

| Field | Origin | Action | Notes |
| --- | --- | --- | --- |
| `org_id` | Co·Br | Convert-FK | → `companies` (club or national-team org) |
| `relationship_type` | Co·Br | Convert-junction | owned/current/loaned_in/loaned_out/target/**national_team** — non-exclusive rows |
| `is_current, start/end` | Co | Create | `current_squad` view derives the live squad (decision C) |

---

## 9 · `player_citizenships` (NEW junction)

| Field | Origin | Action | Notes |
| --- | --- | --- | --- |
| (citizenship) | Br | Convert-junction | N–N `player_id`↔`nation_id` — multiple nationality |

*(Not in the Coda CSV; populated when citizenship data exists.)*

---

## 10 · `player_representations` (NEW) — agent (person) + agency (org)

| Field | Origin | Action | Notes |
| --- | --- | --- | --- |
| `agency_company_id` | Co·Br | Convert-FK | agency = **org** `companies(type=agency)` (was free text `Representation Name`) |
| `agent_contact_id` | Br | Convert-FK | agent = **person** `contacts` (via `company_contacts.role='agent'`) |
| `rep_code` | Co | Create | DR/RL/ZY; `REP (Temp Column)` discardable |
| `agent_expiry` | Co | Normalize | dirty formats → date; **month-only → last day of month** (decision 10) |
| `is_current, start/end` | Co | Create | |

---

## 11 · Services (Onesport) → `companies.kind='service'`

| Field | Origin | Action | Notes |
| --- | --- | --- | --- |
| service record | V | Normalize | `companies.id` + `legacy_ref` |
| type | V | Normalize | `companies.kind` + `teams.level` (Police/Fire/Prison/Ambulance) |
| sports secretary | V | Convert-junction | `company_contacts.role='sports_secretary'` |
| sports | V | Convert-junction | `team_sports` |
| status | V | Normalize | via deals/pipeline |

---

## 12 · `activities` (NEW) + `tasks` (EXTEND)

| Field | Origin | Action | Notes |
| --- | --- | --- | --- |
| dated outreach | V | Create | `activities` (channel, status, occurred_at) |
| targets | — | Create | company/contact/deal/player; **no `league_id`** (a league is a `company`); ≥1 |
| `tasks.contact_id` | A | Extend | **nullable** + deal/company/activity ids |
| auto follow-up | V | Create | `activities`→`tasks.activity_id` trigger (M3-4) |
| free note | A | Reuse | `contact_notes`/`deal_notes` |

---

## 13 · Target lists (NEW)

| Field | Origin | Action | Notes |
| --- | --- | --- | --- |
| `target_lists` | Co | Create | Hit List bool → `clubs.hit_list` |
| `org_target_lists` | — | Convert-junction | N–N; FK → `companies` (any org can be on a list) |
| `player_target_lists` | Co | Convert-junction | N–N; `Target Players` empty in export |

---

## 14 · Social media (decision E)

`contacts.linkedin_url` on the person; Instagram/X/TikTok → `contact_social_profiles(platform, url)` unique `(contact_id, platform, url)`; statuses → `company_contacts`. `player_social_profiles` same shape.

---

## 15 · `teams`, `team_sports`, `sports` (Onesport, R22/R23)

| Field | Origin | Action | Notes |
| --- | --- | --- | --- |
| `teams.id, company_id` | req | Create | nested under org |
| `teams.level` | req | Create | grassroots/school/university/club |
| `team_sports` | req | Convert-junction | multi-select |
| `sports` | req | Create | taxonomy seeded later (M1-4) |

---

## 16 · Reused as-is

`sales` (Google OAuth on Supabase — **no `entra_oid`**), `tags`, `contact_notes`, `deal_notes`, `configuration` (GBP + slugs), `favicons_excluded_domains`. Views `*_summary`/`activity_log`: update; add `current_squad`.

---

## 17 · External-ID & cross-system strategy

| Column | On | Holds |
| --- | --- | --- |
| `coda_row_id` | clubs, players | the Coda id (source of truth) |
| `legacy_ref` | companies, deals | vibecoded `a##`/`svc##`/`d##` |
| `gps_org_id` | clubs | **nullable, optional** GPS link (doc 05 §0; doc 07) |

PK always `bigint` identity. No shared tables with GPS; integration = standardized vocabulary + the optional `gps_org_id`.
