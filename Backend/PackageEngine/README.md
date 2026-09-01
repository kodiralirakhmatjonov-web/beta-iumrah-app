# iumrah Package Engine

Production flight integration baseline using Ignav.

## Active responsibilities

- Resolve recommended Primary Hotels from the shared `primary_hotels` table.
- Expose hotel room categories required by the iOS generator/booking flow.
- Proxy flight fare searches to Ignav through `POST /api/package/flights/search`.
- Keep `IGNAV_API_KEY` only in the Cloudflare Worker secret store.
- Normalize and validate verified Ignav itineraries before they reach the iOS app.
- Keep existing booking contact/customization/hotel maintenance routes.

## Explicitly not handled here

- Airline scraping/bots or WKWebView flight automation.
- Flight SearchSession/Durable Object jobs.
- Consumer final package pricing.
- Configured `package_primary_hotels` pricing.

The iOS app owns the existing `LocalPackagePricingEngine`. Current prices for the selected Makkah/Madinah Primary Hotels are verified by `HotelLivePriceSearchService` for the actual trip dates, guests and room/category. Ignav fare discovery and hotel-price verification start in parallel; the selected outbound and return fares are then passed to the unchanged local package pricing engine.
