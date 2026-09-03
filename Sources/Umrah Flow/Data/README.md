# Umrah Flow data snapshot

Runtime source remains Supabase.

- `translations2_rows.csv` contains only translation rows used by the migrated Umrah Flow. It was extracted from the supplied `translations_rows(1).csv` export. The source export currently contains: `ar`, `en`, `fr`, `id`, `kk`, `ms`, `ru`, `tr`, `uz`.
- `audio_urls_rows.csv` is the supplied Umrah audio URL export. It contains the 20 Umrah audio keys and languages: `ar`, `bn`, `en`, `id`, `kk`, `ms`, `ru`, `tr`, `uz`.
- `safa5_sarab1` does not exist in the supplied translation export; the SwiftUI view intentionally falls back to the non-Arabic Safa text instead of inventing religious copy.

The Swift client first tries the isolated Supabase table `translations2`, then transparently falls back to the existing `translations` table until `translations2` is created/imported.
