--
-- Triggers
-- This file declares all triggers.
--

-- Auto-populate sales_id from current auth user on insert
create or replace trigger set_company_sales_id_trigger
    before insert on public.companies
    for each row execute function public.set_sales_id_default();

create or replace trigger set_contact_sales_id_trigger
    before insert on public.contacts
    for each row execute function public.set_sales_id_default();

create or replace trigger set_contact_notes_sales_id_trigger
    before insert on public.contact_notes
    for each row execute function public.set_sales_id_default();

create or replace trigger set_deal_sales_id_trigger
    before insert on public.deals
    for each row execute function public.set_sales_id_default();

create or replace trigger set_deal_notes_sales_id_trigger
    before insert on public.deal_notes
    for each row execute function public.set_sales_id_default();

create or replace trigger set_task_sales_id_trigger
    before insert on public.tasks
    for each row execute function public.set_sales_id_default();

-- Auto-fetch company logo from website favicon on save
create or replace trigger company_saved
    before insert or update on public.companies
    for each row execute function public.handle_company_saved();

-- Lowercase contact emails before insert or update (must run before contact_saved)
create or replace trigger "10_lowercase_contact_emails"
    before insert or update on public.contacts
    for each row execute function public.lowercase_email_jsonb();

-- Auto-fetch contact avatar from email on save (runs after lowercase_contact_emails)
create or replace trigger "20_contact_saved"
    before insert or update on public.contacts
    for each row execute function public.handle_contact_saved();

-- Update contact.last_seen when a contact note is created
create or replace trigger on_public_contact_notes_created_or_updated
    after insert on public.contact_notes
    for each row execute function public.handle_contact_note_created_or_updated();

-- Cleanup storage attachments when contact notes are updated or deleted
create or replace trigger on_contact_notes_attachments_updated_delete_note_attachments
    after update on public.contact_notes
    for each row
    when (old.attachments is distinct from new.attachments)
    execute function public.cleanup_note_attachments();

create or replace trigger on_contact_notes_deleted_delete_note_attachments
    after delete on public.contact_notes
    for each row execute function public.cleanup_note_attachments();

-- Cleanup storage attachments when deal notes are updated or deleted
create or replace trigger on_deal_notes_attachments_updated_delete_note_attachments
    after update on public.deal_notes
    for each row
    when (old.attachments is distinct from new.attachments)
    execute function public.cleanup_note_attachments();

create or replace trigger on_deal_notes_deleted_delete_note_attachments
    after delete on public.deal_notes
    for each row execute function public.cleanup_note_attachments();

-- Auth triggers: sync auth.users to public.sales
create or replace trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

create or replace trigger on_auth_user_updated
    after update on auth.users
    for each row execute function public.handle_update_user();

-- Goalkeeper schema (Phase 2): updated_at maintenance
create or replace trigger set_contacts_updated_at
    before update on public.contacts
    for each row execute function private.gk_set_updated_at();

create or replace trigger set_company_contacts_updated_at
    before update on public.company_contacts
    for each row execute function private.gk_set_updated_at();

create or replace trigger set_contact_social_profiles_updated_at
    before update on public.contact_social_profiles
    for each row execute function private.gk_set_updated_at();

-- Goalkeeper schema (Phase 2): bidirectional sync of contacts.company_id mirror
-- company_contacts change -> recompute contacts.company_id
create or replace trigger gk_company_contacts_sync
    after insert or delete or update of company_id, contact_id, is_primary, is_current
    on public.company_contacts
    for each row execute function private.gk_sync_primary_company();

-- Atomic-side contacts.company_id change -> create/promote company_contacts
create or replace trigger gk_contacts_company_bridge
    after insert or update of company_id on public.contacts
    for each row execute function private.gk_bridge_contact_company();

-- Goalkeeper schema (Phase 3): keep deals.stage_id <-> deals.stage (slug) in sync;
-- accept legacy slug writes; reject cross-brand / unknown stages. BEFORE -> no recursion.
create or replace trigger gk_deals_stage_sync
    before insert or update of stage_id, stage, brand_id on public.deals
    for each row execute function private.gk_sync_deal_stage();

-- deal_modules only apply to xG-brand deals.
create or replace trigger gk_deal_modules_brand_guard
    before insert or update on public.deal_modules
    for each row execute function private.gk_check_deal_module_brand();

-- Goalkeeper schema (Phase 4): activity follow-up automation (one task per activity).
create or replace trigger gk_activities_followup
    after insert or update of requires_follow_up, follow_up_date, contact_id, company_id, deal_id, sales_id
    on public.activities
    for each row execute function private.gk_handle_activity_followup();
