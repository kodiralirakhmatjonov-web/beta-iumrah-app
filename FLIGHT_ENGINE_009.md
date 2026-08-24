# iumrah Beta Flight Engine 0.09

Technical TestFlight validation mode.

- Real provider bots are enabled (`officialWebBots`).
- No silent sandbox fallback is allowed in this build.
- Search target: 6 verified options; hard minimum: 4.
- Providers run in bounded batches to reduce search latency and iPhone memory pressure.
- CAPTCHA/human verification is surfaced to the user through a persistent WKWebView session.
- Raw fares remain private technical observations and are sent to Package Engine only.
- Package Engine normalizes FX server-side and returns public package totals only.
- Flight observations older than 20 minutes are rejected by Package Engine.
- Unknown provider IDs, invalid fare scope/currency/date, and oversized quote batches are rejected.
- API errors expose server-side reason to the beta UI instead of silently switching to mock results.

Before TestFlight validation:
1. Apply this ZIP.
2. Re-run `Deploy iumrah Package Engine` so backend 0.09 is live.
3. Confirm deployment is green.
4. Run the existing TestFlight workflow once.
