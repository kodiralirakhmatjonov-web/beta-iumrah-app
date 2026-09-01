import assert from 'node:assert/strict';
import fs from 'node:fs';

const service = fs.readFileSync(new URL('../../../Sources/HotelPricing/HotelLivePriceSearchService.swift', import.meta.url), 'utf8');
const coordinator = fs.readFileSync(new URL('../../../Sources/Services/RealFlightPackageSearchService.swift', import.meta.url), 'utf8');
const journey = fs.readFileSync(new URL('../../../Sources/State/JourneyStore.swift', import.meta.url), 'utf8');

// Live hotel verification remains and is keyed to actual itinerary + selected room/category.
assert.match(service, /TripStayPlanner\.windows\(for: trip/);
assert.match(service, /selectedRoomId: makkahRoomId/);
assert.match(service, /selectedRoomName: makkahRoomName/);
assert.match(service, /selectedRoomId: madinahRoomId/);
assert.match(service, /selectedRoomName: madinahRoomName/);

// Makkah and Madinah are checked concurrently when both are required.
assert.match(service, /async let makkahValue/);
assert.match(service, /async let madinahValue/);

// Hotel verification starts before the unified flight provider is awaited.
const hotelStart = coordinator.indexOf('startHotelPriceCheck(trip: trip');
const flightAwait = coordinator.indexOf('try await flightProvider.search');
assert.ok(hotelStart >= 0 && flightAwait > hotelStart, 'hotel verification must start in parallel before flight provider await');

// Final local pricing refuses a missing live hotel price; it must not use package_primary_hotels.
assert.match(journey, /throw LocalPricingError\.missingHotelPrice\(city\)/);
assert.ok(!journey.includes('configuredHotelComponentPrice('));
console.log('live hotel verification contract OK');
