--
-- Grants
-- This file declares all grants and default privileges for the public schema.
--

-- Schema usage
grant usage on schema public to postgres;
grant usage on schema public to anon;
grant usage on schema public to authenticated;
grant usage on schema public to service_role;

-- Function grants
grant all on function public.cleanup_note_attachments() to anon;
grant all on function public.cleanup_note_attachments() to authenticated;
grant all on function public.cleanup_note_attachments() to service_role;

grant all on function public.get_avatar_for_email(text) to anon;
grant all on function public.get_avatar_for_email(text) to authenticated;
grant all on function public.get_avatar_for_email(text) to service_role;

grant all on function public.get_domain_favicon(text) to anon;
grant all on function public.get_domain_favicon(text) to authenticated;
grant all on function public.get_domain_favicon(text) to service_role;

grant all on function public.get_note_attachments_function_url() to anon;
grant all on function public.get_note_attachments_function_url() to authenticated;
grant all on function public.get_note_attachments_function_url() to service_role;

revoke all on function public.get_user_id_by_email(text) from public;
grant all on function public.get_user_id_by_email(text) to service_role;

grant all on function public.handle_company_saved() to anon;
grant all on function public.handle_company_saved() to authenticated;
grant all on function public.handle_company_saved() to service_role;

grant all on function public.handle_contact_note_created_or_updated() to anon;
grant all on function public.handle_contact_note_created_or_updated() to authenticated;
grant all on function public.handle_contact_note_created_or_updated() to service_role;

grant all on function public.handle_contact_saved() to anon;
grant all on function public.handle_contact_saved() to authenticated;
grant all on function public.handle_contact_saved() to service_role;

grant all on function public.handle_new_user() to anon;
grant all on function public.handle_new_user() to authenticated;
grant all on function public.handle_new_user() to service_role;

grant all on function public.handle_update_user() to anon;
grant all on function public.handle_update_user() to authenticated;
grant all on function public.handle_update_user() to service_role;

grant all on function public.is_admin() to anon;
grant all on function public.is_admin() to authenticated;
grant all on function public.is_admin() to service_role;

grant all on function public.lowercase_email_jsonb() to anon;
grant all on function public.lowercase_email_jsonb() to authenticated;
grant all on function public.lowercase_email_jsonb() to service_role;

grant all on function public.merge_contacts(bigint, bigint) to anon;
grant all on function public.merge_contacts(bigint, bigint) to authenticated;
grant all on function public.merge_contacts(bigint, bigint) to service_role;

grant all on function public.set_sales_id_default() to anon;
grant all on function public.set_sales_id_default() to authenticated;
grant all on function public.set_sales_id_default() to service_role;

-- Table grants
grant all on table public.companies to anon;
grant all on table public.companies to authenticated;
grant all on table public.companies to service_role;

grant all on table public.contacts to anon;
grant all on table public.contacts to authenticated;
grant all on table public.contacts to service_role;

grant all on table public.contact_notes to anon;
grant all on table public.contact_notes to authenticated;
grant all on table public.contact_notes to service_role;

grant all on table public.deals to anon;
grant all on table public.deals to authenticated;
grant all on table public.deals to service_role;

grant all on table public.deal_notes to anon;
grant all on table public.deal_notes to authenticated;
grant all on table public.deal_notes to service_role;

grant all on table public.sales to anon;
grant all on table public.sales to authenticated;
grant all on table public.sales to service_role;

grant all on table public.tags to anon;
grant all on table public.tags to authenticated;
grant all on table public.tags to service_role;

grant all on table public.tasks to anon;
grant all on table public.tasks to authenticated;
grant all on table public.tasks to service_role;

grant all on table public.configuration to anon;
grant all on table public.configuration to authenticated;
grant all on table public.configuration to service_role;

grant all on table public.favicons_excluded_domains to anon;
grant all on table public.favicons_excluded_domains to authenticated;
grant all on table public.favicons_excluded_domains to service_role;

-- Goalkeeper schema (Phase 1) table grants
-- Matches the Atomic pattern: table privileges granted to all API roles; anon is
-- still blocked at row level because it has no RLS policy on these tables.
grant all on table public.brands to anon;
grant all on table public.brands to authenticated;
grant all on table public.brands to service_role;

grant all on table public.pipeline_stages to anon;
grant all on table public.pipeline_stages to authenticated;
grant all on table public.pipeline_stages to service_role;

grant all on table public.org_types to anon;
grant all on table public.org_types to authenticated;
grant all on table public.org_types to service_role;

grant all on table public.nations to anon;
grant all on table public.nations to authenticated;
grant all on table public.nations to service_role;

grant all on table public.sports to anon;
grant all on table public.sports to authenticated;
grant all on table public.sports to service_role;

grant all on table public.target_lists to anon;
grant all on table public.target_lists to authenticated;
grant all on table public.target_lists to service_role;

