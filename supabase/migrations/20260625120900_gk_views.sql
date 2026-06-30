-- Goalkeeper schema — Phase 8: views.
--
-- Extends activity_log with a UNION of activities (appends an `activity` json
-- column so existing leading columns are preserved under CREATE OR REPLACE), and
-- adds current_squad (Decision C: "physically at the club now" derived from
-- player_org_assignments). companies_summary / contacts_summary already expose
-- their new columns (migrations 2 and 3), so they are not re-touched here.
-- Depends on migrations 5 (activities) and 6 (player_org_assignments).

create or replace view public.activity_log with (security_invoker = on) as
select
    ('company.' || c.id || '.created') as id,
    'company.created' as type,
    c.created_at as date,
    c.id as company_id,
    c.sales_id,
    to_json(c.*) as company,
    null::json as contact,
    null::json as deal,
    null::json as contact_note,
    null::json as deal_note,
    null::json as activity
from public.companies c
union all
select
    ('contact.' || co.id || '.created'),
    'contact.created',
    co.first_seen,
    co.company_id,
    co.sales_id,
    null::json,
    to_json(co.*),
    null::json,
    null::json,
    null::json,
    null::json
from public.contacts co
union all
select
    ('contactNote.' || cn.id || '.created'),
    'contactNote.created',
    cn.date,
    co.company_id,
    cn.sales_id,
    null::json,
    null::json,
    null::json,
    to_json(cn.*),
    null::json,
    null::json
from public.contact_notes cn
    left join public.contacts co on co.id = cn.contact_id
union all
select
    ('deal.' || d.id || '.created'),
    'deal.created',
    d.created_at,
    d.company_id,
    d.sales_id,
    null::json,
    null::json,
    to_json(d.*),
    null::json,
    null::json,
    null::json
from public.deals d
union all
select
    ('dealNote.' || dn.id || '.created'),
    'dealNote.created',
    dn.date,
    d.company_id,
    dn.sales_id,
    null::json,
    null::json,
    null::json,
    null::json,
    to_json(dn.*),
    null::json
from public.deal_notes dn
    left join public.deals d on d.id = dn.deal_id
union all
select
    ('activity.' || a.id || '.created'),
    'activity.created',
    a.occurred_at,
    a.company_id,
    a.sales_id,
    null::json,
    null::json,
    null::json,
    null::json,
    null::json,
    to_json(a.*)
from public.activities a;

-- current_squad (Decision C): "physically at the club now" =
-- (owned AND NOT loaned_out) OR loaned_in. Raw player_org_assignments rows stay
-- faithful to Coda; this view gives the coherent read.
create or replace view public.current_squad with (security_invoker = on) as
select distinct
    poa.player_id,
    poa.org_id
from public.player_org_assignments poa
where poa.is_current
  and (
    poa.relationship_type = 'loaned_in'
    or (
      poa.relationship_type = 'owned'
      and not exists (
        select 1 from public.player_org_assignments lo
        where lo.player_id = poa.player_id
          and lo.org_id = poa.org_id
          and lo.relationship_type = 'loaned_out'
          and lo.is_current
      )
    )
  );

grant all on table public.current_squad to anon;
grant all on table public.current_squad to authenticated;
grant all on table public.current_squad to service_role;
