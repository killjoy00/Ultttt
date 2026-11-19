# Google Play Console policy answers — Ultimate Tic/Tac/Toe (Android offline v1)

**Prepared from the Android source in this repository, November 19, 2026.** These answers are not automatically submitted to Play Console. Verify them against the actual uploaded AAB and Play's current questionnaire before saving any declaration. They must be revisited when online play, ads, purchases, or external SDKs are added.

## Main store listing
- App name: **Ultimate Tic/Tac/Toe**
- Language: **English (United States)**
- App type: **Game**
- Category: **Board** (subject to current Console options)
- Price: **Free**
- Short and full descriptions: see [en-US.json](en-US.json)
- Contact email: **must use the developer's Play Console contact email** (not provided to this repository; don't invent one)
- Website/support: https://killjoy00.github.io/Ultttt/support/
- Privacy policy for Android version: https://github.com/killjoy00/Ultttt/blob/main/android/PRIVACY.md
- Suggested release notes: *First Android test build: offline computer games, pass-and-play, saved matches, stats, replay, and light/dark themes.*

## App content / policy declarations (current Android binary only)
| Console question | Grounded proposed answer | Notes |
| --- | --- | --- |
| Ads | **No** | No AdMob SDK or ad requests in this Android build. This differs from iOS. |
| App access | **All functionality accessible without login** | First-run tutorial can be skipped. No passwords or restricted review path. |
| Data safety: data collected by developer/SDKs | **None identified** | Only local game history/settings using Android SharedPreferences; no internet permission or third-party data SDKs. Verify packaged dependencies before submitting. |
| Data safety: data shared | **None identified** | No third-party analytics, ad SDK, or remote match backend. |
| Account creation | **No** | No account/login or remote profile. |
| Data deletion | **Delete/clear local app storage** | No account and no developer backend to request deletion from. |
| In-app purchases | **No** | Play Billing is not yet present. |
| News / financial / health / government app | **No** | It is an offline board game. |
| High-risk permissions | **None** | No location, contacts, camera, storage/media, SMS, microphone, etc. |
| User-generated content or messaging | **No** | Local two-player uses the same device. There is no chat or content upload. |
| Content rating | **Complete official questionnaire** | Gameplay itself has no violence, sex, drugs, profanity, gambling, or user-chat content. Let the questionnaire assign the official result; don't claim a rating without it. |
| Target audience | **Developer confirmation required** | A nine-board strategy game can appeal to teens and adults. Suggested initial selection: 13–15, 16–17, and 18+, **only if this represents the actual intended audience**. Selecting children requires Families-policy compliance. |
| Ads identifier / data encryption | **Not applicable to current build** | No ad identifier dependency or network transmissions. Device OS backups are separate from developer collection. |

## Pending setup not automatable with the Play Developer API

The Play Console's **App content** forms (ads, app access, content rating, data safety, target audience), App signing, contact email, countries, and testing/production access eligibility generally need the developer's console UI. These are distinct from the store listing descriptions/images that can be updated through the Android Publisher API with permission.

The artwork/screenshot assets must reflect the **real Android** build. A suggested initial graphic set is: a 512×512 high-resolution app icon matching the iOS game identity; 1024×500 feature graphic; 2–8 real portrait phone screenshots. Do not reuse fake game-state mockups. Do not advertise online play, Game Center, Google Play Games, ads, paid ad removal, or interactive tutorial parity in this initial Android listing.

## Re-check before production

- Does the actual tested AAB include any SDK/permission not listed above?
- Is the Android-specific privacy policy URL public and reliably accessible?
- Are main store listing text and screenshots complete and truthful?
- Is target audience selection honest about the intended players?
- Are the appropriate testing requirements met for the developer account?
- Is release explicitly approved after internal testing and device QA?
