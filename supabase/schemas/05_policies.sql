--
-- Row Level Security
-- This file declares RLS policies for all tables.
--

-- Enable RLS on all tables
alter table public.companies enable row level security;
alter table public.contacts enable row level security;
alter table public.contact_notes enable row level security;
alter table public.deals enable row level security;
alter table public.deal_notes enable row level security;
alter table public.sales enable row level security;
alter table public.tags enable row level security;
alter table public.tasks enable row level security;
alter table public.configuration enable row level security;
alter table public.favicons_excluded_domains enable row level security;
-- Goalkeeper schema (Phase 1)
alter table public.brands enable row level security;
alter table public.pipeline_stages enable row level security;
alter table public.leagues enable row level security;
alter table public.nations enable row level security;
alter table public.sports enable row level security;
alter table public.target_lists enable row level security;
alter table public.clubs enable row level security;
alter table public.company_brands enable row level security;

-- Companies
create policy "Enable read access for authenticated users" on public.companies for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.companies for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.companies for update to authenticated using (true) with check (true);
create policy "Company Delete Policy" on public.companies for delete to authenticated using (true);

-- Contacts
create policy "Enable read access for authenticated users" on public.contacts for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.contacts for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.contacts for update to authenticated using (true) with check (true);
create policy "Contact Delete Policy" on public.contacts for delete to authenticated using (true);

-- Contact Notes
create policy "Enable read access for authenticated users" on public.contact_notes for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.contact_notes for insert to authenticated with check (true);
create policy "Contact Notes Update policy" on public.contact_notes for update to authenticated using (true);
create policy "Contact Notes Delete Policy" on public.contact_notes for delete to authenticated using (true);

-- Deals
create policy "Enable read access for authenticated users" on public.deals for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.deals for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.deals for update to authenticated using (true) with check (true);
create policy "Deals Delete Policy" on public.deals for delete to authenticated using (true);

-- Deal Notes
create policy "Enable read access for authenticated users" on public.deal_notes for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.deal_notes for insert to authenticated with check (true);
create policy "Deal Notes Update Policy" on public.deal_notes for update to authenticated using (true);
create policy "Deal Notes Delete Policy" on public.deal_notes for delete to authenticated using (true);

-- Sales
create policy "Enable read access for authenticated users" on public.sales for select to authenticated using (true);

-- Tags
create policy "Enable read access for authenticated users" on public.tags for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.tags for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.tags for update to authenticated using (true);
create policy "Enable delete for authenticated users only" on public.tags for delete to authenticated using (true);

-- Tasks
create policy "Enable read access for authenticated users" on public.tasks for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.tasks for insert to authenticated with check (true);
create policy "Task Update Policy" on public.tasks for update to authenticated using (true);
create policy "Task Delete Policy" on public.tasks for delete to authenticated using (true);

-- Configuration (admin-only for writes)
create policy "Enable read for authenticated" on public.configuration for select to authenticated using (true);
create policy "Enable insert for admins" on public.configuration for insert to authenticated with check (public.is_admin());
create policy "Enable update for admins" on public.configuration for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- Favicons excluded domains
create policy "Enable access for authenticated users only" on public.favicons_excluded_domains to authenticated using (true) with check (true);

--
-- Goalkeeper schema (Phase 1)
-- Single-tenant launch model (Decision 10): authenticated users get full access;
-- anon has no policy and is therefore denied. RBAC arrives in a later milestone.
--

-- Brands
create policy "Enable read access for authenticated users" on public.brands for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.brands for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.brands for update to authenticated using (true) with check (true);
create policy "Brands Delete Policy" on public.brands for delete to authenticated using (true);

-- Pipeline stages
create policy "Enable read access for authenticated users" on public.pipeline_stages for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.pipeline_stages for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.pipeline_stages for update to authenticated using (true) with check (true);
create policy "Pipeline Stages Delete Policy" on public.pipeline_stages for delete to authenticated using (true);

-- Leagues
create policy "Enable read access for authenticated users" on public.leagues for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.leagues for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.leagues for update to authenticated using (true) with check (true);
create policy "Leagues Delete Policy" on public.leagues for delete to authenticated using (true);

-- Nations
create policy "Enable read access for authenticated users" on public.nations for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.nations for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.nations for update to authenticated using (true) with check (true);
create policy "Nations Delete Policy" on public.nations for delete to authenticated using (true);

-- Sports
create policy "Enable read access for authenticated users" on public.sports for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.sports for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.sports for update to authenticated using (true) with check (true);
create policy "Sports Delete Policy" on public.sports for delete to authenticated using (true);

-- Target lists
create policy "Enable read access for authenticated users" on public.target_lists for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.target_lists for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.target_lists for update to authenticated using (true) with check (true);
create policy "Target Lists Delete Policy" on public.target_lists for delete to authenticated using (true);

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
