create extension if not exists pg_cron;
create extension if not exists pg_net;

do $outer$
begin
  if not exists (select 1 from cron.job where jobname = 'sync-voided-purchases') then
    perform cron.schedule(
      'sync-voided-purchases',
      '0 3 * * *',
      $job$
      select net.http_post(
        url := 'https://vqssjwewtjgekuyzzggo.supabase.co/functions/v1/sync-voided-purchases',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || (
            select decrypted_secret from vault.decrypted_secrets
            where name = 'service_role_key'
          )
        ),
        body := '{}'::jsonb
      );
      $job$
    );
  end if;
end
$outer$;
