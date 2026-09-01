# iumrah Beta iOS

Native SwiftUI client for the iumrah self-Umrah platform.

## Generator architecture after cleanup 013

1. User defines route, dates, travelers, hotel stars and comfort level.
2. iumrah resolves Makkah Primary Hotel, and Madinah Primary Hotel when required, from the shared `primary_hotels` recommendation layer.
3. Generator starts two independent operations in parallel:
   - unified flight inventory (`FlightInventoryProviding`), intentionally unconfigured until the next Ignav update;
   - live current-price verification for the selected Primary Hotel stay(s).
4. Outbound and return flight choices flow through provider-neutral flight DTOs.
5. Existing `LocalPackagePricingEngine` builds the final consumer package price after verified flight fares and hotel costs are available.
6. Existing Booking and eSIM paths remain separate and unchanged by this cleanup.

Airline-specific server bots, device/WKWebView flight bots, flight SearchSession/Durable Objects and server package pricing are not part of the active architecture.
