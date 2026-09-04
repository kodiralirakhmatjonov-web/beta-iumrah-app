# iumrah Beta Package Engine

Production hotel pricing comes from the shared iumrah Hotels catalog maintained by iumrah Business. Production flight discovery uses one complete round-trip/open-jaw provider itinerary per fare and exposes a sequential customer UX: choose the outbound leg first, then choose a compatible return leg from the same complete itinerary inventory.

## Responsibilities

- Resolve recommended Primary Hotels from the shared `primary_hotels` table.
- Only resolve hotels whose `hotel_price_cache` row is `fresh`, has a normalized USD room-night rate, and has not expired.
- Proxy complete flight searches through `POST /api/package/flights/search`.
- Normalize and validate every returned itinerary without truncating valid results.
- Cache an exact normalized provider search in D1 for 12 hours so identical searches do not spend another provider request while the cache is fresh.
- Accumulate one compact calendar fare observation per route/date/passenger/cabin signature and expose it through `GET /api/package/flights/calendar` without making a provider request.
- Purge expired exact-search payloads and all past-date calendar rows automatically through the Worker cron.
- Keep package pricing in iOS `LocalPackagePricingEngine`, using the complete journey fare exactly once plus the current hotel catalog room-night rates.

## Flight cache architecture

`flight_search_cache` stores the normalized response for the exact broad provider request. UI-only filters (airline, baggage, stop count, time window and display price limit) are intentionally not part of the paid upstream request; the client filters the broad returned inventory locally. This means changing those UI filters can reuse the same D1 response.

Exact search payloads are considered fresh for 12 hours. They are deleted after expiry by scheduled cleanup, so large itinerary JSON does not accumulate until travel day.

`flight_calendar_fares` is intentionally much smaller. Each successful real search records the latest minimum complete-itinerary fare for its exact outbound/return date pair, passenger signature and cabin. These rows remain available until the outbound date passes, allowing the customer date calendar to fill progressively from real searches without proactively buying calendar API requests.

The calendar endpoint never calls the upstream flight provider. It only reads D1.

## Hotel price architecture

Booking/Expedia price extraction and the 48-hour refresh lifecycle belong to iumrah Business / HotelsWorker. Beta does not open Booking or Expedia and does not run on-device hotel price bots.

Public catalog hotel responses contain a fresh normalized `price.nightlyUSD` value. The client scales that room-night benchmark by the actual number of trip rooms and the actual Makkah/Madinah stay nights. If the cache expires, the hotel is not generator-eligible until iumrah Business refreshes it.
