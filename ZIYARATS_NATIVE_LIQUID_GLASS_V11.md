# iumrah Ziyarats — Native Liquid Glass v11

Strict Liquid Glass correction.

- iOS 26 floating/navigation chrome uses only Apple-native SwiftUI Liquid Glass APIs:
  - `glassEffect`
  - `GlassEffectContainer`
  - `.buttonStyle(.glass)`
- Removed every `.regularMaterial` fallback from Ziyarats.
- Removed the manual glass-like border and shadow from the main Find My-style surface.
- Pre-iOS 26 fallback is deliberately opaque `systemBackground`; it does not imitate Liquid Glass.
- Ordinary content cards remain opaque surfaces; Liquid Glass is reserved for floating/navigation chrome.
- Makkah / Madinah switch remains one native interactive glass surface, not a manually blurred capsule.
- Close button remains a system SF Symbol button with `.buttonStyle(.glass)` and `.buttonBorderShape(.circle)` on iOS 26.
- Top chrome is grouped in `GlassEffectContainer` so Apple owns compositing/interactions between glass surfaces.

No database/service/model behavior changed from v10.
