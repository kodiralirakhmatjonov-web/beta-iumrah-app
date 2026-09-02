import assert from 'node:assert/strict';
import fs from 'node:fs';

const root = new URL('../../../', import.meta.url);
const hotelService = fs.readFileSync(new URL('Sources/HotelPricing/HotelLivePriceSearchService.swift', root), 'utf8');
const hotelBot = fs.readFileSync(new URL('Sources/HotelPricing/HotelPriceBotRunner.swift', root), 'utf8');
const hotelBotScripts = fs.readFileSync(new URL('Sources/HotelPricing/HotelPriceBotScripts.swift', root), 'utf8');
const hotelProvider = fs.readFileSync(new URL('Sources/HotelPricing/HotelPriceProvider.swift', root), 'utf8');
const hotelParser = fs.readFileSync(new URL('Sources/HotelPricing/HotelPriceTextParser.swift', root), 'utf8');
const localPricing = fs.readFileSync(new URL('Sources/Services/LocalPackagePricingEngine.swift', root), 'utf8');
const coordinator = fs.readFileSync(new URL('Sources/Services/RealFlightPackageSearchService.swift', root), 'utf8');
const journey = fs.readFileSync(new URL('Sources/State/JourneyStore.swift', root), 'utf8');
const finalView = fs.readFileSync(new URL('Sources/Views/Package/FinalPackageView.swift', root), 'utf8');
const flightCard = fs.readFileSync(new URL('Sources/Views/Components/FlightCard.swift', root), 'utf8');
const flightRows = fs.readFileSync(new URL('Sources/Views/Flights/FlightSearchProgressComponents.swift', root), 'utf8');
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
assert.match(hotelService, /inFlight:\s*\[String:\s*Task<HotelPriceSearchSnapshot, Never>\]/);
assert.match(hotelService, /if let existing = inFlight\[key\]/);
assert.match(hotelProvider, /func searchURLs\(for request: HotelPriceSearchRequest\)/);
assert.match(hotelProvider, /identity\.canonicalURL \?\? identity\.sourceURL/);
assert.match(hotelProvider, /set\("checkin", checkIn\)/);
assert.match(hotelProvider, /set\("chkin", checkIn\)/);
assert.match(hotelBotScripts, /const dateEvidence = hasRequestedDate\(expectedCheckIn\) && hasRequestedDate\(expectedCheckOut\)/);
assert.match(hotelBot, /card\.score >= 0\.62, card\.dateEvidence/);
assert.match(hotelParser, /priceValues\.min\(by:/);
assert.match(coordinator, /isCompleteHotelSnapshot/);
assert.match(coordinator, /hotelPriceService\.invalidateAll\(\)/);

// Hotel lookup starts beside flight discovery and is reused by final pricing.
assert.match(journey, /func scheduleHotelPricePrefetch\(forceRefresh: Bool = false\)/);
assert.match(journey, /hotelPricePrefetchTask = Task/);
assert.match(outbound, /journey\.scheduleHotelPricePrefetch\(\)/);
assert.ok(outbound.indexOf('journey.scheduleHotelPricePrefetch()') < outbound.indexOf('searchOutboundProgressive('));

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

// Preserve every valid upstream itinerary instead of collapsing results that
// happen to share the same physical outbound or return leg.
assert.match(coordinator, /private func allJourneyOffers/);
assert.ok(!coordinator.includes('cheapestUniqueOffers('));
assert.match(coordinator, /seen\.insert\(value\.resultIdentityKey\)/);
assert.match(flightRows, /id: offer\.resultIdentityKey/);
for (const source of [outbound, inbound]) {
  assert.match(source, /indexByKey\[offer\.resultIdentityKey\]/);
  assert.match(source, /Current journeys found|Compatible current journeys/);
}
assert.match(coordinator, /func pairedOutbound\(for inbound: FlightOffer\)/);
assert.match(journey, /pairedOutbound\(for: offer\)/);
assert.match(flightCard, /pairedReturnRow\(paired\)/);

console.log('production journey + hotel pricing contract OK');
