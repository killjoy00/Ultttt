# Ultimate Tic/Tac/Toe for Android (work in progress)

This is a **native Kotlin / Jetpack Compose** port in the same repository as the SwiftUI app. The first delivery implements the offline, playable foundation. It is **not yet Google Play ready**.

## Current capabilities
- Same immutable forced-board rules and legal move validation as Swift \`UltimateGame\`
- Local two-player and Easy/Medium/Hard computer, matching iOS evaluation and node budget
- Android native 3×3 grid of mini-boards, claimed-board fills, distinct active-board outline, winning lines
- System/light/dark appearance, persisted offline matches and scores, undo, move-by-move replay
- Optional first-run introduction; no third-party prompts on first launch
- Automated Android API 36 build and rules tests in \`.github/workflows/android-ci.yml\`

## Still required before release
- Upgrade introductory guidance to the full interactive iOS tutorial; improve screen reader coverage, sound/haptics, icon and visual QA.
- Set up Play Games Services v2 for achievements and leaderboards. Its former multiplayer APIs **do not exist**; build a separate asynchronous multiplayer service if online play is needed.
- Integrate AdMob with UMP consent and platform-specific live Android identifiers. Until then **no ads**. Add Google Play Billing for Remove Ads only when testable and approved; **do not** advertise an unavailable purchase.
- Verify privacy / data safety, Android App Bundle signing, genuine store screenshots, Play Console listing and accessibility/device QA.
- Publish through internal testing first, then closed testing and production access as applicable. The signed bundle and uploading must use GitHub Actions secrets, not local developer machines.

## Builds
Open the \`android/\` directory in Android Studio, or use the Android CI workflow. CI uses JDK 17, Gradle 8.13, Android Gradle Plugin 8.13.2, compileSdk / targetSdk 36. The package name is \`com.killjoy00.ultttt\`. No signing secrets are committed.

Run unit tests and a debug build with \`gradle -p android testDebugUnitTest assembleDebug\` on a build environment with the Android SDK installed. GitHub Actions produces an installable debug APK for internal device testing. Do not upload the unsigned debug APK as the final production release.

The Swift app and iOS CI are unchanged.
