# iumrah Beta

Native iOS beta client for the iumrah package generator.

## Current bootstrap

- SwiftUI native app, iOS 17+
- Real public hotel catalog from `https://iumrah.app/api/catalog/hotels`
- Trip builder: origin, dates, flexibility, travelers, rooms, hotel stars, package tier
- Primary-hotel flow with a replace-hotel path
- Outbound + return flight selection architecture
- Package total is shown as one total only; hotel/flight component costs are never shown
- Flight search and final quote currently use isolated beta adapters until the real backend bot/quote endpoints are connected

## Generate Xcode project

```bash
xcodegen generate
open iumrahBeta.xcodeproj
```

The repository intentionally keeps generated `.xcodeproj` files out of git. CI should install XcodeGen before building.
