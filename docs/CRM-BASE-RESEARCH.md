# Open-Source CRM Base — Research & Recommendation

> **Goal:** Pick the open-source CRM that best fits the [reverse-engineered requirements](./CRM-REQUIREMENTS.md)
> as a **starting point** for the Goalkeeper Group CRM — instead of building a fully bespoke ("vibe-coded") system
> from zero, which is slower and riskier.
> **Date:** June 2026. **Method:** requirements rubric (R1–R14) + current web research on the leading projects.

---

## TL;DR — Decision (ratified 16 Jun 2026)

> ### ✅ **Atomic CRM** (Marmelab) is the **approved** base. Host on **Supabase**, sign in with **Google OAuth**. The existing prototype is **retired** (front-end-only, hardcoded data); Atomic becomes the production backend, with the schema modelled on the company's **Coda** app for cross-system congruency.

> The comparison below is retained as the **decision record** — *why* Atomic was chosen over Twenty/EspoCRM. Hosting and sign-in details are in [§4 Hosting (Supabase + Vercel)](#4-hosting--infrastructure--supabase-backend--vercel-frontend) and [§5 Authentication (Google OAuth)](#5-authentication--access--google-oauth--rbac). The milestone-by-milestone build plan lives in **[CRM-BACKLOG.md](./CRM-BACKLOG.md)**.

**Why Atomic CRM wins for *this* project:** it is the **same stack the prototype is already on** — React + TypeScript +
Tailwind + **Supabase (Postgres + Auth)** — under the most permissive licence (**MIT**). The Supabase schema, auth
middleware, and seed work already in this repo carry straight over. Atomic is a lightweight (~15k LOC) **starter you
own and extend**, shipping the generic 60% of a CRM (contacts, companies, deals-Kanban, tasks, notes, activity log,
CSV import/export, SSO) so the team can spend its effort on the **bespoke 40%** that is the actual product: the
multi-brand pipelines and the football intelligence layer.

You can test it online at <https://marmelab.com/atomic-crm-demo/#/>

**The honest fork in the road:**

| If the team wants… | Choose | Because |
|---|---|---|
| To **own and code** a bespoke domain on a familiar stack, reuse the Supabase work, keep an MIT licence | **Atomic CRM** ✅ | Same stack; smallest leap from today's prototype; most freedom |
| To **configure (no-code) a polished platform** with custom objects/fields/automation via UI, and accept AGPL + a new backend to host | **Twenty** | Best no-code customization & UX, but single-pipeline today + AGPL + heavier to host |
| Maximum **no-code admin power** and a mature feature set, and PHP is acceptable | **EspoCRM** | Strongest no-code data-model/entity manager, but PHP (stack mismatch) + AGPL |

Twenty is an outstanding product (the 2026 benchmarks' #1 overall) and a very close call. It loses **for us
specifically** on three points that matter given our requirements and our existing code: (1) it has **one fixed
opportunity pipeline** today — multiple independent per-brand pipelines (our #1 must-have, R2) need workarounds;
(2) **AGPL-3.0** is "contaminating"; (3) adopting it means **abandoning the scaffolded Supabase backend** for a
heavier NestJS + Redis + GraphQL system.

---

## 1. Evaluation method

Candidates were scored against the requirements rubric from the requirements doc (R1–R14). The weight is on the
**must-haves** that make this CRM unusual:

- **R1** custom objects/entities (Club, Service, Contact-intel, Email-pattern, Shopify-order)
- **R2** multiple **independent pipelines** with custom stages per brand
- **R3** Kanban DnD + weighted-pipeline rollups
- **R5/R6** activity logging + **dated follow-up automation** + task grouping
- **R7** large prospect list: filter/search/batch/CSV export
- **R8** self-hostable, low-cost, small-team auth
- **R9–R14** email-pattern/LinkedIn, dashboards, Shopify, modern stack, automation, AI

Plus a project-specific tie-breaker: **proximity to the current prototype** (React/TS/Tailwind/Supabase) — adopting a
base on the same stack means the existing schema, auth middleware, components, and seed data are reusable rather than thrown away.

---

## 2. The field (2026)

Independent 2026 benchmarks converge on the same shortlist for "small team that wants to customise":
**Twenty, Atomic CRM, and Krayin**, with **EspoCRM** as the no-code-heavy option and the ERP suites (Odoo, ERPNext)
judged "too large" for CRM-only use.

| CRM | Licence | Stack | Stars (approx.) | Custom objects | Multiple pipelines | Stack fit to prototype | Verdict for us |
|-----|---------|-------|------|----------------|--------------------|------------------------|----------------|
| **Atomic CRM** (Marmelab) | **MIT** | **React + TS + Tailwind + shadcn + Supabase/Postgres** | ~1.1k | Via code (own the schema) | Via code | **Exact match** ✅ | **Best base** |
| **Twenty** | AGPL-3.0 | TypeScript, NestJS, React, Postgres, Redis, GraphQL | ~30k+ | **Yes (no-code, UI)** | **Single pipeline today**; workaround via Select-field Kanban / custom objects | Partial (TS/React, but new backend) | Strong runner-up |
| **EspoCRM** | AGPL-3.0 | PHP8, custom framework, MySQL/Postgres | ~2k+ | **Yes (no-code Entity Manager)** | Workarounds (multiple entities/select); not first-class | Poor (PHP) | No-code alternative |
| **Krayin** | MIT | PHP8, Laravel, Vue | ~1k+ | Via code | Limited | Poor (PHP/Vue) | Skip |
| **SuiteCRM** | AGPL-3.0 | PHP8 (SugarCRM fork) | ~4k+ | Yes (Studio) | Yes | Poor (legacy PHP) | Skip (dated codebase) |
| **Odoo CRM** | LGPLv3 | Python, OWL JS, Postgres | large | Yes (Studio) | Yes | Poor (Python ERP) | Overkill |
| **ERPNext / Frappe CRM** | GPL-3.0 / MIT | Python, Frappe, MariaDB | large | Yes | Yes | Poor (Python) | Overkill for CRM-only |

*Stars are indicative, not decisive. Twenty has by far the largest community; Atomic the best stack fit.*

---

## 3. Shortlist deep-dive

### 3.1 Atomic CRM — **recommended base** (score ~8/10 for our needs)

**What it is:** an open-source CRM **template** by Marmelab (the team behind react-admin), built on React, shadcn/ui,
Tailwind, react-admin, TanStack Query, and **Supabase + PostgreSQL**, with Vite, Playwright e2e and Jest tests.
MIT-licensed. Actively maintained (v1.5.0, March 2026; ~1,500 commits).

**Out-of-the-box features that map to our FRs:**

| Atomic feature | Covers |
|---|---|
| Contacts + Organizations | Accounts, Contacts (FR-ACC, FR-CON) |
| Deals on a **Kanban pipeline** | Pipeline board (FR-PIPE-1/3) |
| Tasks & reminders | Tasks (FR-TASK-1/2) |
| Notes + **activity history** (incl. "CC the CRM to log email") | Outreach log, notes (FR-OUT, account notes) |
| CSV **import/export** | CSV export (XR-9, FR-OUT-5, FR-CON-4) |
| **SSO** (Google, Azure, Keycloak, Auth0) free | Auth (FR-AUTH) |
| Tags, theming, component override | Branding/UX (NFR-3) |

**Why it's the best fit:**
- **Stack identity with the prototype.** Same frontend *and* same backend (Supabase/Postgres/Auth). The repo's
  existing `supabase/migrations/*`, `src/lib/supabase/*` clients, auth middleware, seed generator, design tokens, and
  even some React components are **reusable** rather than discarded.
- **MIT licence** — no AGPL "contamination"; full freedom to keep changes private or commercialise later.
- **Lightweight & ownable.** ~15k LOC you control. The architecture is built for replacing/extending any component,
  which is exactly the posture we need to bolt on a bespoke football schema.
- **The bespoke core is meant to be coded anyway.** Multi-brand pipelines, the ~170-club scouting directory, contact
  intel, email-pattern derivation, the Services vertical — none of these come free from *any* CRM. Atomic lets us add
  them as Supabase tables + react-admin resources with the least friction.

**Stated weaknesses (per 2026 benchmark):** "limited built-in features" and a "small community." For us these are
acceptable — we are deliberately building the missing features, and the small surface area is easier to own.

### 3.2 Twenty — strong runner-up (best no-code platform; 2026 benchmark #1 overall)

**Strengths:** the most polished UI of the field; **no-code custom objects and custom fields via the admin UI**
(text, number, currency, %, dates, select, and relations many-to-one/one-to-many/many-to-many); Kanban-by-stage
views editable in-app; workflow automation with webhooks; role-based permissions; email/calendar sync; large, fast-moving community. Self-host via Docker (Postgres + Redis + SMTP), ~1–2 h for a developer.

**Why not #1 for us:**
- **R2 (multiple independent pipelines) is the deciding gap.** Twenty today has a *single* Opportunities object with
  one fixed stage set. Multiple per-brand pipelines require a workaround — several `Select` fields each with its own
  Kanban view, or a custom object per pipeline. Native "record types / multiple pipelines" is an open, requested
  feature, not shipped. Our product needs 4 pipelines with *different* stage counts and names; the workaround is
  awkward and central to the app.
- **AGPL-3.0** — modifications served in a SaaS context must be open-sourced. Fine for a purely internal tool, but a
  strategic constraint and strictly more restrictive than Atomic's MIT.
- **Backend divergence.** Adopting Twenty means running its NestJS + custom metadata engine + Redis + GraphQL stack
  and **throwing away the Supabase work** already done here. More to host (≥2 vCPU/4 GB) and a different ops model.
- Reporting is "basic," no time-in-stage/forecasting, no native mobile app yet.

**Pick Twenty instead if:** the team would rather **configure** a maintained platform than maintain bespoke code, is
comfortable with AGPL, and accepts modelling brands as views/Select fields rather than true separate pipelines.

### 3.3 EspoCRM — best no-code data model, wrong stack

**Strengths:** the most powerful **no-code Entity Manager** — create custom entities, fields, relationships, layouts,
and Dynamic Logic with zero code; mature, complete feature set; runs lean. This would model Clubs/Services/Intel
entities purely through admin config.

**Why not:** PHP8 + custom framework + MySQL/Postgres is a **full stack mismatch** with the prototype (we'd abandon
React/Supabase and the team's existing skills). AGPL-3.0. Documentation rated "poor." Multiple pipelines are
workaround-based, not first-class. Best reserved as the alternative if the team explicitly prefers an
admin-configured CRM over a coded one and doesn't care about the JS stack.

### 3.4 Briefly considered, rejected

- **SuiteCRM / Odoo / ERPNext / Axelor:** feature-rich but heavy ERPs or legacy codebases; 2026 benchmarks score them
  4–5/10 for a customisation-focused small team. Odoo's e-commerce module is tempting for the Shopify/Onesport side,
  but adopting an ERP to get a CRM is the wrong trade for a small team. **Overkill.**
- **Krayin:** MIT and developer-friendly, but Laravel/Vue (stack mismatch) with "clunky UX." No advantage over Atomic for us.
- **Monica:** personal-relationship CRM, not a B2B sales tool. Out of scope.

---

## 4. Hosting & infrastructure — Supabase backend + Vercel frontend

**Confirmed: host on Supabase.** Atomic CRM *is* a Supabase application — its backend is Postgres + the
auto-generated PostgREST API + GoTrue auth + Storage + Edge Functions, accessed through the Supabase client SDK. The
only sub-decision is **Supabase Cloud vs self-hosted Supabase**:

| Option | What it is | When to pick |
|---|---|---|
| **Supabase Cloud** ✅ *(recommended to start)* | Managed Supabase (Pro ≈ $25/mo/project): hosted Postgres, Auth, Storage, Edge Functions, Realtime, **automatic connection pooling, backups, and prod/staging branching** | Default — simplest, fastest path (matches the meeting's "simplest & quickest" rationale); near-zero ops |
| **Self-hosted Supabase** (Docker on a VPS) | Run the full Supabase stack (GoTrue, PostgREST, Storage, Kong, Studio) yourself | Only if data-residency/compliance demands it, or to escape usage-based pricing at scale |

**Recommendation: start on Supabase Cloud.** Self-hosting puts connection-pool tuning, backups, and security updates
on us, and Supabase self-hosted has **no multi-project/branching** — staging + prod = two full stacks. That's ops we
don't want while building the bespoke 40%. The schema is portable Postgres, so we can move to self-hosting later if needed.

**Frontend host: Vercel** *(approved)*. Atomic's frontend is a static Vite/React SPA — deploy to Vercel with
git-based per-branch environments (`main`→prod, `staging`→staging, PRs→preview) and automatic SSL, with the domain
**`crm.goalkeeper.com`** (+ `staging.crm.goalkeeper.com`) via a GoDaddy CNAME. Pair it with **one Supabase project per
environment** (dev / staging / prod). Integration workers (Gmail / WhatsApp / Shopify sync, scheduled reporting) run
as Supabase Edge Functions/cron. Full infra tasks: [backlog Milestone M0](./CRM-BACKLOG.md#m0--foundation--infrastructure).

---

## 5. Authentication & access — Google OAuth + RBAC

**Feasibility: high — effectively built-in.** Both layers we need are first-class:

- **Google sign-in:** Atomic CRM already ships Google SSO (with Azure/Keycloak/Auth0), and Supabase Auth (GoTrue)
  supports the Google OAuth provider natively — configure a Google client ID/secret in the Supabase dashboard. No custom auth code.
- **Restrict to `@goalkeeper.com`:** enforce via Google Workspace `hd` (hosted-domain) hint + server-side domain
  verification, and/or a Supabase **Auth Hook / DB trigger** that rejects non-`goalkeeper.com` sign-ups.
- **Role-based access control:** Supabase's documented pattern — a `roles`/`permissions` table + a **Custom Access
  Token Auth Hook** that injects the role into the JWT + **RLS policies** reading that claim. Replaces the prototype's
  blanket `authenticated using (true)` policy with real per-role rules.

**Effort:** low for Google sign-in + domain restriction (config + a small hook); moderate for full RBAC (design roles
+ rewrite RLS) — and RBAC can land **after** an initial "any authenticated team member = full access" launch, exactly
as the meeting sequenced it.

---

## 6. Build path — from approved base to product

> **The prototype is retired** — it was a front-end-only presentation layer with hardcoded data. Atomic CRM is the
> production backend foundation. The data schema is modelled on the company's **Coda** app (clubs, positions,
> goalkeepers, competition levels, nested hierarchies) and the XG app for cross-system congruency — coordinate org
> hierarchies with **Diego** *(this input is a prerequisite for finalising the schema)*.
>
> The full milestone-by-milestone plan and v1 acceptance criteria live in **[CRM-BACKLOG.md](./CRM-BACKLOG.md)**.

1. **Stand up Atomic CRM** — frontend on **Vercel**, backend on **Supabase Cloud** (one project per env:
   dev/staging/prod; Docker for local dev), domain **crm.goalkeeper.com** via GoDaddy. *(Backlog M0.)*
2. **Design one centralized schema** (single Postgres DB) modelled on Coda + XG: core tables `contacts`, `companies`,
   `services` (police/fire/ambulance/prison), `clubs`, plus the football-domain tables. Use **relational/junction
   tables** so a contact or company can map to **multiple brands/clubs/businesses** (xG / Calma / Onesport /
   Goalkeeper.com) without duplication — this is how multi-company lives in one schema.
3. **Map data sources** from each team member into the schema; **migrate** existing seed/Coda data (adapt `scripts/gen-seed.ts`).
4. **Build the bespoke layer** (§7) as react-admin resources + custom screens, reusing the design tokens for the dark
   "Command Centre" theme.
5. **Wire auth** (Google OAuth, §5), then **integrations** (Gmail, WhatsApp Business, Shopify) to kill manual entry,
   then automation/reporting.

---

## 7. What's still TBD — gap analysis (Atomic CRM → our requirements)

Even the best-fit base doesn't ship our domain. The following is **net-new work** on top of Atomic CRM, ordered by
how bespoke it is. (Items map back to the requirement IDs.)

### A. Bespoke data model & objects — *the core build* (R1, XR-2/3)
- [ ] **Club directory** entity (~170 clubs, tier/league, country, crest) as a scouting universe **separate from
      Accounts**, with "promote to pipeline" action. *(new table + resource + UI)*
- [ ] **Contact-intel** model: per-club Sporting Director / Head of Recruitment / GK Coach, free-text intel notes,
      and **per-person verified LinkedIn URLs**. *(extend contacts or new table)*
- [ ] **Club email-pattern** model (`domain`, house `pattern`, contacts-on-file) + **email-derivation logic**
      (name + pattern → likely email). *(custom field + helper; no CRM ships this)*
- [ ] **Services** vertical: UK Police/Ambulance/Fire/Prison sports sections with type taxonomy + status. *(new resource)*
- [ ] **Shopify order** records (store, items, total, signal). *(new table; + sync, see §7.D)*
- [ ] **League** entity + **league-level outreach logs**. *(new tables)*
- [ ] **Coda-derived entities** (per 16 Jun decision): **Goalkeeper/Player**, **Position**, **Competition level /
      hierarchy**. *(model on the Coda + XG apps; confirm CRM-vs-xG-product scope with Diego before building)*
- [ ] **Many-to-many junction tables** so a contact/company maps to multiple brands/clubs/businesses without
      duplication — the structural basis for multi-company in one schema. *(core relational design)*

### B. Multi-brand pipelines (R2, R3, XR-1) — *must-have, not built-in*
- [ ] A **brand** dimension (xG / Onesport / Calma / Goalkeeper.com) on deals.
- [ ] **Per-brand stage sets** (8 stages for xG, 6 for Onesport/Calma, 6 for gkcom) and per-brand Kanban.
- [ ] **Global brand switcher/filter** across all screens; keep xG and Onesport prospect lists separate.
- [ ] **Weighted-pipeline rollups** (Σ value×prob) + closed-won totals; stage→probability auto-derivation.

### C. Outreach & automation (R5, R6, XR-5/6/8)
- [ ] **Outreach tracker** screen: unified prospect rows, status (Target/In-Pipeline/Won), coverage %.
- [ ] **"Batches of 10"** working view with send-readiness scoring and per-batch progress.
- [ ] **Target → pipeline promotion** modal (stage, contact, value, note) that creates/updates a deal.
- [ ] **Follow-up automation**: logging an outreach (account *or* league) auto-creates a dated follow-up task.
      *(Atomic has tasks/reminders, but this rule is custom — Supabase trigger or app logic.)*
- [ ] Task **grouping** (Overdue/Today/Upcoming/Completed) and follow-up vs manual typing.

### D. Reporting & integrations (R10, R11, R17–R19) — *promoted to must-have (16 Jun)*
- [ ] **Cross-brand revenue dashboard** (combined YTD, per-brand, xG closed-won breakdown) + charts, with
      **configurable weekly/monthly** reporting timelines. *(Atomic dashboards are basic.)*
- [ ] **Shopify** auto-sync (Onesport + Calma): order list + KPIs (net, AOV, high-value signal). **Replaces Sam's
      manual "upload report to Claude" flow.** *(integration TBD — needs Shopify API credentials.)*
- [ ] **Gmail** integration — log/sync email into the activity timeline. *(TBD — Gmail/Workspace API.)*
- [ ] **WhatsApp Business** integration — capture conversations. *(TBD — **requires a WhatsApp Business API key**.)*
- [ ] Dashboard **Hot Deals** widget + activity feed.

### E. UX, settings, polish (NFR-3, R13/R14)
- [ ] **Dark "Command Centre" theme** with per-brand accent colours; GBP everywhere; dense tables/Kanban/modals.
      *(reuse `src/lib/design/tokens.ts` + `globals.css`.)*
- [ ] **Settings**: active-brand toggles, notification preferences, weekly digest email. *(notifications/digest = automation work)*
- [ ] Click-to-act `mailto:` / `tel:` / LinkedIn links throughout (mostly free, but wired to our fields).
- [ ] **AI Intelligence** surface (the prototype has a button only) — enrichment/summarisation. *(nice-to-have, fully TBD.)*
- [ ] **Feedback feature with a visibility toggle** (Brendan, 16 Jun) — in-app feedback capture, switch controls who can see it. *(R20)*

### F. Data migration (NFR-7)
- [ ] Map and import the existing seed datasets (clubs, contacts, club-emails, services, deals, Shopify orders) **and
      the Coda data** into the new schema; adapt `gen-seed.ts` output to the new table shapes.

### G. Auth & access (R21) — *low/moderate effort, mostly config (see §5)*
- [ ] **Google OAuth** sign-in restricted to `@goalkeeper.com` (config + domain-check hook). *(near built-in.)*
- [ ] **Role-based access control** (Supabase roles table + JWT claim + RLS) — replaces blanket `using(true)`.
      *Ship after an initial all-team-full-access launch.*

**Rough effort read:** B + C + the core of A are the real build (the genuinely bespoke product). D's Shopify sync and
E's automation/AI are the longest single integrations. A's plain directories (Clubs/Services) and F (import) are
comparatively quick on the react-admin/Supabase foundation. Generic CRM plumbing (auth, contacts, companies, deals
CRUD, tasks, notes, CSV, theming primitives) is **provided by Atomic** and is the main thing we *don't* rebuild.

---

## 8. Risks & mitigations

- **Atomic's small community / thin built-ins.** *Mitigation:* we're already committing to build the bespoke layer;
  the MIT licence and small codebase mean low lock-in and easy forking. react-admin (its foundation) is widely used and well-documented.
- **"Did we under-rate Twenty's no-code speed?"** If the domain turns out to need *less* bespoke logic than the
  prototype implies, Twenty's UI-driven custom objects could be faster. *Mitigation:* the multi-pipeline + Supabase-reuse
  arguments still favour Atomic for *this* codebase; revisit only if requirements simplify.
- **Multi-pipeline complexity is real either way.** No open CRM ships 4 brand-specific pipelines cleanly; we own this
  logic regardless of base. Atomic just makes it code we control.
- **Shopify sync** is an external integration with its own maintenance cost — schedule it as a discrete later milestone, not part of the core CRM build.

---

## 9. Sources

- [Twenty CRM Review — The Dench Blog](https://www.dench.com/blog/twenty-crm-review)
- [Twenty CRM Review (2026) — Toolworthy](https://www.toolworthy.ai/tool/twenty)
- [Twenty — Multiple Pipelines / Record Types (GitHub Discussion #10631)](https://github.com/twentyhq/twenty/discussions/10631)
- [Twenty — Multiple Opportunity Pipelines (GitHub Issue #10454)](https://github.com/twentyhq/twenty/issues/10454)
- [Twenty — Pipeline user guide](https://twenty.com/user-guide/section/crm-essentials/pipeline)
- [Atomic CRM — GitHub (marmelab/atomic-crm)](https://github.com/marmelab/atomic-crm)
- [Introducing Atomic CRM — Marmelab blog](https://marmelab.com/blog/2024/09/06/open-source-crm-atomic-crm.html)
- [Atomic CRM Review — The Dench Blog](https://www.dench.com/blog/atomic-crm-review)
- [EspoCRM Features](https://www.espocrm.com/features/)
- [EspoCRM — Multiple Pipelines (community forum)](https://forum.espocrm.com/forum/general/77295-multiple-pipelines)
- [Best Open Source CRM Benchmark 2026 — Marmelab](https://marmelab.com/blog/2026/01/09/open-source-crm-benchmark-2026.html)
- [Top 20 Open-Source Self-Hosted CRMs (2026) — GrowCRM](https://growcrm.io/2026/01/04/top-20-open-source-self-hosted-crms-in-2025/)
- [Best Open Source CRM Tools in 2026 — OpenSourceAlternatives](https://www.opensourcealternatives.to/blog/best-open-source-crm)
- [Atomic CRM — Deploying to Production](https://marmelab.com/atomic-crm/doc/developers/deploy/)
- [Self-Hosted vs Cloud Supabase 2026 — QueryGlow](https://queryglow.com/blog/supabase-self-hosted)
- [Supabase — Custom Claims & Role-Based Access Control (RBAC)](https://supabase.com/docs/guides/api/custom-claims-and-role-based-access-control-rbac)

> *Note: the Marmelab 2026 benchmark is authored by Atomic CRM's maintainer; its scores are corroborated here against
> independent reviews (Dench, Toolworthy, GrowCRM) and primary sources (Twenty's own GitHub/docs).*
