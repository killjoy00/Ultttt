# Google Play Games Services v2: Android activation

Android's native Play Games integration is independent from Apple Game Center. Google
has retired the Play Games multiplayer APIs. This setup enables **achievements and the
online-wins leaderboard**, not online matchmaking. Android turn-based online play needs
a separate secure match backend.

## What is already coded

- Initialize Play Games v2 **after** the first-launch tutorial so the tutorial
  cannot be interrupted by third-party sign-in prompts.
- Detect player authentication, retry synchronization when they return to the app.
- Show Play Games achievements and the online-wins leaderboard from Statistics.
- Track unique solo games and online wins separately; never count pass-and-play as
  a solo achievement, and never award two wins for an undo/re-win of one game.
- Keep local gameplay functional when a Play Games account is unavailable.
- The numeric project ID **517518057047** and all six generated resource IDs are now in `android/play-games.properties`.

## Play Console: do these once

1. Open [Google Play Console](https://play.google.com/console/) → **Ultimate Tic/Tac/Toe**.
   Confirm the Android package is **com.killjoy00.ultttt**.
2. Go to **Grow users → Play Games Services → Setup and management →
   Configuration**. Set up a Play Games Services project if one is not linked.
   Use the **numeric Play Games Services Project ID** (shown beneath the game name),
   not the Google Cloud project name or the Android package.
3. Under **Credentials** / **Linked apps**, create or verify the Android
   credential for **com.killjoy00.ultttt**. Its **SHA-1 must match the App
   signing key certificate** shown at Play Console → Test and release →
   Setup → App integrity. Do **not** substitute the upload-key SHA-1. If you
   also sideload debug builds, add a separate debug credential with the debug
   signing SHA-1.
4. **Completed via Google API: five achievements and one leaderboard.**
   The existing Google Play service account is stored in the **EZTrivia**
   GitHub repository, not the UTTT repository. The isolated workflow
   `EZTrivia/.github/workflows/ultttt-play-games-provision.yml`
   ran successfully in branch `automation/ultttt-play-games-20261121`,
   run **44986983849**. The UTTT script `Scripts/configure_play_games.py`
   remains available for future audits and idempotent provisioning.

   | Name | Google resource type | When awarded |
   | --- | --- | --- |
   | First Win | Standard achievement | First win vs computer |
   | Five Wins | Standard achievement | Five wins vs computer |
   | Ten Wins | Standard achievement | Ten wins vs computer |
   | First Online Win | Standard achievement | First confirmed online win |
   | 25 Online Wins | Standard achievement | Twenty-five confirmed online wins |
   | Online Wins | Leaderboard (integer, high to low) | Cumulative online wins |

5. **Public configuration already committed:** `android/play-games.properties`
   contains `PLAY_GAMES_APP_ID=517518057047` and all six Google-issued
   resource IDs. Draft resources are separate from a Play Games publish
   and remain unavailable to general players until testing and publication.

6. **Asset review before publication:** Google Play Games achievement and
   leaderboard icons require suitable artwork. The Play Games Publishing
   API's image upload method is deprecated; artwork may need uploading or
   replacement through Play Console. The **Google Play Store listing**
   already contains six phone screenshots and one feature graphic, audited
   with the existing service account on November 21, 2026.
   These are different assets from Play Games icons.

7. Under **Testers**, add your Google account, a second tester, and/or enable
   the **internal test track** for Play Games Services. Unpublished PGS apps
   return sign-in/404 errors for accounts outside the tester list.
8. Publish the new **Play Games Services configuration** from its Publishing
   page when ready. This is separate from publishing an Android app bundle.
9. After the IDs land in the repo, merge the passing PR and run **GitHub Actions
   → Ultimate TTT - Google Play Internal Testing → Run workflow** on `main`.
   Use an unused Android version code. Confirm internal-track installation
   and authenticated achievements UI on a Play Games test account.
10. Win one, five and ten games against the computer and verify the milestone
    achievements. Once online matches are operational, win a match and verify
    the online achievement and leaderboard. Check sign-in, reopening,
    offline play, and offline-to-online recovery.

## Important safeguards

- Never use old `play-services-games` v1; Android uses pinned
  `play-services-games-v2:22.1.0`.
- Play Games platform identity does **not** authenticate users to a custom
  multiplayer server. Online games need independent authenticated identity.
- Achievements count confirmed results since this integration; historical
  local scores don't distinguish AI from pass-and-play and are not backfilled.
- IDs left blank mean Google Play Games integration remains disabled, not
  that the game is broken.
- Production uploads are never triggered by the code or PR. Review Play
  Console Data safety and user consent disclosures before the next release.

Official docs:
- https://developer.android.com/games/pgs/console/setup
- https://developer.android.com/games/pgs/android/android-signin
- https://developer.android.com/games/pgs/android/achievements
- https://developer.android.com/games/pgs/android/leaderboards
