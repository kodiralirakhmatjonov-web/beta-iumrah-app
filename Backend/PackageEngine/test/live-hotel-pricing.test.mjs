import assert from 'node:assert/strict';
import fs from 'node:fs';

const root = new URL('../../../', import.meta.url);
const trip = fs.readFileSync(new URL('Sources/Models/TripModels.swift', root), 'utf8');
const planner = fs.readFileSync(new URL('Sources/Core/TripStayPlanner.swift', root), 'utf8');
const journey = fs.readFileSync(new URL('Sources/State/JourneyStore.swift', root), 'utf8');
const hotelCosts = fs.readFileSync(new URL('Backend/PackageEngine/src/hotel-costs.ts', root), 'utf8');
const packageSearch = fs.readFileSync(new URL('Backend/PackageEngine/src/package-search.ts', root), 'utf8');

assert.match(trip, /var saudiArrivalDate:\s*Date\?/);
assert.match(trip, /var hotelStayStartDate:\s*Date \{ saudiArrivalDate \?\? departureDate \}/);
assert.match(planner, /trip\.hotelStayStartDate/);
assert.match(journey, /trip\.saudiArrivalDate = selectedArrivalDay/);

// Authoritative hotel pricing moved behind Cloudflare: the client sends only IDs/nights.
assert.match(hotelCosts, /resolveServerHotelPricing/);
assert.match(hotelCosts, /SELECT/);
assert.match(hotelCosts, /nightly_usd|nightlyUSD/i);
assert.match(hotelCosts, /HOTEL_PRICE_UNAVAILABLE/);
assert.match(packageSearch, /resolveServerHotelPricing\(env\.HOTELS_DB/);
assert.match(journey, /packageEngine\.packageQuote\(/);
assert.doesNotMatch(journey, /LocalPackagePricingEngine\.calculate/);

console.log('arrival-aware server-owned hotel pricing contract OK');
