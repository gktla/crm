--
-- Functions
-- This file declares all PL/pgSQL functions in the public schema, plus the
-- Goalkeeper (Phase 2) private sync helpers in the private schema.
--

-- Goalkeeper schema (Phase 2): private sync helpers (internal; not exposed as RPC).
-- Format matches pg_dump (see AGENTS.md). Grants/revokes live in 06_grants.sql.

CREATE OR REPLACE FUNCTION "private"."gk_set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
    new.updated_at = now();
    return new;
end;
$$;

CREATE OR REPLACE FUNCTION "private"."gk_apply_primary_company"("p_contact_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    v_company_id bigint;
    v_prev text;
begin
    select cc.company_id into v_company_id
    from public.company_contacts cc
    where cc.contact_id = p_contact_id and cc.is_primary and cc.is_current
    limit 1;

    v_prev := coalesce(current_setting('gk.sync_active', true), '');
    perform set_config('gk.sync_active', '1', true);
    update public.contacts c
       set company_id = v_company_id
     where c.id = p_contact_id
       and c.company_id is distinct from v_company_id;
    perform set_config('gk.sync_active', v_prev, true);
end;
$$;

CREATE OR REPLACE FUNCTION "private"."gk_set_primary_company_contact"("p_company_contact_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    v_contact_id bigint;
    v_is_current boolean;
    v_prev text;
begin
    select contact_id, is_current into v_contact_id, v_is_current
    from public.company_contacts where id = p_company_contact_id;

    if v_contact_id is null then
        raise exception 'company_contact % not found', p_company_contact_id;
    end if;
    if not v_is_current then
        raise exception 'cannot set a non-current company_contact (%) as primary', p_company_contact_id;
    end if;

    v_prev := coalesce(current_setting('gk.sync_active', true), '');
    perform set_config('gk.sync_active', '1', true);
    update public.company_contacts
       set is_primary = false, updated_at = now()
     where contact_id = v_contact_id and is_primary and id <> p_company_contact_id;
    update public.company_contacts
       set is_primary = true, updated_at = now()
     where id = p_company_contact_id and is_primary is distinct from true;
    perform set_config('gk.sync_active', v_prev, true);

    perform private.gk_apply_primary_company(v_contact_id);
end;
$$;

CREATE OR REPLACE FUNCTION "private"."gk_set_primary_company_for_contact"("p_contact_id" bigint, "p_company_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    v_prev text;
    v_target_id bigint;
begin
    v_prev := coalesce(current_setting('gk.sync_active', true), '');
    perform set_config('gk.sync_active', '1', true);

    if p_company_id is null then
        update public.company_contacts
           set is_primary = false, updated_at = now()
         where contact_id = p_contact_id and is_primary;
    else
        select id into v_target_id
        from public.company_contacts
        where contact_id = p_contact_id and company_id = p_company_id and is_current and is_primary
        order by id limit 1;

        if v_target_id is null then
            select id into v_target_id
            from public.company_contacts
            where contact_id = p_contact_id and company_id = p_company_id and is_current
            order by id limit 1;
        end if;

        if v_target_id is null then
            insert into public.company_contacts (company_id, contact_id, role, is_primary, is_current)
            values (p_company_id, p_contact_id, 'other', false, true)
            returning id into v_target_id;
        end if;

        update public.company_contacts
           set is_primary = false, updated_at = now()
         where contact_id = p_contact_id and is_primary and id <> v_target_id;
        update public.company_contacts
           set is_primary = true, updated_at = now()
         where id = v_target_id and is_primary is distinct from true;
    end if;

    perform set_config('gk.sync_active', v_prev, true);
    perform private.gk_apply_primary_company(p_contact_id);
end;
$$;

CREATE OR REPLACE FUNCTION "private"."gk_sync_primary_company"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
    if coalesce(current_setting('gk.sync_active', true), '') = '1' then
        if tg_op = 'DELETE' then return old; else return new; end if;
    end if;

    if tg_op = 'DELETE' then
        perform private.gk_apply_primary_company(old.contact_id);
        return old;
    end if;

    perform private.gk_apply_primary_company(new.contact_id);
    if tg_op = 'UPDATE' and new.contact_id is distinct from old.contact_id then
        perform private.gk_apply_primary_company(old.contact_id);
    end if;
    return new;
end;
$$;

CREATE OR REPLACE FUNCTION "private"."gk_bridge_contact_company"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
    if coalesce(current_setting('gk.sync_active', true), '') = '1' then
        return new;
    end if;
    if tg_op = 'UPDATE' and new.company_id is not distinct from old.company_id then
        return new;
    end if;
    if tg_op = 'INSERT' and new.company_id is null then
        return new;
    end if;

    perform private.gk_set_primary_company_for_contact(new.id, new.company_id);
    return new;
end;
$$;

-- Goalkeeper schema (Phase 3): deal stage resolution + stage_id<->slug sync + module guard.
CREATE OR REPLACE FUNCTION "private"."gk_resolve_pipeline_stage"("p_brand_id" bigint, "p_slug" "text") RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    v_id bigint;
    v_alias text;
begin
    -- Direct match: works for any brand's own slugs.
    select id into v_id from public.pipeline_stages
    where brand_id = p_brand_id and slug = p_slug;
    if v_id is not null then
        return v_id;
    end if;

    -- Legacy Atomic global dealStages -> xG alias (explicit, documented).
    v_alias := case p_slug
                   when 'opportunity' then 'target'
                   when 'in-negociation' then 'decision-maker-bought-in'
                   when 'won' then 'closed-won'
                   else null
               end;
    if v_alias is null then
        return null;
    end if;

    select id into v_id from public.pipeline_stages
    where brand_id = p_brand_id and slug = v_alias;
    return v_id;
end;
$$;

CREATE OR REPLACE FUNCTION "private"."gk_sync_deal_stage"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    v_brand bigint;
    v_slug text;
    v_xg bigint;
    v_resolve_from_slug boolean := false;
    v_user_set_brand boolean := false;
begin
    -- Decide the action from INSERT vs UPDATE and which column actually changed.
    -- On a legacy Kanban move (UPDATE deals SET stage='closed-won') stage_id keeps
    -- its old non-null value, so a plain "stage_id is not null" check would wrongly
    -- ignore the slug change. We must compare against OLD.
    if tg_op = 'INSERT' then
        if new.stage_id is not null then
            v_resolve_from_slug := false;
            v_user_set_brand := new.brand_id is not null;       -- explicit brand on insert
        elsif new.stage is not null then
            v_resolve_from_slug := true;                         -- legacy slug insert
        else
            return new;
        end if;
    else  -- UPDATE
        if new.stage_id is distinct from old.stage_id then
            -- (A) stage_id changed, and (D) stage_id + stage changed together:
            -- stage_id always wins; the sent slug is ignored.
            v_resolve_from_slug := false;
            v_user_set_brand := new.brand_id is distinct from old.brand_id;
        elsif new.stage is distinct from old.stage then
            -- (B) legacy slug write only -> resolve within the (possibly new) brand.
            v_resolve_from_slug := true;
        elsif new.brand_id is distinct from old.brand_id then
            -- (C) only brand_id changed -> the current stage must belong to it.
            v_resolve_from_slug := false;
            v_user_set_brand := true;
        else
            return new;                                          -- (E) nothing relevant changed
        end if;
    end if;

    if v_resolve_from_slug then
        -- Legacy slug path: resolve within the provided brand (default xG).
        select id into v_xg from public.brands where key = 'xg';
        v_brand := coalesce(new.brand_id, v_xg);
        new.stage_id := private.gk_resolve_pipeline_stage(v_brand, new.stage);
        if new.stage_id is null then
            raise exception 'no pipeline_stage for brand_id % and legacy stage slug "%"', v_brand, new.stage;
        end if;
        select brand_id, slug into v_brand, v_slug from public.pipeline_stages where id = new.stage_id;
    else
        -- stage_id path: stage_id is the source of truth; derive brand + slug.
        select brand_id, slug into v_brand, v_slug from public.pipeline_stages where id = new.stage_id;
        if v_brand is null then
            raise exception 'deals.stage_id % does not exist', new.stage_id;
        end if;
        -- Reject only when the user explicitly set a conflicting brand_id; when only
        -- stage_id was set we DERIVE the brand from it (allows changing brand via stage).
        if v_user_set_brand and new.brand_id is not null and new.brand_id <> v_brand then
            raise exception 'stage_id % belongs to brand %, not the deal''s brand %',
                new.stage_id, v_brand, new.brand_id;
        end if;
    end if;

    new.brand_id := v_brand;
    new.stage := v_slug;

    -- Module protection: a deal that carries xG deal_modules must stay xG. This runs
    -- AFTER the final brand_id is computed, so it also catches an INDIRECT brand change
    -- caused by moving the deal to another brand's stage_id (not only UPDATE OF brand_id).
    if tg_op = 'UPDATE'
       and new.brand_id is distinct from old.brand_id
       and new.brand_id <> (select id from public.brands where key = 'xg')
       and exists (select 1 from public.deal_modules where deal_id = old.id) then
        raise exception 'cannot change deal % to brand "%": it still has xG deal_modules (remove them first)',
            old.id, (select key from public.brands where id = new.brand_id);
    end if;

    return new;
end;
$$;

CREATE OR REPLACE FUNCTION "private"."gk_check_deal_module_brand"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    v_key text;
begin
    select b.key into v_key
    from public.deals d join public.brands b on b.id = d.brand_id
    where d.id = new.deal_id;
    if v_key is distinct from 'xg' then
        raise exception 'deal_modules only apply to xG-brand deals (deal % has brand "%")',
            new.deal_id, coalesce(v_key, '<none>');
    end if;
    return new;
end;
$$;

-- Goalkeeper schema (Phase 4): activity follow-up automation (one task per activity).
CREATE OR REPLACE FUNCTION "private"."gk_handle_activity_followup"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    v_task_id bigint;
begin
    select id into v_task_id from public.tasks where activity_id = new.id;

    if new.requires_follow_up then
        if v_task_id is null then
            insert into public.tasks (contact_id, company_id, deal_id, activity_id, type, text, due_date, sales_id)
            values (new.contact_id, new.company_id, new.deal_id, new.id, 'follow-up',
                    'Follow up: ' || new.type, new.follow_up_date, new.sales_id);
        else
            update public.tasks
               set due_date = new.follow_up_date,
                   contact_id = new.contact_id,
                   company_id = new.company_id,
                   deal_id = new.deal_id
             where id = v_task_id and done_date is null;
        end if;
    else
        if v_task_id is not null then
            delete from public.tasks where id = v_task_id and done_date is null;
        end if;
    end if;
    return null;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."cleanup_note_attachments"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
    DECLARE
      payload jsonb;
      request_headers jsonb;
      auth_header text;
    BEGIN
      request_headers := coalesce(
        nullif(current_setting('request.headers', true), '')::jsonb,
        '{}'::jsonb
      );
      auth_header := request_headers ->> 'authorization';

      IF auth_header IS NULL OR auth_header = '' THEN
        IF TG_OP = 'DELETE' THEN
          RETURN OLD;
        END IF;

        RETURN NEW;
      END IF;

      payload := jsonb_build_object(
        'old_record', OLD,
        'record', NEW,
        'type', TG_OP
      );

      PERFORM net.http_post(
        url := public.get_note_attachments_function_url(),
        body := payload,
        params := '{}'::jsonb,
        headers := jsonb_build_object(
          'Content-Type',
          'application/json',
          'Authorization',
          auth_header
        ),
        timeout_milliseconds := 10000
      );

      IF TG_OP = 'DELETE' THEN
        RETURN OLD;
      END IF;

      RETURN NEW;
    END;
    $$;

CREATE OR REPLACE FUNCTION "public"."get_avatar_for_email"("email" "text") RETURNS "text"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
declare email_hash text;
declare gravatar_url text;
declare gravatar_status int8;
declare email_domain text;
declare favicon_url text;
declare domain_status int8;

begin
    -- Try to fetch a gravatar image
    email_hash = encode(extensions.digest(email, 'sha256'), 'hex');
    gravatar_url = concat('https://www.gravatar.com/avatar/', email_hash, '?d=404');

    select status from extensions.http_get(gravatar_url) into gravatar_status;

    if gravatar_status = 200 then
        return gravatar_url;
    end if;

    -- Fallback to email's domain favicon if not excluded
    email_domain = split_part(email, '@', 2);
    return get_domain_favicon(email_domain);
exception
    when others then
        return 'ERROR';
end;
$$;

CREATE OR REPLACE FUNCTION "public"."get_domain_favicon"("domain_name" "text") RETURNS "text"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
declare domain_status int8;

begin
    if exists (select from favicons_excluded_domains as fav where fav.domain = domain_name) then
        return null;
    end if;

    return concat(
        'https://favicon.show/',
        (regexp_matches(domain_name, '^(?:https?:\/\/)?(?:[^@\/\n]+@)?(?:www\.)?([^:\/?\n]+)', 'i'))[1]
    );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."get_note_attachments_function_url"() RETURNS "text"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
    DECLARE
      issuer text;
      function_url text;
    BEGIN
      issuer := coalesce(
        nullif(current_setting('request.jwt.claim.iss', true), ''),
        (
          coalesce(
            nullif(current_setting('request.jwt.claims', true), ''),
            '{}'
          )::jsonb ->> 'iss'
        )
      );
      issuer := nullif(issuer, '');
      IF issuer IS NOT NULL THEN
        issuer := rtrim(issuer, '/');
        IF right(issuer, 8) = '/auth/v1' THEN
          function_url :=
            left(issuer, length(issuer) - 8) || '/functions/v1/delete_note_attachments';

          IF function_url LIKE 'http://127.0.0.1:%' THEN
            RETURN replace(
              function_url,
              'http://127.0.0.1:',
              'http://host.docker.internal:'
            );
          END IF;

          IF function_url LIKE 'http://localhost:%' THEN
            RETURN replace(
              function_url,
              'http://localhost:',
              'http://host.docker.internal:'
            );
          END IF;

          RETURN function_url;
        END IF;
      END IF;

      RETURN 'http://host.docker.internal:54321/functions/v1/delete_note_attachments';
    END;
    $$;

CREATE OR REPLACE FUNCTION "public"."get_user_id_by_email"("email" "text") RETURNS TABLE("id" "uuid")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
BEGIN
  RETURN QUERY SELECT au.id FROM auth.users au WHERE au.email = $1;
END;
$_$;

CREATE OR REPLACE FUNCTION "public"."handle_company_saved"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
declare company_logo text;

begin
    if new.logo is not null then
        return new;
    end if;

    company_logo = get_domain_favicon(new.website);
    if company_logo is null then
        return new;
    end if;

    new.logo = concat('{"src":"', company_logo, '","title":"Company favicon"}');
    return new;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."handle_contact_note_created_or_updated"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  update public.contacts set last_seen = new.date where contacts.id = new.contact_id and contacts.last_seen < new.date;
  return new;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."handle_contact_saved"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$declare contact_avatar text;
declare emails_length int8;
declare item jsonb;

begin
    if new.avatar is not null then
        return new;
    end if;

    select coalesce(jsonb_array_length(new.email_jsonb), 0) into emails_length;

    if emails_length = 0 then
        return new;
    end if;

    for item in select jsonb_array_elements(new.email_jsonb)
    loop
        select public.get_avatar_for_email(item->>'email') into contact_avatar;
        if (contact_avatar is not null) then
            exit;
        end if;
    end loop;

    if contact_avatar is null then
        return new;
    end if;

    new.avatar = concat('{"src":"', contact_avatar, '"}');
    return new;
end;$$;

CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  sales_count int;
begin
  -- Google OAuth domain restriction (server-side, authoritative).
  -- The `hd` query param on the client only pre-filters Google's account
  -- chooser and can be bypassed, so the real boundary is enforced here:
  -- reject any google-provider sign-in whose email is not @goalkeeper.com.
  -- The email/password path is left untouched.
  if new.raw_app_meta_data ->> 'provider' = 'google'
     and new.email not like '%@goalkeeper.com' then
    raise exception 'Sign-in is restricted to @goalkeeper.com accounts';
  end if;

  select count(id) into sales_count
  from public.sales;

  insert into public.sales (first_name, last_name, email, user_id, administrator)
  values (
    coalesce(new.raw_user_meta_data ->> 'first_name', new.raw_user_meta_data -> 'custom_claims' ->> 'first_name', new.raw_user_meta_data ->> 'given_name', new.raw_user_meta_data ->> 'name', new.raw_user_meta_data ->> 'full_name', 'Pending'),
    coalesce(new.raw_user_meta_data ->> 'last_name', new.raw_user_meta_data -> 'custom_claims' ->> 'last_name', new.raw_user_meta_data ->> 'family_name', 'Pending'),
    new.email,
    new.id,
    case when sales_count > 0 then FALSE else TRUE end
  );
  return new;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."handle_update_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  update public.sales
  set
    first_name = coalesce(new.raw_user_meta_data ->> 'first_name', new.raw_user_meta_data -> 'custom_claims' ->> 'first_name', 'Pending'),
    last_name = coalesce(new.raw_user_meta_data ->> 'last_name', new.raw_user_meta_data -> 'custom_claims' ->> 'last_name', 'Pending'),
    email = new.email
  where user_id = new.id;

  return new;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."is_admin"() RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  return exists (
    select 1 from public.sales where user_id = auth.uid() and administrator = true
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."merge_contacts"("loser_id" bigint, "winner_id" bigint) RETURNS bigint
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
DECLARE
  winner_contact contacts%ROWTYPE;
  loser_contact contacts%ROWTYPE;
  deal_record RECORD;
  cc_record RECORD;
  merged_emails jsonb;
  merged_phones jsonb;
  merged_tags bigint[];
  winner_emails jsonb;
  loser_emails jsonb;
  winner_phones jsonb;
  loser_phones jsonb;
  email_map jsonb;
  phone_map jsonb;
  winner_has_primary boolean;
  prev_sync text;
BEGIN
  -- Fetch both contacts
  SELECT * INTO winner_contact FROM contacts WHERE id = winner_id;
  SELECT * INTO loser_contact FROM contacts WHERE id = loser_id;

  IF winner_contact IS NULL OR loser_contact IS NULL THEN
    RAISE EXCEPTION 'Contact not found';
  END IF;

  -- 1. Reassign tasks from loser to winner
  UPDATE tasks SET contact_id = winner_id WHERE contact_id = loser_id;

  -- 2. Reassign contact notes from loser to winner
  UPDATE contact_notes SET contact_id = winner_id WHERE contact_id = loser_id;

  -- 3. Update deals - replace loser with winner in contact_ids array
  FOR deal_record IN
    SELECT id, contact_ids
    FROM deals
    WHERE contact_ids @> ARRAY[loser_id]
  LOOP
    UPDATE deals
    SET contact_ids = (
      SELECT ARRAY(
        SELECT DISTINCT unnest(
          array_remove(deal_record.contact_ids, loser_id) || ARRAY[winner_id]
        )
      )
    )
    WHERE id = deal_record.id;
  END LOOP;

  -- 3a. Reassign activities from loser to winner (before the loser is deleted,
  -- so contact_id ON DELETE CASCADE does not destroy them).
  UPDATE activities SET contact_id = winner_id WHERE contact_id = loser_id;

  -- 3b. Reassign contact_social_profiles; drop loser duplicates of (platform, url).
  DELETE FROM contact_social_profiles l
  WHERE l.contact_id = loser_id
    AND EXISTS (
      SELECT 1 FROM contact_social_profiles w
      WHERE w.contact_id = winner_id AND w.platform = l.platform AND w.url = l.url
    );
  UPDATE contact_social_profiles SET contact_id = winner_id, updated_at = now()
  WHERE contact_id = loser_id;

  -- 3c. Reassign company_contacts with deterministic conflict resolution.
  -- Suppress the mirror sync while we shuffle rows; recompute once at the end.
  prev_sync := coalesce(current_setting('gk.sync_active', true), '');
  PERFORM set_config('gk.sync_active', '1', true);

  winner_has_primary := EXISTS (SELECT 1 FROM company_contacts WHERE contact_id = winner_id AND is_primary);

  -- If the winner already owns the primary, the loser's primary yields to it.
  IF winner_has_primary THEN
    UPDATE company_contacts SET is_primary = false, updated_at = now()
    WHERE contact_id = loser_id AND is_primary;
  END IF;

  -- Resolve ACTIVE conflicts: loser active row whose (company_id, role) collides
  -- with a winner active row. Winner values win; loser fills the gaps; notes are
  -- concatenated when both differ; the primary flag transfers only if the winner
  -- has none. Then the loser row is removed (its data was folded in).
  FOR cc_record IN
    SELECT l.* FROM company_contacts l
    WHERE l.contact_id = loser_id AND l.is_current
      AND EXISTS (
        SELECT 1 FROM company_contacts w
        WHERE w.contact_id = winner_id AND w.is_current
          AND w.company_id = l.company_id AND w.role = l.role
      )
  LOOP
    UPDATE company_contacts w SET
      title = coalesce(w.title, cc_record.title),
      relationship_status = coalesce(w.relationship_status, cc_record.relationship_status),
      instagram_status = coalesce(w.instagram_status, cc_record.instagram_status),
      linkedin_status = coalesce(w.linkedin_status, cc_record.linkedin_status),
      preferred_contact = w.preferred_contact OR cc_record.preferred_contact,
      verified_at = greatest(w.verified_at, cc_record.verified_at),
      start_date = least(w.start_date, cc_record.start_date),
      notes = CASE
                WHEN w.notes IS NULL THEN cc_record.notes
                WHEN cc_record.notes IS NULL THEN w.notes
                WHEN w.notes = cc_record.notes THEN w.notes
                ELSE w.notes || E'\n---\n' || cc_record.notes
              END,
      is_primary = w.is_primary OR (cc_record.is_primary AND NOT winner_has_primary),
      updated_at = now()
    WHERE w.contact_id = winner_id AND w.is_current
      AND w.company_id = cc_record.company_id AND w.role = cc_record.role;
    DELETE FROM company_contacts WHERE id = cc_record.id;
  END LOOP;

  -- Move the remaining loser rows (non-conflicting active + all historical).
  UPDATE company_contacts SET contact_id = winner_id, updated_at = now()
  WHERE contact_id = loser_id;

  PERFORM set_config('gk.sync_active', prev_sync, true);

  -- 3d. External IDs: keep the winner's; borrow the loser's only when the winner
  -- lacks one. Clear the loser's coda_row_id first to avoid a transient unique clash.
  IF winner_contact.coda_row_id IS NULL AND loser_contact.coda_row_id IS NOT NULL THEN
    UPDATE contacts SET coda_row_id = NULL WHERE id = loser_id;
  END IF;

  -- 4. Merge contact data

  -- Get email arrays
  winner_emails := COALESCE(winner_contact.email_jsonb, '[]'::jsonb);
  loser_emails := COALESCE(loser_contact.email_jsonb, '[]'::jsonb);

  -- Merge emails with deduplication by email address
  -- Build a map of email -> email object, then convert back to array
  email_map := '{}'::jsonb;

  -- Add winner emails to map
  IF jsonb_array_length(winner_emails) > 0 THEN
    FOR i IN 0..jsonb_array_length(winner_emails)-1 LOOP
      email_map := email_map || jsonb_build_object(
        winner_emails->i->>'email',
        winner_emails->i
      );
    END LOOP;
  END IF;

  -- Add loser emails to map (won't overwrite existing keys)
  IF jsonb_array_length(loser_emails) > 0 THEN
    FOR i IN 0..jsonb_array_length(loser_emails)-1 LOOP
      IF NOT email_map ? (loser_emails->i->>'email') THEN
        email_map := email_map || jsonb_build_object(
          loser_emails->i->>'email',
          loser_emails->i
        );
      END IF;
    END LOOP;
  END IF;

  -- Convert map back to array
  merged_emails := (SELECT jsonb_agg(value) FROM jsonb_each(email_map));
  merged_emails := COALESCE(merged_emails, '[]'::jsonb);

  -- Get phone arrays
  winner_phones := COALESCE(winner_contact.phone_jsonb, '[]'::jsonb);
  loser_phones := COALESCE(loser_contact.phone_jsonb, '[]'::jsonb);

  -- Merge phones with deduplication by number
  phone_map := '{}'::jsonb;

  -- Add winner phones to map
  IF jsonb_array_length(winner_phones) > 0 THEN
    FOR i IN 0..jsonb_array_length(winner_phones)-1 LOOP
      phone_map := phone_map || jsonb_build_object(
        winner_phones->i->>'number',
        winner_phones->i
      );
    END LOOP;
  END IF;

  -- Add loser phones to map (won't overwrite existing keys)
  IF jsonb_array_length(loser_phones) > 0 THEN
    FOR i IN 0..jsonb_array_length(loser_phones)-1 LOOP
      IF NOT phone_map ? (loser_phones->i->>'number') THEN
        phone_map := phone_map || jsonb_build_object(
          loser_phones->i->>'number',
          loser_phones->i
        );
      END IF;
    END LOOP;
  END IF;

  -- Convert map back to array
  merged_phones := (SELECT jsonb_agg(value) FROM jsonb_each(phone_map));
  merged_phones := COALESCE(merged_phones, '[]'::jsonb);

  -- Merge tags (remove duplicates)
  merged_tags := ARRAY(
    SELECT DISTINCT unnest(
      COALESCE(winner_contact.tags, ARRAY[]::bigint[]) ||
      COALESCE(loser_contact.tags, ARRAY[]::bigint[])
    )
  );

  -- 5. Update winner with merged data
  UPDATE contacts SET
    avatar = COALESCE(winner_contact.avatar, loser_contact.avatar),
    gender = COALESCE(winner_contact.gender, loser_contact.gender),
    first_name = COALESCE(winner_contact.first_name, loser_contact.first_name),
    last_name = COALESCE(winner_contact.last_name, loser_contact.last_name),
    title = COALESCE(winner_contact.title, loser_contact.title),
    company_id = COALESCE(winner_contact.company_id, loser_contact.company_id),
    email_jsonb = merged_emails,
    phone_jsonb = merged_phones,
    linkedin_url = COALESCE(winner_contact.linkedin_url, loser_contact.linkedin_url),
    background = COALESCE(winner_contact.background, loser_contact.background),
    has_newsletter = COALESCE(winner_contact.has_newsletter, loser_contact.has_newsletter),
    first_seen = LEAST(COALESCE(winner_contact.first_seen, loser_contact.first_seen), COALESCE(loser_contact.first_seen, winner_contact.first_seen)),
    last_seen = GREATEST(COALESCE(winner_contact.last_seen, loser_contact.last_seen), COALESCE(loser_contact.last_seen, winner_contact.last_seen)),
    sales_id = COALESCE(winner_contact.sales_id, loser_contact.sales_id),
    tags = merged_tags,
    coda_row_id = COALESCE(winner_contact.coda_row_id, loser_contact.coda_row_id),
    legacy_ref = COALESCE(winner_contact.legacy_ref, loser_contact.legacy_ref)
  WHERE id = winner_id;

  -- 6. Delete loser contact (its relations/profiles/activities were reassigned)
  DELETE FROM contacts WHERE id = loser_id;

  -- 7. Recompute the winner's company mirror from the merged relations
  PERFORM private.gk_apply_primary_company(winner_id);

  RETURN winner_id;
END;
$$;

CREATE OR REPLACE FUNCTION "public"."lowercase_email_jsonb"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NEW.email_jsonb IS NOT NULL THEN
    NEW.email_jsonb = COALESCE((
      SELECT jsonb_agg(
        jsonb_set(elem, '{email}', to_jsonb(LOWER(elem->>'email')))
      )
      FROM jsonb_array_elements(NEW.email_jsonb) AS elem
    ), '[]'::jsonb);
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION "public"."set_sales_id_default"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NEW.sales_id IS NULL THEN
    SELECT id INTO NEW.sales_id FROM sales WHERE user_id = auth.uid();
  END IF;
  RETURN NEW;
END;
$$;
