# Deploying the PvP server to Cloud Run

## Current deployment

| | |
| --- | --- |
| GCP project | `shardfall-billing` (729072124482) |
| Service | `shardfall-pvp-closed`, region `asia-southeast1` |
| URL | `https://shardfall-pvp-closed-dijw7q6vdq-as.a.run.app` |
| Image | `asia-southeast1-docker.pkg.dev/shardfall-billing/shardfall/pvp-server:v1` |
| Secrets | `shardfall-pvp-internal-auth`, `shardfall-supabase-service-key` |
| Scaling | min 0, max 3, 512Mi / 1 vCPU |

An earlier `europe-west1` copy of the same service still exists. It works, but a
single Postgres round trip measured ~0.84–1.06 s from there against ~0.32–0.38 s
from `asia-southeast1`, because the database is in Singapore and a command makes
several sequential queries. Delete the European service once the Singapore one
is confirmed end-to-end:

```bash
gcloud run services delete shardfall-pvp-closed --region=europe-west1
```

The steps below are the full recipe, kept for rebuilding or moving the service.

---


The authoritative PvP service is a stateless Dart HTTP server. All match state
lives in Postgres, and `pvp_commit_transition` rejects stale writes with a
revision check, so the service can scale to zero and run multiple instances
safely.

Target: **Cloud Run, `asia-southeast1` (Singapore)** — the same region as the
Supabase project. That matters more than it looks: the service makes several
Postgres round trips per command, so a "free" US region would push every player
action across the Pacific repeatedly. Cloud Run's free tier is US-only, but with
scale-to-zero and closed-test traffic this costs cents per month.

**Before you start:** Cloud Run requires billing enabled on the Google Cloud
project. Use the same project you linked to Play Console for receipt
verification. Cost will be near zero, but a payment method is required.

Values used below:

| Thing | Value |
| --- | --- |
| Supabase URL | `https://vqssjwewtjgekuyzzggo.supabase.co` |
| Region | `asia-southeast1` |
| Service name | `shardfall-pvp` |

```bash
export PROJECT_ID=<your-gcp-project-id>
export REGION=asia-southeast1
gcloud config set project "$PROJECT_ID"
```

## Step 1 · Enable the APIs

```bash
gcloud services enable run.googleapis.com cloudbuild.googleapis.com \
  artifactregistry.googleapis.com secretmanager.googleapis.com
```

## Step 2 · Create the image repository

```bash
gcloud artifacts repositories create shardfall \
  --repository-format=docker --location="$REGION"
```

## Step 3 · Store the secrets

The service needs two: a shared secret that proves a request came from your
Supabase Edge Functions, and the Supabase service role key. Neither belongs in
a plain environment variable, and neither ever goes into the Flutter app.

```bash
# A strong random shared secret. Keep the printed value; Step 7 needs it.
openssl rand -base64 32 | tr -d '\n' > /tmp/pvp-secret
cat /tmp/pvp-secret; echo

gcloud secrets create pvp-internal-secret --data-file=/tmp/pvp-secret
rm /tmp/pvp-secret

# Service role key: Supabase Dashboard -> Project Settings -> API keys.
# Paste it at the prompt, then press Ctrl-D.
gcloud secrets create shardfall-service-role-key --data-file=-
```

Cloud Run's default service account has to be allowed to read them:

```bash
export PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
export RUNTIME_SA="$PROJECT_NUMBER-compute@developer.gserviceaccount.com"

for s in pvp-internal-secret shardfall-service-role-key; do
  gcloud secrets add-iam-policy-binding "$s" \
    --member="serviceAccount:$RUNTIME_SA" \
    --role=roles/secretmanager.secretAccessor
done
```

## Step 4 · Build the image

Run this from the repository root — the build context must be the root, which
is what [`cloudbuild.yaml`](../backend/pvp_server/cloudbuild.yaml) handles.

```bash
export IMAGE="$REGION-docker.pkg.dev/$PROJECT_ID/shardfall/pvp-server:v1"

gcloud builds submit . \
  --config=backend/pvp_server/cloudbuild.yaml \
  --substitutions=_IMAGE="$IMAGE"
```

## Step 5 · Deploy

