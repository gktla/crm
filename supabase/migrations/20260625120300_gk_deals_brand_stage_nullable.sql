-- Goalkeeper schema — Phase 3A: deals brand/stage columns (nullable) + deal_modules.
--
-- Adds brand_id/stage_id as NULLABLE (FKs + NOT NULL come in 3C, after the 3B
-- backfill), plus probability and external IDs, and creates the deal_modules
-- junction with RLS/policies/grants. The legacy deals.stage slug is preserved.
-- Additive; no historical migration touched.

--
-- 1. Extend deals (deals.updated_at already exists from Atomic, so it is not added)
--
alter table public.deals add column brand_id bigint;
alter table public.deals add column stage_id bigint;
alter table public.deals add column probability smallint;
alter table public.deals add column coda_row_id text;
alter table public.deals add column legacy_ref text;

alter table public.deals
    add constraint deals_probability_check check (probability between 0 and 100);
-- coda_row_id is NOT unique for deals (per canonical); legacy_ref IS unique
-- (vibecoded d## ids). See 02-field-mapping §14 / 03 deals.
alter table public.deals add constraint deals_legacy_ref_key unique (legacy_ref);

create index deals_brand_idx on public.deals using btree (brand_id);
create index deals_stage_idx on public.deals using btree (stage_id);

--
-- 2. deal_modules (xG-only modules; PK prevents duplicate module per deal)
--
create table public.deal_modules (
    deal_id bigint not null,
    module text not null,
    created_at timestamp with time zone not null default now(),
    primary key (deal_id, module),
    constraint deal_modules_module_check check (module in
        ('ongoing_support', 'transfer_market_support', 'opposition_analysis', 'api'))
);

alter table public.deal_modules
    add constraint deal_modules_deal_id_fkey foreign key (deal_id) references public.deals(id) on delete cascade;

--
-- 3. RLS + policies (single-tenant; anon denied by absence of policy)
--
alter table public.deal_modules enable row level security;

create policy "Enable read access for authenticated users" on public.deal_modules for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.deal_modules for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.deal_modules for update to authenticated using (true) with check (true);
create policy "Deal Modules Delete Policy" on public.deal_modules for delete to authenticated using (true);

--
-- 4. Grants (deal_modules has no identity sequence: composite PK)
--
grant all on table public.deal_modules to anon;
grant all on table public.deal_modules to authenticated;
grant all on table public.deal_modules to service_role;
