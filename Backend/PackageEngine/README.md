# iumrah Beta Package Engine

Production flight integration uses Ignav. Production hotel pricing uses the shared iumrah Hotels catalog maintained by iumrah Business.

## Responsibilities

- Resolve recommended Primary Hotels from the shared `primary_hotels` table.
- Only resolve hotels whose `hotel_price_cache` row is `fresh`, has a normalized USD room-night rate, and has not expired.
- Proxy independent one-way flight searches to Ignav through `POST /api/package/flights/search`.
- Normalize and validate all returned Ignav itineraries without truncating valid provider results.
- Keep package pricing in the iOS `LocalPackagePricingEngine` so the same selected outbound/inbound fares and the same hotel catalog rate produce the user-visible quote and Business audit snapshot.

## Hotel price architecture

Booking/Expedia price extraction and the 48-hour refresh lifecycle belong to iumrah Business / HotelsWorker. Beta does not open Booking or Expedia and does not run on-device hotel price bots.

Public catalog hotel responses contain a fresh normalized `price.nightlyUSD` value. The client scales that room-night benchmark by the actual number of trip rooms and the actual Makkah/Madinah stay nights. If the cache expires, the hotel is not generator-eligible until iumrah Business refreshes it.

## Flight architecture

A round trip is two explicit independent one-way searches and selections: outbound and return. Ignav's fare for each request is treated according to its declared fare scope. No hidden paired itinerary is copied across the two screens.
