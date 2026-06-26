-- Goalkeeper schema — Phase 1, migration 2: companies extension + clubs.
--
-- Extends companies with organisation classification and external IDs, creates
-- the 1:1 clubs extension and the company_brands junction (both with RLS +
-- policies + grants, Decision 10), and refreshes companies_summary so the new
-- columns surface in list/show. Depends on migration 1 (brands). Additive only.

--
-- Extend companies
--

alter table public.companies add column kind text not null default 'company';
alter table public.companies add column ltv bigint;
alter table public.companies add column updated_at timestamp with time zone not null default now();
alter table public.companies add column coda_row_id text;
alter table public.companies add column legacy_ref text;

-- Documented organisation kinds (Decision 13: CHECK over inventoried values,
-- extended by future migration rather than a lookup table for now).
alter table public.companies
    add constraint companies_kind_check check (
        kind in (
            'pro_club', 'federation', 'media', 'agency', 'service',
            'school', 'university', 'grassroots', 'company'
        )
    );

-- coda_row_id is reserved for a general organisations table (Decision 14);
-- the Club CRM Row ID lives in clubs.coda_row_id, never here.
alter table public.companies add constraint companies_coda_row_id_key unique (coda_row_id);
alter table public.companies add constraint companies_legacy_ref_key unique (legacy_ref);

create index companies_kind_idx on public.companies using btree (kind);
create index companies_name_idx on public.companies using btree (name);

--
-- Clubs (1:1 extension of companies; company_id is PK and FK)
--

create table public.clubs (
    company_id bigint primary key,
    league_id bigint,
    nation_id bigint,
    crest text,
    keeper_count smallint not null default 0,
    contract_end date,
    hit_list boolean not null default false,
    -- Free text on purpose (Decision 12: xg_status values not fully inventoried).
    xg_status text,
    email_domain text,
    email_pattern text,
    notes text,
    -- Single source of truth for the Club CRM Row ID (Decision 14).
    coda_row_id text unique,
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone not null default now(),
    constraint clubs_keeper_count_check check (keeper_count >= 0)
);

alter table public.clubs
    add constraint clubs_company_id_fkey foreign key (company_id) references public.companies(id) on delete cascade;
alter table public.clubs
    add constraint clubs_league_id_fkey foreign key (league_id) references public.leagues(id);
alter table public.clubs
    add constraint clubs_nation_id_fkey foreign key (nation_id) references public.nations(id);

create index clubs_league_idx on public.clubs using btree (league_id);
create index clubs_nation_idx on public.clubs using btree (nation_id);
create index clubs_xg_status_idx on public.clubs using btree (xg_status);

--
-- Company brands (N-N companies <-> brands)
--

create table public.company_brands (
    company_id bigint not null,
    brand_id bigint not null,
    created_at timestamp with time zone not null default now(),
    primary key (company_id, brand_id)
);

alter table public.company_brands
    add constraint company_brands_company_id_fkey foreign key (company_id) references public.companies(id) on delete cascade;
alter table public.company_brands
    add constraint company_brands_brand_id_fkey foreign key (brand_id) references public.brands(id) on delete cascade;

--
-- Row Level Security + policies (Decision 10)
--

alter table public.clubs enable row level security;
alter table public.company_brands enable row level security;

-- Clubs
create policy "Enable read access for authenticated users" on public.clubs for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.clubs for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.clubs for update to authenticated using (true) with check (true);
create policy "Clubs Delete Policy" on public.clubs for delete to authenticated using (true);

-- Company brands
create policy "Enable read access for authenticated users" on public.company_brands for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.company_brands for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.company_brands for update to authenticated using (true) with check (true);
create policy "Company Brands Delete Policy" on public.company_brands for delete to authenticated using (true);

--
-- Grants (clubs and company_brands have no identity sequence)
--

grant all on table public.clubs to anon;
grant all on table public.clubs to authenticated;
grant all on table public.clubs to service_role;

grant all on table public.company_brands to anon;
grant all on table public.company_brands to authenticated;
grant all on table public.company_brands to service_role;

--
-- Refresh companies_summary to expose the new columns. Existing columns and the
-- nb_deals / nb_contacts behaviour are unchanged; security_invoker is preserved.
--

create or replace view public.companies_summary with (security_invoker = on) as
select
    c.id,
    c.created_at,
    c.name,
    c.sector,
    c.size,
    c.linkedin_url,
    c.website,
    c.phone_number,
    c.address,
    c.zipcode,
    c.city,
    c.state_abbr,
    c.sales_id,
    c.context_links,
    c.country,
    c.description,
    c.revenue,
    c.tax_identifier,
    c.logo,
    count(distinct d.id) as nb_deals,
    count(distinct co.id) as nb_contacts,
    -- New columns appended at the end so CREATE OR REPLACE VIEW preserves the
    -- existing leading columns (Postgres only allows appending to a replaced view).
    c.kind,
    c.ltv,
    c.updated_at,
    c.coda_row_id,
    c.legacy_ref
from public.companies c
    left join public.deals d on c.id = d.company_id
    left join public.contacts co on c.id = co.company_id
group by c.id;
