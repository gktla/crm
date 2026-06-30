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
alter table public.org_types enable row level security;
alter table public.nations enable row level security;
alter table public.sports enable row level security;
alter table public.target_lists enable row level security;
alter table public.clubs enable row level security;
alter table public.company_org_types enable row level security;
alter table public.org_relationships enable row level security;
alter table public.competitions enable row level security;
alter table public.company_brands enable row level security;
-- Goalkeeper schema (Phase 2)
alter table public.company_contacts enable row level security;
alter table public.contact_social_profiles enable row level security;
-- Goalkeeper schema (Phase 3 / 4)
alter table public.deal_modules enable row level security;
alter table public.activities enable row level security;
-- Goalkeeper schema (Phase 6/7)
alter table public.players enable row level security;
alter table public.player_org_assignments enable row level security;
alter table public.player_citizenships enable row level security;
alter table public.player_representations enable row level security;
alter table public.player_social_profiles enable row level security;
alter table public.player_target_lists enable row level security;
alter table public.teams enable row level security;
alter table public.team_sports enable row level security;
alter table public.org_target_lists enable row level security;

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

-- Org types
create policy "Enable read access for authenticated users" on public.org_types for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.org_types for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.org_types for update to authenticated using (true) with check (true);
create policy "Org Types Delete Policy" on public.org_types for delete to authenticated using (true);

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

-- Company org types
create policy "Enable read access for authenticated users" on public.company_org_types for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.company_org_types for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.company_org_types for update to authenticated using (true) with check (true);
create policy "Company Org Types Delete Policy" on public.company_org_types for delete to authenticated using (true);

-- Org relationships
create policy "Enable read access for authenticated users" on public.org_relationships for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.org_relationships for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.org_relationships for update to authenticated using (true) with check (true);
create policy "Org Relationships Delete Policy" on public.org_relationships for delete to authenticated using (true);

-- Competitions
create policy "Enable read access for authenticated users" on public.competitions for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.competitions for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.competitions for update to authenticated using (true) with check (true);
create policy "Competitions Delete Policy" on public.competitions for delete to authenticated using (true);

-- Company brands
create policy "Enable read access for authenticated users" on public.company_brands for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.company_brands for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.company_brands for update to authenticated using (true) with check (true);
create policy "Company Brands Delete Policy" on public.company_brands for delete to authenticated using (true);

-- Company contacts (Phase 2)
create policy "Enable read access for authenticated users" on public.company_contacts for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.company_contacts for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.company_contacts for update to authenticated using (true) with check (true);
create policy "Company Contacts Delete Policy" on public.company_contacts for delete to authenticated using (true);

-- Contact social profiles (Phase 2)
create policy "Enable read access for authenticated users" on public.contact_social_profiles for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.contact_social_profiles for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.contact_social_profiles for update to authenticated using (true) with check (true);
create policy "Contact Social Profiles Delete Policy" on public.contact_social_profiles for delete to authenticated using (true);

-- Deal modules (Phase 3)
create policy "Enable read access for authenticated users" on public.deal_modules for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.deal_modules for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.deal_modules for update to authenticated using (true) with check (true);
create policy "Deal Modules Delete Policy" on public.deal_modules for delete to authenticated using (true);

-- Activities (Phase 4)
create policy "Enable read access for authenticated users" on public.activities for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.activities for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.activities for update to authenticated using (true) with check (true);
create policy "Activities Delete Policy" on public.activities for delete to authenticated using (true);

-- Players (Phase 6)
create policy "Enable read access for authenticated users" on public.players for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.players for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.players for update to authenticated using (true) with check (true);
create policy "Players Delete Policy" on public.players for delete to authenticated using (true);

-- Player org assignments (Phase 6)
create policy "Enable read access for authenticated users" on public.player_org_assignments for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.player_org_assignments for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.player_org_assignments for update to authenticated using (true) with check (true);
create policy "Player Org Assignments Delete Policy" on public.player_org_assignments for delete to authenticated using (true);

-- Player citizenships (Phase 6)
create policy "Enable read access for authenticated users" on public.player_citizenships for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.player_citizenships for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.player_citizenships for update to authenticated using (true) with check (true);
create policy "Player Citizenships Delete Policy" on public.player_citizenships for delete to authenticated using (true);

-- Player representations (Phase 6)
create policy "Enable read access for authenticated users" on public.player_representations for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.player_representations for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.player_representations for update to authenticated using (true) with check (true);
create policy "Player Representations Delete Policy" on public.player_representations for delete to authenticated using (true);

-- Player social profiles (Phase 6)
create policy "Enable read access for authenticated users" on public.player_social_profiles for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.player_social_profiles for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.player_social_profiles for update to authenticated using (true) with check (true);
create policy "Player Social Profiles Delete Policy" on public.player_social_profiles for delete to authenticated using (true);

-- Player target lists (Phase 6)
create policy "Enable read access for authenticated users" on public.player_target_lists for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.player_target_lists for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.player_target_lists for update to authenticated using (true) with check (true);
create policy "Player Target Lists Delete Policy" on public.player_target_lists for delete to authenticated using (true);

-- Teams (Phase 7)
create policy "Enable read access for authenticated users" on public.teams for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.teams for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.teams for update to authenticated using (true) with check (true);
create policy "Teams Delete Policy" on public.teams for delete to authenticated using (true);

-- Team sports (Phase 7)
create policy "Enable read access for authenticated users" on public.team_sports for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.team_sports for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.team_sports for update to authenticated using (true) with check (true);
create policy "Team Sports Delete Policy" on public.team_sports for delete to authenticated using (true);

-- Org target lists (Phase 7)
create policy "Enable read access for authenticated users" on public.org_target_lists for select to authenticated using (true);
create policy "Enable insert for authenticated users only" on public.org_target_lists for insert to authenticated with check (true);
create policy "Enable update for authenticated users only" on public.org_target_lists for update to authenticated using (true) with check (true);
create policy "Org Target Lists Delete Policy" on public.org_target_lists for delete to authenticated using (true);
