# iumrah Package Engine — beta 0.7

Server-side pricing boundary for `com.iumrah.beta`.

This Worker is deployed on `iumrah.app` but uses the **existing** Cloudflare D1 database `iumrah-hotels`. The deployment workflow refuses to create a second D1 database.

## Routes

Public consumer routes:

- `GET /api/package/health`
- `GET /api/package/primary-hotel?tier=standard&stars=4&city=Makkah`
- `POST /api/package/quote`
- `POST /api/package/flight-options/quote`

Admin routes (same staff cookie/auth source as iumrah Business):

- `GET /api/admin/package/primary-hotels`
- `PUT /api/admin/package/primary-hotels`
- `DELETE /api/admin/package/primary-hotels?tier=standard&stars=4&city=Makkah`

The admin response may contain internal base hotel prices. Public consumer responses never return hotel cost, flight cost, FX-normalized cost, markup or profit.

## Primary Hotel configuration

Each `Package Tier × Stars × City` has one active Primary Hotel configuration in `package_primary_hotels`.

Example admin request body:

```json
{
  "tier": "standard",
  "stars": 4,
  "city": "Makkah",
  "hotelId": "existing-hotel-id",
  "roomId": null,
  "basePriceUsd": 55,
  "priceUnit": "perRoomNight",
  "active": true
}
```

The Worker validates that the hotel exists in `iumrah-hotels`, is published, is in the requested city, and matches the configured star level.

## Deployment

The repository workflow `deploy-package-engine.yml` resolves the existing `iumrah-hotels` D1 by name, applies the Package Engine schema idempotently to that database without altering the Hotels Worker migration history, deploys only `/api/package*` and `/api/admin/package*`, then checks `https://iumrah.app/api/package/health`.

Required GitHub secrets:

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_ZONE_ID`

The same Cloudflare token permissions used by the existing Hotels Cloud deployment are sufficient for this Worker except R2 access is not required.
