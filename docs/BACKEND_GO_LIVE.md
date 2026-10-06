# Backend go-live — step by step

Everything in code is done and deployed. What is left is Google-side
configuration, which needs your account. Roughly 45 minutes.

Values you will paste repeatedly:

| Thing | Value |
| --- | --- |
| Package name | `com.shardfall.shardfall` |
| Upload key SHA-1 | `B6:94:27:07:FC:09:DD:E5:75:CE:38:4C:5A:16:89:CB:E8:26:CA:59` |
| Supabase project ref | `vqssjwewtjgekuyzzggo` |

**Two independent tracks.** Steps 1–3 make paid Gold verifiable. Steps 4–7 make
accounts work so Gold survives a reinstall. You can do either first, and the app
keeps running (offline) until both are done.

---

## Track A — receipt verification

### Step 1 · Prepare Google Cloud API access

1. Create or choose a Google Cloud project for Shardfall.
2. Enable **Google Play Android Developer API** in that project.
3. The current Play Developer API flow does not require linking the developer
   account to the Cloud project; access is granted by adding the service
   account as a Play Console user.

### Step 2 · Service account with Play permission

1. Open <https://console.cloud.google.com/iam-admin/serviceaccounts>, pick the
   project you just linked, **Create service account**. Name it e.g.
   `shardfall-billing`. No roles needed on the Google Cloud side.
2. Open the account → **Keys → Add key → Create new key → JSON**. It downloads.
3. Back in <https://play.google.com/console> → **Users and permissions →
   Invite new users**, paste the service account email
   (`…@….iam.gserviceaccount.com`).
4. Grant the service account these two **account permissions**:
   **View financial data, orders, and cancellation survey responses** and
   **Manage orders and subscriptions**. Also grant app access to Shardfall.
   Google’s Billing APIs can answer `401` until both financial and order access
   are present.

> Permissions can take a few hours to propagate. Until then the app returns
> `503` internally and simply retries later — players still get their Gold
> immediately, it just is not durable yet.

### Step 3 · Give Supabase the credentials

Open <https://supabase.com/dashboard/project/vqssjwewtjgekuyzzggo/functions/secrets>
and add these secrets:

| Name | Value |
| --- | --- |
| `GOOGLE_SERVICE_ACCOUNT_JSON` | the whole downloaded JSON file, pasted as-is |
| `ANDROID_PACKAGE_NAME` | `com.shardfall.shardfall` |
| `SHARDFALL_SERVICE_ROLE_KEY` | the Supabase legacy service-role key, used only by the refund scheduler |

Track A is now live. Nothing to rebuild.

---

## Track B — Google Sign-In

### Step 4 · OAuth consent screen

In Google Auth Platform → **Branding**, use app name `Shardfall`, support email
`fajar.mreza@gmail.com`, and the public privacy policy URL
<https://fareza777.github.io/shardfall/privacy.html>. Terms of service are
optional. Add `fareza777.github.io` to Authorized domains if Google reports it
missing. In **Audience**, set Publishing status to **In production** after the
branding is saved.

### Step 5 · OAuth client IDs

The `Shardfall Web` client and Android upload-key client already exist in
project `Shardfall Billing`. The Web client ID is
`729072124482-a5mn4a6alj6ielikioqrjgfp1v1mvg66.apps.googleusercontent.com`;
use it as `serverClientId` and keep its secret only in Supabase.

Also create Android clients for all three Play signing certificates (same
package `com.shardfall.shardfall`). Hybrid signing uses three fingerprints;
register all of them, not just the upload certificate:

| Certificate | SHA-1 |
| --- | --- |
| `deployment_cert.der` | `4B:14:A8:CB:50:EE:A5:3F:E5:3B:17:4C:7F:01:0D:F8:0C:15:B4:75` |
| `hybrid_classical_cert.der` | `1B:84:81:76:BB:19:5C:F1:D0:76:09:27:A8:F9:46:96:A9:F7:BD:57` |
| `hybrid_pqc_cert.der` | `08:80:0F:3F:F8:21:BF:85:B0:4E:A3:89:54:C5:50:8D:11:AA:FC:A1` |

Download these from Play Console → **Protected with Play → Manage Play app
signing → Download certificates**. The existing `Shardfall Android` client
uses the upload-key fingerprint and should remain for sideloaded APKs.

### Step 6 · Enable Google in Supabase

Open <https://supabase.com/dashboard/project/vqssjwewtjgekuyzzggo/auth/providers?provider=Google>:

1. Toggle **Enable Sign in with Google**.
2. **Client IDs** — comma-separated, **Web first**: Web client ID, upload-key
   Android client ID, then the Android client IDs for `deployment_cert.der`,
   `hybrid_classical_cert.der`, and `hybrid_pqc_cert.der`.
3. **Client Secret** — keep the existing Web client secret.
4. Save.

Leave **Skip nonce check** off. It is only needed for iOS.

### Step 7 · Rebuild with production defaults

```bash
export ANDROID_HOME=/c/Android/Sdk
cd "C:/TCG Claude/app"
flutter build appbundle --release
flutter build apk --release
```

The production Web client ID is now the source default, so omit the
`--dart-define` flag for production. Use that override only when intentionally
building against a separate staging Web client ID.

---

## Step 8 · Schedule the refund job

Open <https://supabase.com/dashboard/project/vqssjwewtjgekuyzzggo/sql/new>.
Grab your service role key first from
<https://supabase.com/dashboard/project/vqssjwewtjgekuyzzggo/settings/api-keys/>
— it bypasses every security rule, so never put it in the app.

```sql
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Run this once. Store the same key in the Edge Function secret
-- SHARDFALL_SERVICE_ROLE_KEY; never put it in the app.
select vault.create_secret(
  '<service-role-key>',
  'service_role_key',
  'Used by the daily voided-purchase synchronization job'
);

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
```

Confirm with `select * from cron.job;`.

---

## Step 9 · Verify it end to end

On a real device signed into a Play **closed-test** account — Play Billing does
not work in an emulator.

| # | Do this | Expect |
| --- | --- | --- |
| 1 | Settings → **Sign in with Google** | a row appears in [profiles](https://supabase.com/dashboard/project/vqssjwewtjgekuyzzggo/editor) |
| 2 | Buy 500 Gold | a row in `purchases` with a real `order_id`, `state = granted` |
| 3 | Uninstall, reinstall, sign in | Gold comes back; a "Gold restored" message shows |
| 4 | Refund the order in Play Console, wait for the 03:00 job | `state` flips to `refunded`, Gold disappears on next sign-in |

If step 2 records nothing, read the function log:
<https://supabase.com/dashboard/project/vqssjwewtjgekuyzzggo/functions/verify-purchase/logs>

Common causes, in order of likelihood: the Play permission from step 2.4 has not
propagated yet; `ANDROID_PACKAGE_NAME` has a typo; the JSON secret got truncated
when pasted.

---

## Still not covered by any of this

- **Play Console paperwork** — Data safety form, content rating, hosted privacy
  policy, and for a new personal developer account, 12 testers for 14 days
  before you can request production access.
- **Client-side economy** — Gold earned in-game is still simulated on the
  device, so a rooted phone can still edit it. Only *paid* Gold is protected.
  Closing that means moving the economy onto the server, which is a separate
  project and mostly matters once ranked PvP exists.
