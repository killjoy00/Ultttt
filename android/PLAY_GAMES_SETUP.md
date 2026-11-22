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
- The integration is **disabled** until the correct non-secret project ID is supplied.

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
4. Go to **Achievements** and create these five **standard (not incremental)**
   achievements. Use suitable names and descriptions; the IDs below are
   **semantic names for the app configuration**, not Play-assigned identifiers.

   | Name | When awarded | Config key |
   | --- | --- | --- |
   | First Win | First win vs computer | PGS_FIRST_WIN_ID |
   | Five Wins | Five wins vs computer | PGS_FIVE_WINS_ID |
   | Ten Wins | Ten wins vs computer | PGS_TEN_WINS_ID |
   | First Online Win | First confirmed online win | PGS_FIRST_ONLINE_WIN_ID |
   | 25 Online Wins | Twenty-five confirmed online wins | PGS_TWENTY_FIVE_ONLINE_WINS_ID |

5. In **Leaderboards**, create **Online Wins**, integer, higher is better, no
   reset, with the user's **cumulative online wins**. Save its assigned ID as
   `PGS_ONLINE_WINS_LEADERBOARD_ID`.
6. Copy the **actual Google-generated IDs** from the Play Console resources
   view into `android/play-games.properties` in the repo. Also fill the
   numeric `PLAY_GAMES_APP_ID`. All seven IDs are public app identifiers,
   **not secrets**; they may be committed. They can alternatively be supplied
   as matching `ULTTTT_*` build environment variables.
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
