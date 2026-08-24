# iumrah Package Engine — beta 0.5

Server-side pricing kernel ported from the existing `iumrah-web` pricing architecture.

## Preserved pricing rules

- 50% package markup;
- 2% payment-fee gross-up;
- public rounding to the nearest $5 per person;
- visa: $120 per traveller;
- meals by Economy / Standard / Comfort / Luxury tier;
- transfer capacity: 3 travellers per sedan;
- Makkah-only vs Makkah+Madinah transfer/guide rules;
- Makkah/Madinah ziyarat group costs;
- rooms: minimum 1 room per 4 adults+children, while respecting the user's selected room count.

## New mobile architecture

Outbound and inbound flight costs are separate inputs. Primary Hotel pricing is resolved server-side from the existing `iumrah-hotels` D1 database through `package_primary_hotels`.

Run `migrations/0001_primary_hotels.sql` against the existing hotel D1 database. Do **not** create a second hotel catalog database.

The mapping key is:

`package tier × star class × city -> Primary Hotel + internal base price`

This supports Economy/Standard/Comfort/Luxury across 1–5★ and separate Makkah/Madinah assignments.

## Privacy boundary

The public consumer response contains only:

- final package price per person;
- final group package price;
- currency;
- quote/version identifiers;
- resolved room/vehicle counts.

It never exposes hotel cost, flight cost, markup, payment fee or estimated profit. The public Primary Hotel endpoint also omits its internal base price.
