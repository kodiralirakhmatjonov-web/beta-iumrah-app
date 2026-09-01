import assert from 'node:assert/strict';
import fs from 'node:fs';

const root = new URL('../../../', import.meta.url);
const service = fs.readFileSync(new URL('Sources/HotelPricing/HotelLivePriceSearchService.swift', root), 'utf8');
const bot = fs.readFileSync(new URL('Sources/HotelPricing/HotelPriceBotRunner.swift', root), 'utf8');
const trip = fs.readFileSync(new URL('Sources/Models/TripModels.swift', root), 'utf8');
const planner = fs.readFileSync(new URL('Sources/Core/TripStayPlanner.swift', root), 'utf8');
const coordinator = fs.readFileSync(new URL('Sources/Services/RealFlightPackageSearchService.swift', root), 'utf8');
const journey = fs.readFileSync(new URL('Sources/State/JourneyStore.swift', root), 'utf8');

// Hotel dates start from the actual Saudi arrival calendar day, not origin departure day.
assert.match(trip, /var saudiArrivalDate:\s*Date\?/);
assert.match(trip, /var hotelStayStartDate:\s*Date \{ saudiArrivalDate \?\? departureDate \}/);
assert.match(planner, /trip\.hotelStayStartDate/);
assert.match(journey, /trip\.saudiArrivalDate = selectedArrivalDay/);
assert.match(journey, /travelCalendarDay\(for: offer\.arrivalAt, airportCode: offer\.destination\)/);

// Hotel lookup is performed after a real outbound is selected, so the arrival day is known.
assert.ok(!coordinator.includes('startHotelPriceCheck('));

// Current-price lookup stays tied to hotel/stay/occupancy and Primary Room capacity.
assert.match(service, /TripStayPlanner\.windows\(for: trip/);
assert.match(service, /makkahRoomCapacity/);
assert.match(service, /madinahRoomCapacity/);
assert.match(service, /selectedRoomId: makkahRoomId/);
assert.match(service, /selectedRoomId: madinahRoomId/);
assert.match(service, /pricingSources: makkahPricingSources/);
assert.match(service, /pricingSources: madinahPricingSources/);

// Business-maintained provider identities are used as a strong hotel match signal.
assert.match(service, /packageEngine\.hotelPricingSources/);
assert.match(bot, /request\.pricingSource\(for: provider\.id\)/);

// Makkah and Madinah can be checked concurrently for each provider.
assert.match(service, /async let makkahValue/);
assert.match(service, /async let madinahValue/);

// Missing current hotel price fails closed; no estimated package_primary_hotels rate is substituted.
assert.match(journey, /throw LocalPricingError\.missingHotelPrice\(city\)/);
assert.ok(!journey.includes('configuredHotelComponentPrice('));
console.log('arrival-aware live hotel pricing contract OK');
