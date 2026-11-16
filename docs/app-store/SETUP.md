# App Store setup: Ultimate Tic/Tac/Toe

## App identity

| Field | Value |
| --- | --- |
| App | Ultimate Tic/Tac/Toe |
| Platform | iOS |
| Bundle ID | com.killjoy00.ultttt |
| Version | 1.0.0 |
| SKU (private suggested value) | ULTTTT-IOS-001 |
| Primary language | English (U.S.) |
| Category | Games → Board |
| Suggested second category | Strategy |
| Price | Free with optional one-time Remove Ads |

The user created the App Store Connect app as Ultimate Tic/Tac/Toe because the original name was unavailable. Keep the bundle ID unchanged.

## Apple Developer and App Store Connect

1. Register an explicit App ID at https://developer.apple.com/account/resources/identifiers/list (Identifiers → + → App IDs → App → Continue). Enter the bundle ID above and enable Game Center and In-App Purchase.
2. Visit https://appstoreconnect.apple.com/apps and create an iOS app with the same bundle ID, language, SKU and public name. Your Account Holder must accept outstanding Apple agreements before adding the app.
3. Under Game Center, enable the Game Center app version and add the five achievements and classic leaderboard below. New Game Center components must be reviewed with the first app version.
4. Under Monetization → In-App Purchases, create the non-consumable Remove Ads product below. Add pricing and US English metadata, plus any required review screenshot.
5. Under App Privacy, add the privacy policy URL and complete accurate third-party data disclosures. The app integrates Google AdMob and UMP, so do not assume "no data collected."
6. Under Distribution, complete age rating, category, copyright, support URL, app description, keywords and real device screenshots. The JSON draft is in docs/app-store/en-US.json.
7. Use the shared-credential GitHub Actions workflow in EZTrivia to build and upload an immutable Ultttt source commit. No local Mac or new Apple API key should be necessary if the existing EZTrivia secrets have access to this app.
8. After Apple processes the binary, add internal TestFlight testers and validate using two actual Game Center accounts/devices. Check online turns, rematch, achievements, IAP sandbox purchase and restore, local AI, tutorial/replay, sounds and privacy consent.
9. Only after the release checks are satisfied, attach the build and submit the app and its Game Center/IAP components for App Review. The automation must not publish an app publicly on its own.

## Remove Ads product

- Type: Non-consumable
- Reference name: Remove Ads
- Product ID: com.killjoy00.ultttt.remove_ads
- Display name: Remove Ads
- English description: Remove banner ads forever with a one-time purchase.
- Price: Choose in App Store Connect; no price has been selected by the developer.
- Do not create a subscription or consumable for this purchase.

## Classic Game Center leaderboard

- Reference name: Online Wins
- Leaderboard ID: com.killjoy00.ultttt.online_wins
- Type: Classic
- Sort: High to Low
- Submission: Best Score
- Integer range: 0 to 1,000,000
- English name: Online Wins
- English description: Most online matches won.

## Achievements

| Name | ID | Points | Before earned | After earned |
| --- | --- | --- | --- | --- |
| First Win | com.killjoy00.ultttt.first_win | 10 | Win your first game against the computer. | You won your first solo game. |
| Five Wins | com.killjoy00.ultttt.five_wins | 20 | Win five games against the computer. | Five solo wins in the books. |
| Ten Wins | com.killjoy00.ultttt.ten_wins | 30 | Win ten games against the computer. | You've won ten solo games. |
| First Online Win | com.killjoy00.ultttt.first_online_win | 20 | Win a Game Center match. | Your first online victory. |
| 25 Online Wins | com.killjoy00.ultttt.twenty_five_online_wins | 40 | Win 25 Game Center matches. | Twenty-five online victories. |

Total: 120 Game Center points. Provide localized artwork and descriptions for each badge. Identifiers in App Store Connect must exactly match the Swift code.

## AdMob release configuration

The source currently uses Google's official demo App ID and demo banner unit ID. For public release, create the app and an iOS banner unit in your AdMob account. Replace both IDs in project.yml and UltimateTTTApp/AdSupport.swift. Configure UMP consent messages, account privacy requirements and any applicable Apple disclosures before enabling live ads. Test ads are acceptable for internal development but do not earn revenue.

## Available public pages

- Privacy policy: https://github.com/killjoy00/Ultttt/blob/main/PRIVACY.md
- Support: https://github.com/killjoy00/Ultttt/issues

The app icon is generated on a GitHub macOS runner with swift tools/generate-app-icon.swift before the Xcode project is generated. Store screenshots must be captured from the real running app; do not submit invented mock screenshots.
