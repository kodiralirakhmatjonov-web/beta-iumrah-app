# Iumrah production Google Sign-In

Production Google OAuth is configured for the canonical iumrah account architecture.

## Public OAuth identifiers

- iOS bundle ID: `com.iumrah.app`
- iOS Client ID: `863185716777-p3ugvu6llaj3np0g0p6of3cqfr1d37te.apps.googleusercontent.com`
- iOS callback scheme: `com.googleusercontent.apps.863185716777-p3ugvu6llaj3np0g0p6of3cqfr1d37te`
- Server/Web Client ID: `863185716777-8tec2kuch1qkra1f1coikpi20j6is65f.apps.googleusercontent.com`

No Google client secret belongs in the iOS repository or app binary.

## Identity contract

Google is an external credential only. The six-digit iumrah ID remains the canonical account identifier. iOS, future Android, and Web send verified Google identity to the same Package Engine and receive the same iumrah account/session model.

- iOS uses the production iOS Client ID plus the Server/Web Client ID.
- Web should use the same Server/Web Client ID with Google Identity Services.
- Android should get its own Android OAuth client (package name + SHA-1) and request the same Server/Web Client ID as server client ID.
- Package Engine validates Google signature, issuer, audience, expiration, nonce, and token replay before issuing an iumrah session.

## TestFlight signing note

The iOS target uses the App Store provisioning profile, but GoogleSignIn Swift Package resource targets must not inherit that provisioning profile. Therefore app signing is target-scoped in `project.yml`, and `.github/workflows/testflight.yml` passes only the custom `IUMRAH_APPLE_TEAM_ID` / `IUMRAH_PROFILE_NAME` values.