grant all on table public.clubs to anon;
grant all on table public.clubs to authenticated;
grant all on table public.clubs to service_role;

grant all on table public.company_org_types to anon;
grant all on table public.company_org_types to authenticated;
grant all on table public.company_org_types to service_role;

grant all on table public.org_relationships to anon;
grant all on table public.org_relationships to authenticated;
grant all on table public.org_relationships to service_role;

grant all on table public.competitions to anon;
grant all on table public.competitions to authenticated;
grant all on table public.competitions to service_role;

grant all on table public.company_brands to anon;
grant all on table public.company_brands to authenticated;
grant all on table public.company_brands to service_role;

-- Goalkeeper schema (Phase 2) table grants
grant all on table public.company_contacts to anon;
grant all on table public.company_contacts to authenticated;
grant all on table public.company_contacts to service_role;

grant all on table public.contact_social_profiles to anon;
grant all on table public.contact_social_profiles to authenticated;
grant all on table public.contact_social_profiles to service_role;

-- Goalkeeper schema (Phase 3 / 4) table grants
grant all on table public.deal_modules to anon;
grant all on table public.deal_modules to authenticated;
grant all on table public.deal_modules to service_role;

grant all on table public.activities to anon;
grant all on table public.activities to authenticated;
grant all on table public.activities to service_role;

-- Goalkeeper schema (Phase 6/7) table grants
grant all on table public.players to anon;
grant all on table public.players to authenticated;
grant all on table public.players to service_role;

grant all on table public.player_org_assignments to anon;
grant all on table public.player_org_assignments to authenticated;
grant all on table public.player_org_assignments to service_role;

grant all on table public.player_citizenships to anon;
grant all on table public.player_citizenships to authenticated;
grant all on table public.player_citizenships to service_role;

grant all on table public.player_representations to anon;
grant all on table public.player_representations to authenticated;
grant all on table public.player_representations to service_role;

grant all on table public.player_social_profiles to anon;
grant all on table public.player_social_profiles to authenticated;
grant all on table public.player_social_profiles to service_role;

grant all on table public.player_target_lists to anon;
grant all on table public.player_target_lists to authenticated;
grant all on table public.player_target_lists to service_role;

grant all on table public.teams to anon;
grant all on table public.teams to authenticated;
grant all on table public.teams to service_role;

grant all on table public.team_sports to anon;
grant all on table public.team_sports to authenticated;
grant all on table public.team_sports to service_role;

grant all on table public.org_target_lists to anon;
grant all on table public.org_target_lists to authenticated;
grant all on table public.org_target_lists to service_role;

-- View grants
grant all on table public.activity_log to anon;
grant all on table public.activity_log to authenticated;
grant all on table public.activity_log to service_role;

grant all on table public.current_squad to anon;
grant all on table public.current_squad to authenticated;
grant all on table public.current_squad to service_role;

grant all on table public.companies_summary to anon;
grant all on table public.companies_summary to authenticated;
grant all on table public.companies_summary to service_role;

grant all on table public.contacts_summary to anon;
grant all on table public.contacts_summary to authenticated;
grant all on table public.contacts_summary to service_role;

grant all on table public.init_state to anon;
grant all on table public.init_state to authenticated;
grant all on table public.init_state to service_role;

-- Sequence grants
grant all on sequence public.companies_id_seq to anon;
grant all on sequence public.companies_id_seq to authenticated;
grant all on sequence public.companies_id_seq to service_role;

grant all on sequence public."contactNotes_id_seq" to anon;
grant all on sequence public."contactNotes_id_seq" to authenticated;
grant all on sequence public."contactNotes_id_seq" to service_role;

grant all on sequence public.contacts_id_seq to anon;
grant all on sequence public.contacts_id_seq to authenticated;
grant all on sequence public.contacts_id_seq to service_role;

grant all on sequence public."dealNotes_id_seq" to anon;
grant all on sequence public."dealNotes_id_seq" to authenticated;
grant all on sequence public."dealNotes_id_seq" to service_role;

grant all on sequence public.deals_id_seq to anon;
grant all on sequence public.deals_id_seq to authenticated;
grant all on sequence public.deals_id_seq to service_role;

grant all on sequence public.favicons_excluded_domains_id_seq to anon;
grant all on sequence public.favicons_excluded_domains_id_seq to authenticated;
grant all on sequence public.favicons_excluded_domains_id_seq to service_role;

grant all on sequence public.sales_id_seq to anon;
grant all on sequence public.sales_id_seq to authenticated;
grant all on sequence public.sales_id_seq to service_role;

grant all on sequence public.tags_id_seq to anon;
grant all on sequence public.tags_id_seq to authenticated;
grant all on sequence public.tags_id_seq to service_role;

grant all on sequence public.tasks_id_seq to anon;
grant all on sequence public.tasks_id_seq to authenticated;
grant all on sequence public.tasks_id_seq to service_role;

