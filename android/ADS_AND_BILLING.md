# Android ads and Remove Ads — release 1.1.0 (version code 3)

## Verification status and publisher identity

Ultimate Tic/Tac/Toe uses the existing shared publisher ID `pub-1217971050094766`.
The **public** root authorized-sellers file at
`https://killjoy00.github.io/app-ads.txt` already includes this exact line:

```text
google.com, pub-1217971050094766, DIRECT, f08c47fec0942fa0
```

The website is hosted by `killjoy00/killjoy00.github.io`, not by the app repository.
The Google Play Developer Website field was found empty by the audit and was saved
to `https://killjoy00.github.io/Ultttt/` via the shared Play publishing workflow.
Allow Google Play and AdMob time to crawl/review the new store website link.

## Ad SDK and experience

- Google Mobile Ads SDK 25.5.0, User Messaging Platform 4.0.0, Play Billing 9.1.0.
- Exactly one **anchored adaptive banner** below the scrolling game board; none on replay
  or during the first-run tutorial.
- Google UMP is requested after tutorial completion and checked each app launch.
- No banner SDK initialization or requests until UMP `canRequestAds()` is true.
- A visible **Advertising privacy choices** action appears in Settings when UMP requires it.
- The game remains fully playable offline. No interstitials or gameplay interruptions.
- The paid `com.killjoy00.ultttt.remove_ads` non-consumable is queried using Google Play
  Billing, restores purchase ownership, acknowledges verified Play purchases, and suppresses
  banner requests for owners. The offline cached entitlement is reconciled when Play returns.
- A purchase control is not offered until Play returns a localized product and price.
- Server-side purchase verification is recommended for future hardening. For the client-only
  launch, ownership is checked with Google Play Billing's queryPurchasesAsync; a server-side
  verification backend is not included here.

## Mandatory identifiers and Google Play setup before publishing code 3

**Do not confuse these values with the app-ads.txt publisher ID.** Two values
must be copied from **AdMob → Apps → Ultimate Tic/Tac/Toe (Android)**:

1. **Android AdMob App ID:** `ca-app-pub-1217971050094766~NNNNNNNNNN`
2. **Android banner Ad Unit ID:** `ca-app-pub-1217971050094766/NNNNNNNNNN`

Pass them to Gradle as environment variables `ULTTTT_ADMOB_ANDROID_APP_ID` and
`ULTTTT_ADMOB_ANDROID_BANNER_UNIT_ID` through the secure release runner.
Debug builds use Google's official test app/banner IDs. A release with no real identifiers
remains ad-disabled, so no accidental real-ad request or unconfigured ad startup occurs.
**A Play release must require the real IDs** and validate their format/owner.

In Google Play Console, register a **one-time non-consumable product**
`com.killjoy00.ultttt.remove_ads` with an agreed price, localization, and activated
purchase option. A configured Google Play Billing product is required before advertising a
working Remove Ads purchase. Verify purchase, cancellation, pending state, refund,
reinstall and restoration on a tester account.

Complete the Play Console **Contains ads** declaration, update **Data safety** disclosures
for Google Mobile Ads/UMP/Billing, review age/target-audience restrictions, and ensure
AdMob Privacy & messaging regional consent forms are configured before submitting code 3.
Publish the revised Android privacy policy before the monetized build.

## Automated release guardrails

The **v2** signed upload workflow is intentionally not reused for code 3 without changing
its fixed version / pre-release checks. The next production release must use version
code 3 and a separate explicit release request, and must check live AdMob IDs, active
Remove Ads product, signed app bundle, launcher icon, R8 mapping, and Play review status.

Never put a Google Play service-account JSON, signing key, AdMob app ID/ad unit secrets,
or purchase tokens into a GitHub commit, GitHub issue, or support email. AdMob publisher
IDs and public app-ads.txt entries are already public and safe to publish.
