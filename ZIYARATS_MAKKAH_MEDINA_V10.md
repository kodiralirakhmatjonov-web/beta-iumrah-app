# iumrah Ziyarats — Makkah + Madinah v10

This patch contains only changed Ziyarats paths.

- Adds Makkah/Madinah switcher to the top map chrome.
- iOS 26 uses the native Liquid Glass API on the city switcher: `.glassEffect(.regular.interactive(true), in: Capsule())`.
- Switching city reloads the matching Cloudflare Ziyarats catalog and route.
- Place gallery has no 5-image client cap.
