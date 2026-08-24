# Flight Engine 0.5 — technical architecture

## Search target

The engine aims for 6 normalized options and refuses to silently invent results when fewer than 4 verified options are found.

## Uzbekistan-first providers

1. Uzbekistan Airways
2. Qanot Sharq
3. Centrum Air
4. Silk Avia
5. Air Samarkand
6. Fly Khiva

## Global discovery providers

7. Google Flights
8. Skyscanner

Uzbekistan-origin searches prioritize the six local/official airline booking systems first. Other origins prioritize the global discovery providers first, while official-provider adapters remain available.

## CAPTCHA / verification

No CAPTCHA bypass is implemented. When a provider requires a human code/CAPTCHA, the bot publishes a `FlightBotChallenge`. A reusable `FlightChallengeWebView` uses the same persistent WebKit website data store, allowing the user to complete verification and the bot to retry with the resulting cookies/session.

## Search algorithm

- exact / ±1 / ±2 / weekend date planning;
- multiple providers;
- provider isolation: one failed site does not kill the full search;
- result extraction from rendered booking pages;
- deduplication by airline + flight number + route + departure time;
- direct flights are ranked ahead of connections;
- closest requested date ranks ahead of farther flexible dates;
- preferred target = 6, hard minimum target = 4;
- if fewer than 4 verified results remain, the engine returns an explicit insufficient-results error rather than mock flights.

## Pricing boundary

The WebKit bots may observe a fare because it is public information shown by the airline/aggregator, but the customer UI must never display that component fare. A candidate must pass through the server-side Package Engine before becoming a public `FlightOffer`.

`Backend/PackageEngine` is the server-side pricing core. It is ported from the current iumrah Web rules and never returns internal cost components or margin to iOS.