-- Goalkeeper schema (Phase 1) sequence grants
-- clubs and company_brands have no identity sequence (PKs are FK / composite).
grant all on sequence public.brands_id_seq to anon;
grant all on sequence public.brands_id_seq to authenticated;
grant all on sequence public.brands_id_seq to service_role;

grant all on sequence public.pipeline_stages_id_seq to anon;
grant all on sequence public.pipeline_stages_id_seq to authenticated;
grant all on sequence public.pipeline_stages_id_seq to service_role;

grant all on sequence public.org_types_id_seq to anon;
grant all on sequence public.org_types_id_seq to authenticated;
grant all on sequence public.org_types_id_seq to service_role;

grant all on sequence public.org_relationships_id_seq to anon;
grant all on sequence public.org_relationships_id_seq to authenticated;
grant all on sequence public.org_relationships_id_seq to service_role;

grant all on sequence public.nations_id_seq to anon;
grant all on sequence public.nations_id_seq to authenticated;
grant all on sequence public.nations_id_seq to service_role;

grant all on sequence public.sports_id_seq to anon;
grant all on sequence public.sports_id_seq to authenticated;
grant all on sequence public.sports_id_seq to service_role;

grant all on sequence public.target_lists_id_seq to anon;
grant all on sequence public.target_lists_id_seq to authenticated;
grant all on sequence public.target_lists_id_seq to service_role;

-- Goalkeeper schema (Phase 2) sequence grants
grant all on sequence public.company_contacts_id_seq to anon;
grant all on sequence public.company_contacts_id_seq to authenticated;
grant all on sequence public.company_contacts_id_seq to service_role;

grant all on sequence public.contact_social_profiles_id_seq to anon;
grant all on sequence public.contact_social_profiles_id_seq to authenticated;
grant all on sequence public.contact_social_profiles_id_seq to service_role;

-- Goalkeeper schema (Phase 4) sequence grants (deal_modules has no identity seq)
grant all on sequence public.activities_id_seq to anon;
grant all on sequence public.activities_id_seq to authenticated;
grant all on sequence public.activities_id_seq to service_role;

-- Goalkeeper schema (Phase 6/7) sequence grants
grant all on sequence public.players_id_seq to anon;
grant all on sequence public.players_id_seq to authenticated;
grant all on sequence public.players_id_seq to service_role;

grant all on sequence public.player_org_assignments_id_seq to anon;
grant all on sequence public.player_org_assignments_id_seq to authenticated;
grant all on sequence public.player_org_assignments_id_seq to service_role;

grant all on sequence public.player_representations_id_seq to anon;
grant all on sequence public.player_representations_id_seq to authenticated;
grant all on sequence public.player_representations_id_seq to service_role;

grant all on sequence public.player_social_profiles_id_seq to anon;
grant all on sequence public.player_social_profiles_id_seq to authenticated;
grant all on sequence public.player_social_profiles_id_seq to service_role;

grant all on sequence public.teams_id_seq to anon;
grant all on sequence public.teams_id_seq to authenticated;
grant all on sequence public.teams_id_seq to service_role;

-- Goalkeeper schema (Phase 2): private sync helpers are internal only.
-- Revoke execute from PUBLIC; no grants to anon/authenticated/service_role.
-- Triggers still invoke them (trigger execution does not check EXECUTE privilege).
revoke execute on function private.gk_set_updated_at() from public;
revoke execute on function private.gk_apply_primary_company(bigint) from public;
revoke execute on function private.gk_set_primary_company_contact(bigint) from public;
revoke execute on function private.gk_set_primary_company_for_contact(bigint, bigint) from public;
revoke execute on function private.gk_sync_primary_company() from public;
revoke execute on function private.gk_bridge_contact_company() from public;
-- Phase 3 / 4 private helpers
revoke execute on function private.gk_resolve_pipeline_stage(bigint, text) from public;
revoke execute on function private.gk_sync_deal_stage() from public;
revoke execute on function private.gk_check_deal_module_brand() from public;
revoke execute on function private.gk_handle_activity_followup() from public;

-- Default privileges
alter default privileges for role postgres in schema public grant all on sequences to postgres;
alter default privileges for role postgres in schema public grant all on sequences to anon;
alter default privileges for role postgres in schema public grant all on sequences to authenticated;
alter default privileges for role postgres in schema public grant all on sequences to service_role;

alter default privileges for role postgres in schema public grant all on functions to postgres;
alter default privileges for role postgres in schema public grant all on functions to anon;
alter default privileges for role postgres in schema public grant all on functions to authenticated;
alter default privileges for role postgres in schema public grant all on functions to service_role;

alter default privileges for role postgres in schema public grant all on tables to postgres;
alter default privileges for role postgres in schema public grant all on tables to anon;
alter default privileges for role postgres in schema public grant all on tables to authenticated;
alter default privileges for role postgres in schema public grant all on tables to service_role;
