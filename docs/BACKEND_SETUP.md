# Backend setup — Shardfall

Supabase project **Shardfall** (`vqssjwewtjgekuyzzggo`), region `ap-southeast-1`.

| Piece | Where | Status |
| --- | --- | --- |
| `public.profiles`, `public.purchases`, RLS, triggers | `supabase/migrations/` | applied |
| `verify-purchase` Edge Function | `supabase/functions/verify-purchase/` | deployed, `verify_jwt = true` |
| `sync-voided-purchases` Edge Function | `supabase/functions/sync-voided-purchases/` | deployed; **needs a schedule** |
| Google service account for receipt checks | Play Console + Google Cloud | **you must create** |
| Google Sign-In OAuth clients | Google Cloud + Supabase Auth | **you must create** |

Until the two "you must create" rows are done, the app still runs — it just
stays fully offline, exactly as it did before this change. Nothing is gated on
the backend.

## What the design does and does not protect

**Protected.** Paid Gold is recorded server-side from a receipt Google itself
confirms, keyed on the purchase token. That survives reinstall and device
changes, cannot be replayed onto a second account, and gives you a row to claw
back on a refund.

**Disclosed.** Paid Gold buys randomised Shard Packs, which Play policy treats
as loot boxes, so the pull rates are shown before purchase via **View pack odds**
on the Shard Pack screen. The numbers come from
[`pack_odds.dart`](../app/lib/packs/pack_odds.dart), the same constants the pack
generator draws from, so the disclosure cannot drift from the behaviour.

**Not protected.** The single-player economy is still simulated on the device,
so `profiles.save_data` is client-asserted — a rooted device can still edit its
own earned Gold and collection. Closing that means moving the economy itself
server-side, which is a much larger change and only really pays off once ranked
PvP exists. The schema is arranged so that work is additive, not a rewrite.

## 1. Service account for receipt verification

1. Play Console → **Setup → API access** → link a Google Cloud project.
2. In Google Cloud → **IAM & Admin → Service Accounts** → create one.
3. Back in Play Console → **Users and permissions** → invite that service
   account and grant **View financial data, orders, and cancellation survey
   responses**. Without this permission the API returns 401.
4. Create a JSON key for the service account and download it.
5. Supabase Dashboard → **Edge Functions → Secrets**, add:

   | Secret | Value |
   | --- | --- |
   | `GOOGLE_SERVICE_ACCOUNT_JSON` | the entire downloaded JSON, pasted as one line |
   | `ANDROID_PACKAGE_NAME` | `com.shardfall.shardfall` |

Permissions can take a few hours to propagate on Google's side. Until then
verification returns `503 verification_unavailable`, which the client treats as
"retry later" — players still get their Gold immediately.

## 2. Google Sign-In

In Google Auth Platform → **Clients**, use the existing Web client for
`serverClientId` and the existing Android upload-key client for sideloaded
builds. This Shardfall Play app uses quantum-ready hybrid signing, so add an
Android OAuth client for each of its three Play signing certificates as well
(package `com.shardfall.shardfall`):

| Play certificate | SHA-1 |
| --- | --- |
| `deployment_cert.der` | `4B:14:A8:CB:50:EE:A5:3F:E5:3B:17:4C:7F:01:0D:F8:0C:15:B4:75` |
| `hybrid_classical_cert.der` | `1B:84:81:76:BB:19:5C:F1:D0:76:09:27:A8:F9:46:96:A9:F7:BD:57` |
| `hybrid_pqc_cert.der` | `08:80:0F:3F:F8:21:BF:85:B0:4E:A3:89:54:C5:50:8D:11:AA:FC:A1` |

The three certificates are available from Play Console → **Protected with
Play → Manage Play app signing → Download certificates**. Keep the upload-key
Android client too; Play-distributed installs use the three Play signing
certificates, not the upload key.

Then Supabase Dashboard → **Authentication → Providers → Google**:

- keep **Enable Sign in with Google** on and **Skip nonce checks** off,
- put the Web client ID first in **Client IDs**, followed by the upload-key
  Android client ID and all three Play signing Android client IDs,
- keep the Web client secret in the provider's secret field.

## 3. Building the app

The Supabase URL, publishable key, and production Google **Web** client ID are
defaults in [`app/lib/services/backend_config.dart`](../app/lib/services/backend_config.dart).
They are public client configuration; RLS is the security boundary. Production
builds no longer need a Google client-ID flag. For a staging project only, you
can override the Web client ID at build time:

```bash
flutter build appbundle --dart-define=GOOGLE_SERVER_CLIENT_ID=<staging-web-client-id>.apps.googleusercontent.com
```

The ID must be a Web application OAuth client ID; Android client IDs are not a
substitute for the token audience checked by Supabase.

## 4. Verifying it end to end

Order matters — do these on a real device signed into a Play **closed-test**
account, since Play Billing does not work in an emulator without a test track.

1. Sign in from **Settings → Sign in with Google**. A row should appear in
   `public.profiles`.
2. Buy 500 Gold. A row should appear in `public.purchases` with a real
   `order_id`, and `save.unverifiedPurchases` should end up empty.
3. Uninstall, reinstall, sign in again. The Gold should come back, and buying
   again should still be possible (the consumable was consumed).

