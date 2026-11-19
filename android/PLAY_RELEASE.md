# Ultimate Tic/Tac/Toe: Android Play Console launch

This repository already builds a **debug APK** on Android CI. That APK is only for testers; it is not a Play Store production release. The separate **Ultimate TTT - Google Play Internal Testing** workflow is `workflow_dispatch` only, restricted to `main`, requires an explicit upload confirmation, and only publishes to the **internal** track. It does not auto-publish to closed testing or production.

## Android identity

- Public name: **Ultimate Tic/Tac/Toe** (must be confirmed available on Google Play; iOS name availability does not reserve Android name)
- Application ID / package: `com.killjoy00.ultttt` (treat as permanent once enrolled)
- Category: Game → Board
- Price: Free
- First test version: `1.0.0-alpha01`, version code `1` (increase on every upload)
- Target SDK 36 and minimum SDK 26.

## What an account administrator must configure

1. Open [Google Play Console](https://play.google.com/console/) using the publisher account that should own the Android game. Create a new **game**, free, with package `com.killjoy00.ultttt`. Only proceed after confirming it is not already registered to a different publisher.
2. Fill out the store listing, developer contact, content rating, target audience, Data safety, advertisements declaration, app access, countries, privacy policy, and all other applicable Play Console policy screens. Use genuine captures from the Android app; no fabricated gameplay/screenshots.
3. Enable Play App Signing. Establish an **app-specific PKCS12 upload key** with alias `upload`. Store the key and password securely (not in the repository). The CI workflow expects **the same password for the PKCS12 keystore and its upload key**, so make them match when provisioning the key.
4. Grant a Google Cloud service account Google Play Developer API access **only** to this new app and the relevant release permissions. Make sure the service account JSON has the correct scoped access. Do not commit credentials or expose them in an issue/PR comment.
5. Add GitHub Actions secrets in the `killjoy00/Ultttt` repository: `ANDROID_UPLOAD_KEYSTORE_BASE64` (base64 contents of the PKCS12 upload key), `ANDROID_UPLOAD_KEY_PASSWORD` (its password), and `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` (service account JSON). These secret **names** match the EZTrivia release approach; repository-scoped secret values are **not automatically shared** with Ultttt.
6. After the Android foundation PR is reviewed and merged into `main`, visit **GitHub → Ultttt → Actions → Ultimate TTT - Google Play Internal Testing → Run workflow**. Enter an unused version code (starting at `1`), version name `1.0.0-alpha01`, a tester-facing note, and affirm **internal upload**. The workflow will test, build, verify signing, archive the AAB, and upload to internal testing. Do not run it before the application, permissions, credentials and store policy pages are in place.
7. Add internal testers and verify installation, game rules, computer difficulty, undo, stats persistence, replay, onboarding, screen readers, UI on small/large screens, and switching between light/dark and landscape/portrait. The first PR is **not yet full feature parity with iOS**.
8. Complete future PRs for original assets/icons and real screenshots, full tutorial parity, online backend, Play Games Services achievements/leaderboards, AdMob + UMP consent, and Google Play Billing Remove Ads. Until these features are implemented and reviewed, do not advertise them in the Play listing. The initial offline game can still ship without those integrations once its own QA/policy requirements are satisfied.
9. Move to closed testing and production only through a **separate** explicitly approved release. New personal developer accounts may need a continuous 14-day closed test with at least 12 opted-in testers before requesting production access; verify the publisher account's status in Play Console. Google review/approval is external and cannot be guaranteed by CI.

## Multiplayer decision

The existing iOS online mode relies on Apple Game Center, which does not provide Android or cross-platform turn-based game storage. Google Play Games Services can provide achievements and leaderboards, but no longer offers its retired turn-based multiplayer APIs. Any Android online play or iOS↔Android games require a separate authenticated asynchronous backend and a compatible iOS update. Offline two-player and computer play do not require backend infrastructure.

## Release guardrails

- No production upload runs automatically; the provided workflow targets **internal** only.
- Never put Google Play credentials or signing keys into a PR, issue, readme, commit, or artifact.
- Do not use the upload key from another app merely because it exists; provision the proper signing configuration for the new app.
- A passing CI build is not a substitute for real-device testing and Play Console review.
