# Ultimate Tic Tac Toe for iPhone

A native, offline SwiftUI version of Ultimate Tic Tac Toe.

## Play

- Play against the computer (Easy, Medium, Hard) or take turns on one phone.
- Each move sends the next player to the corresponding small board.
- If that small board is complete, the next player may play in any unfinished board.
- Win three small boards in a row to win the match. Drawn small boards count for neither player.
- Undo, saved games, and match scores are included. The computer plays O; X moves first.

## Project

- `Sources/UltimateTTTCore`: Swift game rules and offline computer opponent
- `UltimateTTTApp`: Native iOS 17+ SwiftUI app
- `Tests/UltimateTTTCoreTests`: Rules tests
- `project.yml`: XcodeGen project specification
- `.github/workflows/ios-ci.yml`: Linux rules tests and macOS simulator build

To generate the Xcode project on a Mac with Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
xcodegen generate
open UltimateTTT.xcodeproj
```

Run game-logic tests from any supported Swift toolchain:

```sh
swift test
```

## Shipping to TestFlight

The CI workflow builds the simulator app without Apple signing credentials. Publishing to TestFlight is a separate step requiring an Apple Developer team, an App Store Connect app record, signing, and an archive/upload workflow. No Apple credentials are stored in this repository.
