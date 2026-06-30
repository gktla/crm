-- Goalkeeper schema — Phase 3C: deals FKs, composite brand<->stage FK,
-- stage_id<->stage compat trigger, NOT NULL, and deal_modules brand guard.
--
-- stage_id is the source of truth. deals.stage (slug) is kept for Atomic Kanban
-- compatibility and synced from stage_id by a BEFORE trigger. The trigger also
-- accepts legacy slug writes (Atomic frontend still writes deals.stage) and
-- resolves them to stage_id, defaulting the brand to xG.

--
-- 1. Compat trigger: keep deals.stage_id and deals.stage consistent.
--    BEFORE trigger that only mutates NEW -> no recursion, no extra writes.
--
create or replace function private.gk_sync_deal_stage() returns trigger
    language plpgsql security definer
    set search_path to ''
    as $$
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

revoke execute on function private.gk_sync_deal_stage() from public;

create trigger gk_deals_stage_sync
    before insert or update of stage_id, stage, brand_id on public.deals
    for each row execute function private.gk_sync_deal_stage();

--
-- 2. Foreign keys: simple brand FK + composite (brand_id, stage_id) -> pipeline_stages
--    (Decision 2: the stage always belongs to the deal's brand).
--
alter table public.deals
    add constraint deals_brand_id_fkey foreign key (brand_id) references public.brands(id);
alter table public.deals
    add constraint deals_brand_stage_fkey foreign key (brand_id, stage_id)
        references public.pipeline_stages(brand_id, id);

--
-- 3. NOT NULL only after confirming the backfill is complete.
--
do $$
declare
    v_bad int;
begin
    select count(*) into v_bad from public.deals where brand_id is null or stage_id is null;
    if v_bad > 0 then
        raise exception 'cannot set NOT NULL: % deal(s) still have null brand_id/stage_id (run/verify 3B backfill)', v_bad;
    end if;
end $$;

alter table public.deals alter column brand_id set not null;
alter table public.deals alter column stage_id set not null;

--
-- 4. deal_modules brand guard: modules only apply to xG-brand deals.
--
create or replace function private.gk_check_deal_module_brand() returns trigger
    language plpgsql security definer
    set search_path to ''
    as $$
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

revoke execute on function private.gk_check_deal_module_brand() from public;

create trigger gk_deal_modules_brand_guard
    before insert or update on public.deal_modules
    for each row execute function private.gk_check_deal_module_brand();
