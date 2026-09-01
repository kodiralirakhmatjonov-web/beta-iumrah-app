# iumrah Package Engine

Cleanup baseline before the unified Ignav flight integration.

## Active responsibilities

- Resolve recommended Primary Hotels from the shared `primary_hotels` table.
- Expose hotel room categories required by the iOS generator/booking flow.
- Keep existing booking contact/customization/hotel maintenance routes.
- Health-check the existing HOTELS_DB / BOOKINGS_DB bindings.

## Explicitly not handled here

- Airline scraping/bots or WKWebView flight automation.
- Flight SearchSession/Durable Object jobs.
- Flight fare discovery or server flight quote calculation.
- Consumer final package pricing.
- `package_primary_hotels` configured-rate pricing.

The iOS app owns the existing `LocalPackagePricingEngine`. Current prices for the selected Makkah/Madinah Primary Hotels are verified by the app's `HotelLivePriceSearchService` for the actual trip dates, guests and room/category.

The next flight implementation should add one Ignav-backed adapter behind `FlightInventoryProviding`. No Ignav key or endpoint is included in cleanup update 013.
