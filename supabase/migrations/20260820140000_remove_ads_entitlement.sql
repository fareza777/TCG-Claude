-- Extend the Google-verified purchase ledger with permanent entitlements.
-- Existing Gold rows remain unchanged; Remove Ads rows carry an entitlement
-- identifier instead of a Gold amount.

alter table public.purchases
  drop constraint purchases_gold_amount_check;

alter table public.purchases
  alter column gold_amount drop not null;

alter table public.purchases
  add column entitlement_id text;

alter table public.purchases
  add constraint purchases_value_shape_check check (
    (product_id = 'gold_500'
      and gold_amount is not null
      and gold_amount > 0
      and entitlement_id is null)
    or
    (product_id = 'remove_ads'
      and gold_amount is null
      and entitlement_id = 'remove_ads')
  );

comment on column public.purchases.entitlement_id is
  'Permanent entitlement granted by a Google-verified one-time product.';

create index purchases_entitlement_state_idx
  on public.purchases (user_id, entitlement_id, state);

create or replace function public.purchased_gold_total()
returns integer
language sql
stable
security invoker
set search_path = ''
as $$
  select coalesce(sum(gold_amount), 0)::integer
  from public.purchases
  where user_id = (select auth.uid())
    and product_id = 'gold_500'
    and state = 'granted';
$$;

comment on function public.purchased_gold_total is
  'Total Gold the signed-in player has actually paid for. Security invoker, so RLS keeps it scoped to the caller.';

create or replace function public.purchased_remove_ads()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from public.purchases
    where user_id = (select auth.uid())
      and product_id = 'remove_ads'
      and entitlement_id = 'remove_ads'
      and state = 'granted'
  );
$$;

comment on function public.purchased_remove_ads is
  'Whether the signed-in player owns an active Google-verified Remove Ads purchase.';
