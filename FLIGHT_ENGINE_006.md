# iumrah Beta — Flight Engine 0.6

Technical update only. No 0.4 visual redesign is included.

## Runtime flow

1. `AutomaticFlightSearchService` checks `/api/package/health`.
2. If Package Engine + Hotels D1 are ready, `RoundTripFlightBotCoordinator` launches the real provider adapters.
3. The orchestrator collects at least 4 verified candidates and prefers 6.
4. Raw provider fare + original currency stay inside the technical pricing bridge. The customer-facing `FlightOffer` never contains a ticket price.
5. `/api/package/flight-options/quote` converts source fares to USD using the official Central Bank of Uzbekistan exchange-rate JSON feed.
6. For outbound cards, Package Engine uses the cheapest verified return candidate as a reference and returns only full-package prices.
7. After outbound selection, every return candidate is quoted against that exact outbound candidate.
8. The final return `FlightOffer` already carries the exact public package quote. Internal hotel/flight costs, markup, fees and profit never return to iOS.

## Safety / beta fallback

`AppConfig.flightEngineMode = .automatic`.

If `/api/package/health` is not deployed or Hotels D1 is not bound yet, the existing sandbox is used. This means update 0.6 is safe to ship to TestFlight before the Cloudflare Package Engine is enabled.

When the Worker becomes healthy, the same TestFlight binary can start using the real engine without another UI rewrite.

## Server routes

- `GET /api/package/health`
- `GET /api/package/primary-hotel`
- `POST /api/package/quote`
- `POST /api/package/flight-options/quote`

## Pricing contract retained from iumrah Web

- package markup: 50%
- payment gross-up: 2%
- public rounding: nearest $5 per traveller
- visa: $120 per traveller
- meal tier logic retained
- transfer: sedan capacity 3
- guide + Makkah/Madinah ziyarat logic retained
- room minimum retained

## Known beta limitation

Provider pages change markup frequently. Each provider is isolated: one failed parser or CAPTCHA cannot crash the complete search. CAPTCHA is never bypassed; the existing `FlightBotChallengeCenter`/`WKWebView` path is reserved for human completion.
