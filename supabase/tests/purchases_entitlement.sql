do $$
declare
  column_is_nullable text;
  helper_exists boolean;
  owner_policy_exists boolean;
  token_constraint_exists boolean;
begin
  select is_nullable
    into column_is_nullable
    from information_schema.columns
   where table_schema = 'public'
     and table_name = 'purchases'
     and column_name = 'gold_amount';

  if column_is_nullable is distinct from 'YES' then
    raise exception 'public.purchases.gold_amount must be nullable for entitlement rows';
  end if;

  select exists (
    select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname = 'purchased_remove_ads'
  ) into helper_exists;

  if not helper_exists then
    raise exception 'public.purchased_remove_ads() is missing';
  end if;

  select exists (
    select 1
      from pg_policies
     where schemaname = 'public'
       and tablename = 'purchases'
       and policyname = 'Owners can read their purchases'
       and cmd = 'SELECT'
  ) into owner_policy_exists;

  if not owner_policy_exists then
    raise exception 'owner purchase read policy is missing';
  end if;

  select exists (
    select 1
      from pg_constraint c
      join pg_class t on t.oid = c.conrelid
      join pg_namespace n on n.oid = t.relnamespace
     where n.nspname = 'public'
       and t.relname = 'purchases'
       and c.conname = 'purchases_purchase_token_key'
  ) into token_constraint_exists;

  if not token_constraint_exists then
    raise exception 'purchase token uniqueness constraint is missing';
  end if;
end;
$$;
