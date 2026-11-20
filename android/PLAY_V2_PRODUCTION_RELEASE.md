# Ultimate Tic/Tac/Toe — corrected Google Play production release

- App id: `com.killjoy00.ultttt`
- Version: **1.0.1**, version code **2**
- Target track: **production**
- Release source: merged Android foundation with corrected launcher icon
- Resolved: required destination colors follow X or O; R8 mapping embedded in release App Bundle
- Native symbols: enabled for available libraries; pre-stripped library symbols cannot be reconstructed
- This file marks the deliberate one-time production release. Workflow: `.github/workflows/android-play-production-v2.yml`

The version-1 bundle was rejected for Play listing/on-device launcher-icon mismatch. Do not upload the rejected bundle again.
