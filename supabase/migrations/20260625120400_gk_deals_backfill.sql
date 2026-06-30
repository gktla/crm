-- Goalkeeper schema — Phase 3B: backfill deals.brand_id / deals.stage_id.
--
-- Brand rule (documented, explicit): every legacy Atomic deal defaults to brand
-- 'xg' — Atomic shipped a single global pipeline and xG is the primary B2B
-- pipeline. Vibecoded brand-tagged deals are imported in a later phase.
--
-- Stage rule (documented, explicit): map each legacy deals.stage slug to a real
-- xG pipeline_stage. The mapping lives in private.gk_resolve_pipeline_stage:
--   opportunity     -> target
--   proposal-sent   -> proposal-sent      (direct slug match)
--   in-negociation  -> decision-maker-bought-in
--   won             -> closed-won
-- Any other legacy slug (e.g. Atomic's 'lost' / 'delayed', which have NO xG
-- equivalent) is NOT guessed: the backfill RAISES and lists the offending
-- values for an explicit human decision. No silent/arbitrary fallback.

--
-- Resolver shared by the backfill and the 3C compat trigger.
--
create or replace function private.gk_resolve_pipeline_stage(p_brand_id bigint, p_slug text) returns bigint
    language plpgsql security definer
    set search_path to ''
    as $$
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

revoke execute on function private.gk_resolve_pipeline_stage(bigint, text) from public;

--
-- Backfill
--
update public.deals d
   set brand_id = (select id from public.brands where key = 'xg')
 where d.brand_id is null;

update public.deals d
   set stage_id = private.gk_resolve_pipeline_stage(d.brand_id, d.stage)
 where d.stage_id is null;

-- Report legacy values found + fail loudly on anything unmapped.
do $$
declare
    r record;
    v_unmapped int;
    v_values text;
begin
    for r in select stage, count(*) as c from public.deals group by stage order by stage loop
        raise notice 'gk deals backfill: legacy stage "%" -> % deal(s)', r.stage, r.c;
    end loop;

    select count(*) into v_unmapped from public.deals where brand_id is null or stage_id is null;
    if v_unmapped > 0 then
        select string_agg(distinct stage, ', ') into v_values
        from public.deals where stage_id is null;
        raise exception 'gk deals backfill: % deal(s) could not be mapped to a pipeline_stage. Unmapped legacy stage value(s): [%]. Resolve explicitly before applying 3C (e.g. add the stage to a brand or reassign these deals).', v_unmapped, v_values;
    end if;

    raise notice 'gk deals backfill: complete, all deals have brand_id + stage_id';
end $$;
