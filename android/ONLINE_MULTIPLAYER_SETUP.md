# Android online multiplayer — Neon

This is a **separate, unfinished** online-play feature for Ultimate Tic/Tac/Toe.
It does not use the retired Google Play Games multiplayer APIs and does not
affect offline games, the existing Play Games achievements, Billing, or AdMob.

## Architecture

Android (Kotlin) → one **Neon Function** (`ulttttonline`) → private Neon Postgres.

- No login screen. A random 256-bit guest credential is generated and stored
  per installation. Every request sends it as an HTTPS bearer token.
- The server hashes the credential, authorizes participation, and returns only
  `self` / `opponent` aliases. Neither player hashes nor SQL credentials go to Android.
- PostgreSQL functions validate every move, forced-board choice, player turn,
  version, and completion. Atomic row locks prevent simultaneous move races.
- Players can find an opponent, invite by a twelve-character code, and resume
  games on the same device. The screen checks for updates every 15 seconds.
- Completed wins are sent to Google Play Games *only after* authenticated
  Play Games sync, and the unique match ID prevents duplicate credit.
- Reinstalling or clearing app data loses the anonymous guest credential and
  access to unfinished matches. Cross-device restoration and iOS crossplay are
  not yet included.

**Abuse protections before public release:** This first version limits
waiting matches per guest. It does not have a reliable IP-based anti-spam
system; public deployment needs a reviewed rate-limit/abuse policy. Do not
publish a production app pointing to an unprotected function.

## Provision

Use a **dedicated** Neon project called `Ultttt Online`, not the database
for another product. Choose an AWS region supporting Neon Functions
(e.g. `aws-us-east-2`). The project and function do not exist merely because
the source is committed.

An account-connected agent can perform these steps with the Neon CLI/MCP:

1. Select the UTTT Neon project/branch (the free plan has limits; inspect cost
   before creating new paid resources).
2. Verify the project has a branch-backed Postgres DB. Do not enable the Data
   API or expose Postgres to a native Android client.
3. Install `schema.sql` on the dedicated branch with the **owner** database
   role. Run `schema_smoke.sql` and inspect the grants/RLS. The runtime's
   `DATABASE_URL` is injected only into the Neon Function.
4. In `android/online-backend`, run `npm ci` (after lockfile is committed).
   Deploy the function source using the Neon CLI, for example
   `neon functions deploy ultttonline --src functions/ulttttonline/index.mjs`.
   Read the actual invocation URL using `neon functions get ultttonline`.
   The function checks guest credentials on **every** route.
5. Keep `ONLINE_NEON_FUNCTION_URL=` blank in
   `android/online.properties` for local/offline builds. After backend
   verification supply the **public URL only** as build environment variable
   `ULTTTT_ONLINE_NEON_FUNCTION_URL` for an **internal-testing** AAB.
   It must be an HTTPS `*.neon.tech` function URL. Never put `DATABASE_URL`,
   a Neon API key, or a secret in the app build.
6. Install the AAB from the Google Play internal track on **two different
   Android devices** and verify:
   - Guest starts a private invite; another guest joins with its code
   - Public Find an opponent pairs two different guests
   - Wrong-player moves, duplicate/stale moves, and illegal forced-board
     moves are rejected by Postgres, not just by the UI
   - Matches reload after the app restarts and after connectivity returns
   - Completing an online match records one win in Play Games, not twice
   - The game board, ads, Remove Ads, and offline play still work
7. Confirm billing, data disclosures, rate-limit protection, and cost controls
   before production rollout. **No automatic production deployment**.

## Local and CI checks

Backend pure API tests: `npm ci && npm test` from
`android/online-backend`. SQL schema and smoke tests run in a PostgreSQL 17
service in `.github/workflows/android-neon-online-ci.yml`. The same PR also
runs Android CI for Kotlin unit tests and AAB compilation.

## Why a Neon Function instead of Neon Auth/Data API?

The first rollout needs no email, password, or OAuth flow. A server-only
bearer-secret identity preserves the existing guest onboarding. A Neon
Function checks this guest identity on every request and owns all PostgreSQL
access, so no SQL or public database credentials are bundled with Android.
This is distinct from a Neon Auth managed account. We can add account linking
later when cross-device restoration and Android/iOS crossplay are designed.

See the official Neon docs:
https://neon.com/docs/compute/functions/overview
https://neon.com/docs/compute/functions/authentication
https://neon.com/docs/compute/functions/deploy
