# Ultimate Tic/Tac/Toe for Android (work in progress)

This is a **native Kotlin / Jetpack Compose** port in the same repository as the SwiftUI app. The offline playable foundation is released; Android AdMob banner and Remove Ads Billing support are being prepared for the next release.

## Current capabilities
- Same immutable forced-board rules and legal move validation as Swift \`UltimateGame\`
- Local two-player and Easy/Medium/Hard computer, matching iOS evaluation and node budget
- Android native 3×3 grid of mini-boards, claimed-board fills, distinct active-board outline, winning lines
- System/light/dark appearance, persisted offline matches and scores, undo, move-by-move replay
- Optional first-run introduction; no third-party prompts on first launch
- Automated Android API 36 build and rules tests in \`.github/workflows/android-ci.yml\`

## Launcher icon / Play policy
- The installed Android icon is now a bundled adaptive icon based on the same nine-board teal/coral artwork as `android/play-store/generate_assets.py`'s Play Store icon. `AndroidManifest.xml` explicitly sets `android:icon` and `android:roundIcon` to `@mipmap/ic_launcher` so Android cannot fall back to a default platform icon.
- **When changing the icon, update both the on-device drawable and the Google Play high-resolution listing icon together.** Keep the Play title and `@string/app_name` identical: **Ultimate Tic/Tac/Toe**.
- Android CI validates the compiled APK includes a launcher icon, preventing another default-system-icon submission.

## Still required before the ads-and-purchases release
- Upgrade introductory guidance to the full interactive iOS tutorial; improve screen reader coverage, sound/haptics, visual QA.
- Play Games Services v2 achievements and leaderboard are wired but remain disabled until you enter the actual Play-assigned IDs. See [activation instructions](PLAY_GAMES_SETUP.md). Its former multiplayer APIs **do not exist**; build a separate asynchronous multiplayer service if online play is needed.
- AdMob banners, UMP consent, and Play Billing Remove Ads are now implemented on the Android code branch. **Live ads remain disabled until the actual Android AdMob app ID and banner unit ID are provided, the Remove Ads one-time product is configured, and the new build passes Play review.** Details: [Android ads and Billing](ADS_AND_BILLING.md).
- Verify privacy / data safety, Android App Bundle signing, genuine store screenshots, Play Console listing and accessibility/device QA.
- Publish through internal testing first, then closed testing and production access as applicable. The signed bundle and uploading must use GitHub Actions secrets, not local developer machines.

## Builds
Open the \`android/\` directory in Android Studio, or use the Android CI workflow. CI uses JDK 17, Gradle 8.13, Android Gradle Plugin 8.13.2, compileSdk / targetSdk 36. The package name is \`com.killjoy00.ultttt\`. No signing secrets are committed.

Run unit tests and a debug build with \`gradle -p android testDebugUnitTest assembleDebug\` on a build environment with the Android SDK installed. GitHub Actions produces an installable debug APK for internal device testing. Do not upload the unsigned debug APK as the final production release.

The Swift app and iOS CI are unchanged.