```bash
gcloud run deploy shardfall-pvp \
  --image="$IMAGE" \
  --region="$REGION" \
  --allow-unauthenticated \
  --min-instances=0 \
  --max-instances=3 \
  --memory=512Mi \
  --cpu=1 \
  --timeout=60 \
  --set-env-vars=SUPABASE_URL=https://vqssjwewtjgekuyzzggo.supabase.co \
  --set-secrets=PVP_INTERNAL_AUTH_SECRET=pvp-internal-secret:latest,SHARDFALL_SERVICE_ROLE_KEY=shardfall-service-role-key:latest
```

On `--allow-unauthenticated`: Supabase Edge Functions cannot mint Google IAM
tokens, so the service has to accept requests from the internet. It is not
open — every `/internal/v1/**` route requires the `X-Pvp-Internal-Secret`
header and compares it in constant time. That shared secret is the whole
boundary, so use the random one from Step 3 and never a guessable string.
`/health` is deliberately unauthenticated and exposes only version strings.

## Step 6 · Check it is alive

```bash
export PVP_URL=$(gcloud run services describe shardfall-pvp \
  --region="$REGION" --format='value(status.url)')
echo "$PVP_URL"

curl -s "$PVP_URL/health"          # {"service":...,"ok":true,"engineVersion":...}
curl -s -o /dev/null -w '%{http_code}\n' \
  -X POST "$PVP_URL/internal/v1/matches/00000000-0000-0000-0000-000000000000/commands"
```

The first must return `ok:true`. The second must return **401** — if it returns
anything else, the secret is not wired up and the service is exposed.

## Step 7 · Point Supabase at it

Open <https://supabase.com/dashboard/project/vqssjwewtjgekuyzzggo/functions/secrets>
and set both:

| Secret | Value |
| --- | --- |
| `PVP_SERVER_URL` | the `$PVP_URL` from Step 6, no trailing slash |
| `PVP_INTERNAL_AUTH_SECRET` | the exact string from Step 3 |

Both already exist with placeholder values, so **update** them rather than
adding new ones. If the secret does not match byte-for-byte, every match
initialization fails with 401 and players get `match_initialization_unavailable`
— they will not be locked out, but no match will ever start.

Edge Functions pick new secrets up on their next cold start; redeploy if you
want it immediate.

## Step 8 · Two-account smoke test

On two real devices with two Google accounts, on a build made with sign-in and
PvP enabled:

```bash
flutter build apk --release \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
```

| # | Do this | Expect |
| --- | --- | --- |
| 1 | Both accounts sign in | two rows in `profiles` |
| 2 | Player 1 queues | `pvp_queue` shows `queued` |
| 3 | Player 2 queues | both get the same match ID; `pvp_matches` row goes `starting` |
| 4 | Play a turn each | `pvp_commands` rows with `result = accepted`, `revision` climbing |
| 5 | Kill one app mid-match, reopen | the match resumes from the server projection |

## When something breaks

Cold start is roughly 1–2 seconds because the image is a compiled binary on
`debian-slim`. If a request is slow, that is why, not a hang.

```bash
gcloud run services logs read shardfall-pvp --region="$REGION" --limit=50
```

| Symptom | Cause |
| --- | --- |
| `pvp_server_not_configured` | Step 7 secrets missing |
| `match_initialization_unavailable`, 401 in Cloud Run logs | the two copies of the shared secret differ |
| `service role required` from the RPC | `SHARDFALL_SERVICE_ROLE_KEY` is not the service role key |
| `unknown_card` when queueing | `pvp_card_catalog` is stale — regenerate it after a set change |
| `invalid_payload` on `/initialize` | the player payload is not camelCase. The service expects `userId` / `seat` / `deckSnapshot`; `pvp-queue` maps the Postgres columns before sending. |

A failed start is now safe: `pvp-queue` cancels the match and releases both
players, and the `pvp-reap-stale-matches` cron catches anything it misses. That
was not true before — a single failed initialization used to lock both players
out of PvP permanently.

## Cost

Scale-to-zero means you pay only while a request is in flight. Closed-test
traffic realistically lands under a dollar a month. To remove cold starts during
a scheduled test session, set `--min-instances=1` and put it back to `0`
afterwards; leaving one instance warm all month is the one setting here that
turns pennies into roughly $15–20.
