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

In Google Cloud → **APIs & Services → Credentials**, create **two** OAuth
client IDs:

- **Android** — package `com.shardfall.shardfall`, plus the SHA-1 fingerprint.
  Use the SHA-1 from Play Console → **Test and release → App integrity → App
  signing key certificate**, not just your local upload key. Play re-signs the
  app, so a build downloaded from Play carries the Play key.
- **Web** — this one's client ID is what the app and Supabase both need.

Then Supabase Dashboard → **Authentication → Providers → Google**:

- enable it,
- paste the **Web** client ID and its client secret,
- add the **Android** client ID to **Authorized Client IDs**.

## 3. Building the app

The Supabase URL and publishable key are already the defaults in
[`app/lib/services/backend_config.dart`](../app/lib/services/backend_config.dart)
— they are meant to ship in the client, since RLS is the real boundary. Only
the Google client ID has to be supplied at build time:

```bash
flutter build appbundle --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
```

Omit it and the sign-in entry disappears from Settings; the game runs offline.

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
