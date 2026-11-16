# Ultimate Tic Tac Toe for iPhone

Native SwiftUI Ultimate Tic Tac Toe, targeting iOS 17+. Light, dark, and Follow iPhone appearance options are available in the game's More → Appearance menu; the setting is saved on-device.

## Play

- Offline pass-and-play or computer (Easy, Medium, Hard)
- Game Center asynchronous turn-based multiplayer, invitations, automatch, saved games and **one-tap rematches**
- Game Center turn notifications and an in-app count of matches awaiting your move
- Five Game Center achievements: First Win, Five Wins, Ten Wins, First Online Win, Twenty-Five Online Wins
- Google AdMob banner; a one-time StoreKit 2 non-consumable removes ads
- Complete forced-board rules, local undo, saved local games and match scores
- Interactive three-stage beginner tutorial, won-board winning-line overlays and clear free-choice feedback
- Move-by-move game replay with key moments from actual board wins
- Local win/loss/draw statistics, streaks and difficulty splits; online cumulative wins leaderboard
- Optional in-app sounds and haptics

Open **More → Settings** to choose Follow iPhone, Light or Dark appearance and enable or disable sound/haptic feedback. Open **More → Interactive tutorial** for a playable walkthrough; **More → Statistics** shows match results and a link to Game Center leaderboards.

Online moves cannot be undone. Game Center stores matches while the app is closed and is responsible for notifying a player when their opponent ends a turn; delivery depends on that player's Apple/Game Center notification preferences. The app also refreshes its in-app "Your turn" count when returning to the foreground. There is no custom push server or separate user account.

Statistics begin tracking at installation of this version. Solo results are recorded once per saved game and removed if you undo the ending move; online outcomes are deduplicated by Game Center match ID. Match history is stored on-device and does not sync across devices. Game Center leaderboard results require signing in and configuring the matching ID in App Store Connect.

## Development

Use Xcode 26.2 or newer and XcodeGen, then run the following:

    xcodegen generate
    open UltimateTTT.xcodeproj
    swift test

The GitHub Actions workflow runs rules tests on Linux and an unsigned simulator build on macOS 26. Apple signing and TestFlight uploads are separate.

## Release checklist

1. **Apple Developer**: register bundle identifier **com.killjoy00.ultttt**, enable Game Center and In-App Purchase, and configure signing and App Store Connect.
2. **Game Center**: enable turn-based matchmaking and create these exact achievement IDs, including descriptions, localizations, points and artwork:
   - com.killjoy00.ultttt.first_win — First Win
   - com.killjoy00.ultttt.five_wins — Five Wins
   - com.killjoy00.ultttt.ten_wins — Ten Wins
   - com.killjoy00.ultttt.first_online_win — First Online Win
   - com.killjoy00.ultttt.twenty_five_online_wins — Twenty-Five Online Wins
   - **Leaderboard**: create and submit a *Classic* leaderboard with ID **com.killjoy00.ultttt.online_wins**, score type **Integer**, sort **High to Low**, and **Best Score** (never reset). The app sends each player's cumulative online wins when signed in. Add localization and submit for approval.
3. **StoreKit**: create a non-consumable product named Remove Ads with product ID **com.killjoy00.ultttt.remove_ads**. Set its price and localization in App Store Connect; test verified purchase, cancellation, restoration and revocation.
4. **AdMob**: create the iOS app and an actual banner ad unit. Replace the **Google test app ID** in project.yml and **Google test banner ad unit ID** in UltimateTTTApp/AdSupport.swift. Test IDs never earn revenue and must not ship.
5. **Privacy**: configure Google UMP consent messages. Complete required privacy disclosures, privacy policy, SKAdNetwork IDs and any ATT disclosures applicable to the chosen ad configuration. Ads are withheld until UMP allows requesting them.
6. **QA and release**: create a 1024x1024 icon, verify matches and rematches using two separate Game Center accounts/devices (foreground/background/terminated with Game Center notifications enabled), inspect tutorial and replay in both appearances, test each AI difficulty, switch sounds/haptics on and off, verify stats/leaderboard submission, test StoreKit sandbox purchase and restore, and produce a signed TestFlight archive.

No Apple credentials, signing keys or live ad identifiers are committed to the repository.

## Structure

- Sources/UltimateTTTCore: rules engine, minimax AI, match history and validated/versioned Game Center match payload
- UltimateTTTApp/GameCenterManager.swift: Game Center authentication, matchmaking, turns, rematches and turn notifications
- UltimateTTTApp/AchievementTracker.swift: persistent achievement progress and Game Center reporting
- UltimateTTTApp/PurchaseManager.swift: verified StoreKit transactions and purchase restoration
- UltimateTTTApp/AdSupport.swift: Google banner ads and UMP privacy controls
- UltimateTTTApp/ContentView.swift: native SwiftUI board and winning-line display
- UltimateTTTApp/TutorialSheet.swift: playable onboarding
- UltimateTTTApp/MatchReplaySheet.swift: postgame move replay
- UltimateTTTApp/StatisticsSheet.swift and GameStatisticsStore.swift: local stats and Game Center leaderboard sync
- UltimateTTTApp/GameFeedback.swift and GameSettingsSheet.swift: original sound effects, haptics and preferences
- Tests: rules, payload, opponent strategy, winning-line and match-history tests
- project.yml: XcodeGen settings, Game Center entitlement and Google Swift packages

## Design choices

Game Center match data is reconstructed from its move history before being displayed. The client reloads a match immediately before submitting a move to avoid overwriting another turn. Local play works offline, without Game Center or a purchase.
