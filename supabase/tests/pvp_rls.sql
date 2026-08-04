-- PvP schema contract tests. Run these in a Supabase SQL test session with
-- pgTAP enabled, or translate the same assertions into the dashboard RLS
-- Tester for two authenticated users and an anonymous role.
begin;

select plan(16);

select has_table('public', 'pvp_queue', 'queue table exists');
select has_table('public', 'pvp_matches', 'match metadata table exists');
select has_table('public', 'pvp_match_runtime', 'server runtime table exists');
select has_table('public', 'pvp_match_players', 'private projection table exists');
select has_table('public', 'pvp_commands', 'command ledger exists');
select has_table('public', 'pvp_events', 'event stream exists');

select has_function(
  'public',
  'pvp_join_queue(jsonb)',
  'queue join RPC exists'
);
select has_function(
  'public',
  'pvp_leave_queue()',
  'queue leave RPC exists'
);
select has_function(
  'public',
  'pvp_commit_transition(uuid,bigint,text,jsonb,jsonb,jsonb,uuid,text,jsonb,jsonb)',
  'server transition RPC exists'
);
select has_function(
  'public',
  'pvp_initialize_match(uuid,text,text,text,jsonb,jsonb,jsonb,bigint,timestamptz)',
  'server initializer RPC exists'
);

select policies_are('public', 'pvp_queue', 1, 'queue has scoped read policy');
select policies_are('public', 'pvp_matches', 1, 'matches have member read policy');
select policies_are('public', 'pvp_match_players', 1, 'private state has owner read policy');
select policies_are('public', 'pvp_commands', 1, 'commands have actor read policy');
select policies_are('public', 'pvp_events', 1, 'events have member read policy');

select ok(
  not exists (
    select 1
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'pvp_match_runtime'
      and grantee in ('anon', 'authenticated')
      and privilege_type in ('SELECT', 'INSERT', 'UPDATE', 'DELETE')
  ),
  'runtime state is not exposed to client roles'
);

select * from finish();
rollback;
