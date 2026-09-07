import assert from 'node:assert/strict';
import fs from 'node:fs';

const root = new URL('../../../', import.meta.url);
const trip = fs.readFileSync(new URL('Sources/Models/TripModels.swift', root), 'utf8');
const planner = fs.readFileSync(new URL('Sources/Core/TripStayPlanner.swift', root), 'utf8');
const coordinator = fs.readFileSync(new URL('Sources/Services/RealFlightPackageSearchService.swift', root), 'utf8');
const journey = fs.readFileSync(new URL('Sources/State/JourneyStore.swift', root), 'utf8');
const hotelModels = fs.readFileSync(new URL('Sources/Models/HotelModels.swift', root), 'utf8');

// Hotel stay still follows the actual Saudi arrival day selected from Ignav.
assert.match(trip, /var saudiArrivalDate:\s*Date\?/);
assert.match(trip, /var hotelStayStartDate:\s*Date \{ saudiArrivalDate \?\? departureDate \}/);
assert.match(planner, /trip\.hotelStayStartDate/);
assert.match(journey, /trip\.saudiArrivalDate = selectedArrivalDay/);

// Price itself comes from the Business-maintained catalog cache. Freshness is diagnostic; the last accepted D1 rate remains a package fallback.
assert.match(hotelModels, /struct HotelCatalogPrice/);
assert.match(hotelModels, /var isUsableForPackage: Bool/);
assert.match(hotelModels, /case "fresh", "stale", "manual"/);
assert.match(coordinator, /catalogPrice\(for: makkahHotel/);
assert.match(coordinator, /hotelCatalogService\.hotelDetail/);
assert.match(coordinator, /unit: \.perRoomNight/);
assert.match(coordinator, /currency: "USD"/);
assert.ok(!coordinator.includes('HotelPriceBotRunner'));
assert.ok(!coordinator.includes('HotelLivePriceSearchService'));

// Final package fails closed only when the catalog has no accepted non-zero rate.
assert.match(journey, /throw LocalPricingError\.missingHotelPrice\(city\)/);
assert.match(journey, /nightlyUsd >= 15/);
assert.match(journey, /nightlyUsd <= 10_000/);

console.log('arrival-aware last-known hotel catalog pricing contract OK');
