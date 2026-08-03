-- handle_new_user() is a SECURITY DEFINER trigger function, but PostgREST also
-- exposes every public function as an RPC endpoint. Postgres checks EXECUTE
-- only when the trigger is created, not when it fires, so revoking here closes
-- /rest/v1/rpc/handle_new_user without affecting the trigger.
revoke execute on function public.handle_new_user() from anon, authenticated, public;
revoke execute on function public.touch_updated_at() from anon, authenticated, public;
revoke execute on function public.guard_save_version() from anon, authenticated, public;
