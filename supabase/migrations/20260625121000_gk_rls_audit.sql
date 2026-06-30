-- Goalkeeper schema — Phase 9: RLS audit (verification only; no schema objects).
--
-- Final guard: every base table in the public schema must have row level security
-- enabled (Decision 10). Fails the migration explicitly if any table is missing
-- it, so a forgotten `enable row level security` can never reach an environment.
-- Creates nothing, so there is no declarative-schema counterpart.
--
-- RBAC placeholder: launch is single-tenant (RLS `to authenticated using(true)`).
-- At M6 the CRM adopts its OWN simple roles model (the GPS 4-layer
-- roles/entitlements pattern is the template, not a dependency — see doc 07).
-- No roles/entitlements tables are created yet.

do $$
declare
    v_missing text;
begin
    select string_agg(c.relname, ', ' order by c.relname) into v_missing
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and not c.relrowsecurity;

    if v_missing is not null then
        raise exception 'RLS audit failed — public base tables without row level security: %', v_missing;
    end if;

    raise notice 'RLS audit: all public base tables have row level security enabled';
end;
$$;
