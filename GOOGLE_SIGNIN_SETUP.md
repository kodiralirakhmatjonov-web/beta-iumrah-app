# Sign in with Google — activation checklist

The repository already contains the complete Google sign-in client/backend flow. It intentionally ships with OAuth placeholders because Google OAuth credentials must be created inside the iumrah Google Cloud project; no client secret belongs in this repository.

## 1. Create the two Google OAuth clients

In Google Cloud Console, use the same project for both credentials:

1. Create an **iOS OAuth client** with bundle identifier `com.iumrah.beta`.
2. Create a **Web application OAuth client** for the iumrah backend.

Keep these three public values:

- iOS Client ID — normally ends in `.apps.googleusercontent.com`.
- iOS URL scheme / reversed client ID — normally starts with `com.googleusercontent.apps.`.
- Web/Server Client ID — normally ends in `.apps.googleusercontent.com`.

Do **not** add a Google client secret to the iOS app, GitHub, Info.plist, or this repository.

## 2. Fill the iOS configuration

Open `Resources/Info.plist` and replace all three placeholders:

- `__GOOGLE_IOS_CLIENT_ID__` → iOS Client ID.
- `__GOOGLE_SERVER_CLIENT_ID__` → Web/Server Client ID.
- `__GOOGLE_REVERSED_IOS_CLIENT_ID__` → iOS URL scheme / reversed iOS Client ID.

The existing `iumrahapp` URL scheme is deliberately left untouched. Google has its own second URL type.

## 3. Fill the Package Engine audience

Open `Backend/PackageEngine/wrangler.template.jsonc` and replace:

- `__GOOGLE_SERVER_CLIENT_ID__` → the **same Web/Server Client ID** used as `GIDServerClientID` in `Info.plist`.

The Package Engine verifies the Google ID-token signature, issuer, audience, expiry, nonce and replay status before it creates an iumrah session.

## 4. Rollout order

Deploy the Package Engine **before** shipping the iOS build. Its migration adds `iumrah_client_google_links` and `iumrah_client_google_assertions`; the worker then exposes:

- `POST /api/package/client/account/google/sign-in`
- `POST /api/package/client/account/google/link`

After the backend is live, build/TestFlight the iOS app. XcodeGen resolves Google Sign-In through Swift Package Manager from `project.yml`.

## 5. Account behavior

Google follows the existing Sign in with Apple contract:

- Google `sub` is only an external credential; the six-digit iumrah ID remains the canonical account ID.
- A Google identity can be linked to only one iumrah account, and an iumrah account can have only one Google identity.
- Linking a new Google sign-in method from Account Security requires the protected primary device.
- If a first Google sign-in has a verified email already registered to iumrah, that existing canonical account is used instead of creating another profile.
- If no canonical account exists for that verified email, one account is created and the current device becomes primary, matching the existing Apple flow.
- Successful Google sign-in returns the same iumrah account/session response used by Apple and password login.

## 6. Validation note for this source ZIP

The Google account-security additions pass Package Engine TypeScript typecheck and the complete account-security contract test file. The original source ZIP already contains six unrelated failing Flights/Storefront contract tests; they are unchanged by this Google patch. Because the existing Package Engine GitHub deploy workflow runs the entire `npm test` suite, those pre-existing failures must be resolved before that workflow can finish a production deploy. Do not bypass them silently.
