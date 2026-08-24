# iumrah Package Engine — beta 0.6

Server-side pricing boundary for `com.iumrah.beta`.

The iOS app may send raw observed flight fare/currency to this Worker, but the Worker never returns component prices, normalized flight costs, hotel base cost, markup or profit. Public responses contain package totals only.

## Required binding

Bind `HOTELS_DB` to the existing `iumrah-hotels` D1 database and apply `migrations/0001_primary_hotels.sql` to that database.

Primary-hotel rows are maintained manually by iumrah Business / admin logic and contain the internal base hotel price used by the Package Engine.

## FX

`src/fx.ts` reads the official Central Bank of Uzbekistan JSON exchange-rate feed and converts supported source currencies through UZS to USD. The in-memory rate table is cached for 15 minutes per warm Worker isolate.

Override URL with `CBU_FX_URL` if required. Default:

`https://cbu.uz/en/arkhiv-kursov-valyut/json/`

## Public routes

- `GET /api/package/health`
- `GET /api/package/primary-hotel?tier=standard&stars=4&city=Makkah`
- `POST /api/package/quote`
- `POST /api/package/flight-options/quote`

## Flight option quoting

Outbound phase receives multiple outbound and return fare observations. The Worker chooses the lowest normalized return fare as the reference return and quotes each outbound candidate as a complete Umrah package.

Return phase receives the exact selected outbound candidate and quotes every return candidate against it. The iOS client receives only `candidateId`, `quoteId`, `pricePerPerson`, `totalPackagePrice`, currency and operational counts.
