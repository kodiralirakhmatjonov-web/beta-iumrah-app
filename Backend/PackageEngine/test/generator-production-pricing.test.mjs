import assert from 'node:assert/strict';
import fs from 'node:fs';

const root = new URL('../../../', import.meta.url);
const hotelService = fs.readFileSync(new URL('Sources/HotelPricing/HotelLivePriceSearchService.swift', root), 'utf8');
const hotelBot = fs.readFileSync(new URL('Sources/HotelPricing/HotelPriceBotRunner.swift', root), 'utf8');
const localPricing = fs.readFileSync(new URL('Sources/Services/LocalPackagePricingEngine.swift', root), 'utf8');
const coordinator = fs.readFileSync(new URL('Sources/Services/RealFlightPackageSearchService.swift', root), 'utf8');
const journey = fs.readFileSync(new URL('Sources/State/JourneyStore.swift', root), 'utf8');
const finalView = fs.readFileSync(new URL('Sources/Views/Package/FinalPackageView.swift', root), 'utf8');
const flightCard = fs.readFileSync(new URL('Sources/Views/Components/FlightCard.swift', root), 'utf8');
const outbound = fs.readFileSync(new URL('Sources/Views/Flights/OutboundFlightView.swift', root), 'utf8');
const inbound = fs.readFileSync(new URL('Sources/Views/Flights/ReturnFlightView.swift', root), 'utf8');

// Current hotel price lookup is retryable, never negative-cached, and room count
// follows the selected Primary Room capacity abstraction.
assert.match(hotelService, /forceRefresh:\s*Bool\s*=\s*false/);
assert.match(hotelService, /if isComplete \{\s*cache\[key\]/s);
assert.match(hotelService, /let isComplete = !snapshot\.makkah\.isEmpty/);
assert.match(hotelService, /resolvedRoomCount\(for: trip, roomCapacity: makkahRoomCapacity\)/);
assert.match(hotelService, /fetchPricingSources\(hotelID: makkahHotel\.id\)/);
assert.match(hotelBot, /CGRect\(x: 0, y: 0, width: 390, height: 844\)/);
assert.match(hotelBot, /sourceIdentity: request\.pricingSource\(for: provider\.id\)/);
assert.match(hotelBot, /roomName:\s*nil/);
assert.match(coordinator, /isCompleteHotelSnapshot/);
assert.match(coordinator, /hotelPriceService\.invalidateAll\(\)/);

// The package consumes one complete journey fare and never sums two one-way fares.
assert.match(journey, /journeyFareUsd:/);
assert.ok(!localPricing.includes('outboundFareUsd'));
assert.ok(!localPricing.includes('inboundFareUsd'));
assert.match(localPricing, /groupFare\(journeyFareUsd/);
assert.match(localPricing, /packageMarkupRate\s*=\s*Decimal\(string:\s*"0\.50"\)!/);
assert.match(localPricing, /baseSelling\s*=\s*totalCost\s*\+\s*totalCost\s*\*\s*packageMarkupRate/);
assert.match(localPricing, /calculatedSelling\s*=\s*baseSelling\s*\/\s*\(1\s*-\s*paymentFeeRate\)/);
assert.match(localPricing, /case \.comfort:\s*return 50/);
assert.match(localPricing, /case \.luxury:\s*return 100/);

// Provider disagreement no longer inflates the hotel component by taking the highest rate.
assert.match(journey, /verified\.min\(by:\s*\{ \$0\.totalUsd < \$1\.totalUsd \}\)/);
assert.ok(!journey.includes('cheapest.totalUsd * Decimal(string: "1.50")! < highest.totalUsd'));
assert.match(journey, /normalizedRoomNightUsd\s*>?=\s*15/);

// A failed initial hotel lookup can be retried without re-running flight search.
assert.match(finalView, /recalculatePrice\(forceHotelRefresh:\s*true\)/);
assert.match(finalView, /Retry price lookup/);

// Fare deltas are now deltas between complete two-leg itineraries.
assert.match(flightCard, /referenceOffer:\s*FlightOffer\?/);
assert.match(flightCard, /current\s*-\s*baseline/);
assert.match(flightCard, /Round-trip price difference/);
assert.match(outbound, /referenceOffer:\s*recommendedOffer/);
assert.match(outbound, /chooseOutboundFlight\(recommendedOffer\)/);
assert.match(inbound, /referenceOffer:\s*recommendedOffer/);
assert.match(inbound, /chooseInboundFlight\(recommendedOffer\)/);

// Recommendation order is complete-trip price first, then stops/duration.
for (const source of [outbound, inbound]) {
  const block = source.slice(source.indexOf('private var recommendedOffer'), source.indexOf('private var recommendedOfferID'));
  assert.ok(block.indexOf('lhs.totalPackagePrice') < block.indexOf('lhs.stops'), 'recommendation must rank complete-trip price before stops');
}

console.log('production journey + hotel pricing contract OK');
