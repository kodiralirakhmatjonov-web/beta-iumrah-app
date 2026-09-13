# iUmra 2.0.0 — App Store update

This repository is prepared to replace the published iUmra 1.0.4 binary while keeping the same App Store record.

- App Store ID: `6759577859`
- Bundle ID: `com.iumrah.app`
- Marketing version: `2.0.0`
- CI build number: `20000 + GitHub Actions run number`
- Previous source version: `1.0.4+14`
- Existing IAP: `iumrah.plus` (non-consumable)
- Legacy URL scheme: `iumrah://`
- Current hotel URL scheme: `iumrahapp://`
- Universal links: `applinks:iumrah.app`
- Device family: iPhone + iPad

## Before TestFlight

Create an App Store distribution provisioning profile for the existing App ID `com.iumrah.app`. Enable Push Notifications, Sign in with Apple and Associated Domains, and use the existing Apple Distribution certificate documented in `SIGNING_REQUIRED.txt`. Put the `.mobileprovision` in `Signing/`.

Then deploy the Package Engine once so Apple identity-token verification uses `com.iumrah.app`, and run the App Store/TestFlight workflow.
