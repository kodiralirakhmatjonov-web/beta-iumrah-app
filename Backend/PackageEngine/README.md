# iumrah Package Engine

Production hotel pricing comes from the shared iumrah Hotels catalog maintained by iumrah Business. Production flight discovery uses one complete round-trip/open-jaw provider itinerary per fare and exposes a sequential customer UX: choose the outbound leg first, then choose a compatible return leg from the same complete itinerary inventory.

## Responsibilities

- Resolve recommended Primary Hotels from the shared `primary_hotels` table.
- Resolve hotels from a positive Business-approved room-night rate: a manual override first, otherwise the last accepted `hotel_price_cache` value. Provider refresh lateness must not block package generation.
- Proxy complete flight searches through `POST /api/package/flights/search`.
- Normalize and validate every returned itinerary without truncating valid results.
- Cache an exact normalized provider search in D1 for 12 hours so identical searches do not spend another provider request while the cache is fresh.
- Accumulate one compact calendar fare observation per route/date/passenger/cabin signature and expose it through `GET /api/package/flights/calendar` without making a provider request.
- Purge expired exact-search payloads and all past-date calendar rows automatically through the Worker cron.
- Own the confidential package-pricing motor on Cloudflare: re-resolve selected flight/hotel inputs from server stores, calculate supplier cost/markup/payment fee, and return only the public price plus an opaque sealed quote proof to clients.
- Do not persist configurator state before booking. After a token-authorized booking exists, attach the immutable pricing report to iumrah Business or queue it in `pending_package_pricing_reports` until the operational trip exists.

## Flight cache architecture

`flight_search_cache` stores the normalized response for the exact broad provider request. UI-only filters (airline, baggage, stop count, time window and display price limit) are intentionally not part of the paid upstream request; the client filters the broad returned inventory locally. This means changing those UI filters can reuse the same D1 response.

Exact search payloads are considered fresh for 12 hours. They are deleted after expiry by scheduled cleanup, so large itinerary JSON does not accumulate until travel day.

`flight_calendar_fares` is intentionally much smaller. Each successful real search records the latest minimum complete-itinerary fare for its exact outbound/return date pair, passenger signature and cabin. These rows remain available until the outbound date passes, allowing the customer date calendar to fill progressively from real searches without proactively buying calendar API requests.

The calendar endpoint never calls the upstream flight provider. It only reads D1.

## Hotel price architecture

Booking/Expedia price extraction and the 48-hour refresh lifecycle belong to iumrah Business / HotelsWorker. Beta does not open Booking or Expedia and does not run on-device hotel price bots.

Public catalog hotel responses contain the Business-approved normalized `price.nightlyUSD` value. The client scales that room-night benchmark by the actual number of trip rooms and the actual Makkah/Madinah stay nights. A late/failed source refresh keeps the last accepted value usable as fallback; a manual Business override is authoritative until Business replaces it.


## Server-owned package pricing

`POST /api/package/quote` is stateless with respect to customer package drafts: it reads verified D1 catalog/cache data, calculates in Worker memory, and returns only public totals plus an AES-GCM `quoteProof`. Supplier costs, markup, payment fee, rounding and profit never enter the iOS/Android/Web response.

After `POST /api/bookings` succeeds, the client submits the opaque proof to `POST /api/package/quote/commit/:bookingID` using the booking token. PackageEngine verifies that the booking totals, tier, travelers and selected hotel IDs match the sealed server snapshot. If the Business `pilgrim_trips` row already exists, the immutable pricing report is written there. If Business is still materializing the trip, the same report is stored in `pending_package_pricing_reports` and Business consumes it when the trip appears. No configurator component rows are created before booking.

`PACKAGE_QUOTE_SEAL_KEY` is the dedicated 32-byte base64url Worker secret for production. The production GitHub deploy workflow requires it and verifies `quoteSealingMode: "dedicated"` before reporting success. The Worker still supports a derived `IGNAV_API_KEY` compatibility key for local/legacy environments only; production must not rely on that fallback.