Check the function's own log if step 2 records nothing:

```bash
npx supabase functions logs verify-purchase --project-ref vqssjwewtjgekuyzzggo
```

## 5. Scheduling the refund job

`sync-voided-purchases` asks Google which purchases were refunded or charged
back and flips those rows to `state = 'refunded'`. The app takes the Gold back
on its next sync, flooring the balance at zero.

Nothing calls it yet — it needs a daily schedule. This step is left to you
because it means putting the **service role key** into the database, and that
key must not pass through anyone else's hands. Run this in the SQL editor:

```sql
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Paste your own service role key (Dashboard → Project Settings → API keys).
select vault.create_secret('<service-role-key>', 'service_role_key');

select cron.schedule(
  'sync-voided-purchases',
  '0 3 * * *',
  $$
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
  $$
);
```

The function rejects anything that is not the service role key with `403`, so a
player's token cannot trigger it. Google keeps voided purchases queryable for 30
days and the job looks back that far by default, so missing a few nights is
harmless.

## Still open before production rollout

- Play Console: Data safety form, content rating, a publicly hosted privacy
  policy, and — for a new personal developer account — 12 testers for 14 days
  before production access can be requested.

## 6. Realtime PvP closed-test staging

PvP is an additive, non-ranked closed-test service. The rules reducer runs in
the Dart service; Supabase stores the durable match/runtime boundary and pairs
players through the authenticated queue RPC. The Flutter client receives only
the viewer-safe projection, so an opponent's hand, deck order, and server seed
never cross the service boundary.

Build the backend image from the repository root with
[`backend/pvp_server/Dockerfile`](../backend/pvp_server/Dockerfile). The image
expects these runtime values, supplied by Cloud Run/Secret Manager rather than
the image or the app:

| Variable | Purpose |
| --- | --- |
| `SUPABASE_URL` | Supabase project URL |
| `SHARDFALL_SERVICE_ROLE_KEY` | server-only PostgREST/RPC access |
| `PVP_INTERNAL_AUTH_SECRET` | Edge Function → Dart service authentication |
| `SHARDFALL_CARD_DATA` | defaults to the image's bundled Set 1 data |
| `PORT` | defaults to Cloud Run's `8080` |

The Edge Functions additionally need `PVP_SERVER_URL` and the same internal
secret. Deploy this only to the staging/closed-test service, then apply the
PvP migration and run the two-account smoke test in
[`PVP_CLOSED_TEST_CHECKLIST.md`](PVP_CLOSED_TEST_CHECKLIST.md). Do not put the
service-role key or internal secret in `--dart-define` values.

The exact SQL migration and functions are ready in this checkout, but applying
them and deploying Cloud Run are external mutations. They require an
authenticated Supabase CLI/project session and a Cloud Run project/service
with permission to set secrets.

## Scheduled jobs

Two `pg_cron` jobs run against this project. Check them with
`select jobname, schedule, active from cron.job;`.

| Job | Schedule | Purpose |
| --- | --- | --- |
| `sync-voided-purchases` | `0 3 * * *` | Asks Google which purchases were refunded and flips those rows to `refunded`. |
| `pvp-reap-stale-matches` | `* * * * *` | Cancels matches stuck in `starting` whose engine never initialized, and releases both players from the queue. |

The reaper is a safety net, not the main path: `pvp-queue` calls
`pvp_abandon_match` directly when initialization fails. Without one of the two,
a failed or unreachable PvP service locks both players out of PvP permanently,
because `pvp_join_queue` refuses to queue anyone holding a `starting` match.

`pg_cron` only reports whether the SQL ran. For the HTTP job, the real outcome
is in `net._http_response` — check `status_code` there, not `cron.job_run_details`.

## Card catalog

`public.pvp_card_catalog` mirrors card ids and rarities so queued PvP decks can
be validated (unknown cards, copy limits, Wellspring cap) before a match is
created. It is **not** kept in sync automatically: regenerate the seed in
`supabase/migrations/20260804180000_pvp_integrity_fixes.sql` from
`app/assets/data/set01.json` whenever the card set changes, or newly printed
cards will be rejected as `unknown_card`.

Ownership is deliberately not enforced. The collection still lives in
client-asserted `profiles.save_data`, so checking against it would be theatre.

## Building

`ANDROID_HOME` is not set in the shell, which makes `flutter doctor` claim
there is no Android SDK. There is — at `C:\Android\Sdk`. Export it first:

```bash
export ANDROID_HOME=/c/Android/Sdk
export ANDROID_SDK_ROOT=/c/Android/Sdk
flutter build appbundle --release
flutter build apk --release
```

Release signing reads `app/android/key.properties` (alias `shardfall-upload`,
gitignored). Confirm a build carries the upload key rather than the debug key:

```bash
$ANDROID_HOME/build-tools/36.1.0/apksigner.bat verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

Expect `CN=SHARDFALL, OU=F7 Developer`. The upload key's SHA-1 is
`B6:94:27:07:FC:09:DD:E5:75:CE:38:4C:5A:16:89:CB:E8:26:CA:59` — add it to the
Android OAuth client from step 2, alongside the Play App Signing SHA-1.
