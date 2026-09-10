# iumrah Ziyarats — Single Surface v8

Client-only UI correction.

## What changed

- Removed the navigation `TabView` from inside the partial-height sheet.
- The system sheet is now the single Liquid Glass surface for Ziyarats.
- The four destinations (Journey / Places / Route / Map) are laid directly on the sheet surface; there is no second glass/tab-bar container.
- Compact detent is the navigation panel itself; no nested pill or second rounded layer.
- The drag indicator is hidden in compact state and shown in card/large states.
- Returned sheet gesture handling to the system default; no custom presentation-content gesture priority.
- Place detail no longer draws its own circular X button. The close action is a native navigation-toolbar item, letting iOS 26 render the button treatment.
- Added consistent top/bottom content margins so headers and cards do not touch the sheet ceiling or bottom navigation.
- Top map close action remains an iOS 26 `.glass` button.
- Right-side map controls now share one native `.glassEffect(.regular, ...)` surface instead of two separate glass circles.

## Intentionally unchanged

- MapKit map, exact coordinates, routes, pins, Cloudflare catalog, localization, image gallery/data model.
- The `TabView` still used inside the photo gallery is only a page-style image pager and is not navigation chrome.

## Deployment

Overlay the ZIP at repository root using the existing update workflow. No Business/Cloudflare deploy is required for this client-only UI correction.
