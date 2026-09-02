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
const flightRows = fs.readFileSync(new URL('Sources/Views/Flights/FlightSearchProgressComponents.swift', root), 'utf8');
const flightModels = fs.readFileSync(new URL('Sources/Models/FlightModels.swift', root), 'utf8');
const outbound = fs.readFileSync(new URL('Sources/Views/Flights/OutboundFlightView.swift', root), 'utf8');
const inbound = fs.readFileSync(new URL('Sources/Views/Flights/ReturnFlightView.swift', root), 'utf8');
const bookingService = fs.readFileSync(new URL('Sources/Services/BookingService.swift', root), 'utf8');
const bookingStore = fs.readFileSync(new URL('Sources/State/BookingStore.swift', root), 'utf8');

// Hotel lookup is retryable and never negative-cached.
assert.match(hotelService, /forceRefresh:\s*Bool\s*=\s*false/);
assert.match(hotelService, /if isComplete \{\s*cache\[key\]/s);
assert.match(hotelService, /let isComplete = !snapshot\.makkah\.isEmpty/);
assert.match(hotelService, /fetchPricingSources\(hotelID: makkahHotel\.id\)/);
assert.match(hotelService, /inFlight:\s*\[String:\s*Task<HotelPriceSearchSnapshot, Never>\]/);
assert.match(hotelService, /if let existing = inFlight\[key\]/);
assert.match(hotelBot, /CGRect\(x: 0, y: 0, width: 390, height: 844\)/);
assert.match(hotelBot, /sourceIdentity: request\.pricingSource\(for: provider\.id\)/);
assert.match(hotelBotScripts, /const dateEvidence = hasRequestedDate\(expectedCheckIn\) && hasRequestedDate\(expectedCheckOut\)/);
assert.match(hotelBot, /card\.score >= 0\.62, card\.dateEvidence/);

// Room category does not drive provider cost. Booking is primary, Expedia is fallback.
assert.match(hotelService, /let requestedRooms = max\(1, trip\.rooms\)/);
assert.ok(!hotelService.includes('resolvedRoomCount('));
assert.match(hotelService, /provider\(\.booking\)/);
assert.match(hotelService, /provider\(\.expedia\)/);
assert.match(hotelService, /if makkahValue == nil/);
assert.match(hotelService, /if madinahValue == nil/);
assert.match(hotelProvider, /func provider\(_ id: HotelPriceProviderID\)/);

// Every scraped provider price is normalized once to a total-stay amount.
assert.match(hotelBot, /let totalStayAmount: Decimal/);
assert.match(hotelBot, /case \.perRoomNight:/);
assert.match(hotelBot, /unit: \.totalStay/);
assert.match(hotelParser, /containsPerNightContext\(preferredLower\)/);
assert.ok(!hotelParser.includes('containsPerNightContext(lower)'));
assert.match(journey, /let effectiveRooms = max\(1, trip\.rooms\)/);

// Hotel lookup starts beside flight discovery and is reused by final pricing.
assert.match(journey, /func scheduleHotelPricePrefetch\(forceRefresh: Bool = false\)/);
assert.match(journey, /hotelPricePrefetchTask = Task/);
assert.match(outbound, /journey\.scheduleHotelPricePrefetch\(\)/);
assert.ok(outbound.indexOf('journey.scheduleHotelPricePrefetch()') < outbound.indexOf('searchOutboundProgressive('));

// Round trip = two independent one-way searches and two independently selected fares.
assert.match(coordinator, /makeOneWayRequest\(\s*origin: trip\.originCode,\s*destination: trip\.outboundDestinationCode/s);
assert.match(coordinator, /makeOneWayRequest\(\s*origin: trip\.returnOriginCode,\s*destination: trip\.originCode/s);
assert.match(coordinator, /inboundOrigin: nil/);
assert.ok(!coordinator.includes('pairedInbound('));
assert.ok(!coordinator.includes('pairedOutbound('));
assert.ok(!journey.includes('chooseFlightJourney('));
assert.match(outbound, /journey\.chooseOutboundFlight\(offer\)/);
assert.match(outbound, /ReturnFlightView\(\)/);
assert.match(inbound, /journey\.chooseInboundFlight\(offer\)/);

// Preserve every distinct provider itinerary; no prefix/limit/physical-leg collapse.
assert.match(coordinator, /seenResults\.insert\(journeyResultKey\(journey\)\)/);
assert.ok(coordinator.includes('let resultKey = journeyResultKey(journey)'));
assert.match(coordinator, /id: "fare:/);
assert.match(flightModels, /let fare = fareAmount\.map/);
assert.ok(!coordinator.includes('.prefix('));
assert.ok(!coordinator.includes('cheapestUniqueOffers('));
assert.match(flightRows, /id: offer\.resultIdentityKey/);
for (const source of [outbound, inbound]) {
  assert.match(source, /indexByKey\[offer\.resultIdentityKey\]/);
}

// Supplier flight cost is exactly outbound + inbound when round-trip.
assert.match(localPricing, /outboundFareUsd:/);
assert.match(localPricing, /inboundFareUsd:/);
assert.match(localPricing, /let flights = outboundFlights \+ inboundFlights/);
assert.match(localPricing, /code: "flight_outbound"/);
assert.match(localPricing, /code: "flight_inbound"/);
assert.match(localPricing, /journeyFare: nil/);
assert.match(localPricing, /outbound: fareInput/);
assert.match(localPricing, /inbound: trip\.isRoundTripFlight/);

// Preserve existing commercial policy and untouched service rates.
assert.match(localPricing, /packageMarkupRate\s*=\s*Decimal\(string:\s*"0\.50"\)!/);
assert.match(localPricing, /baseSelling\s*=\s*totalCost\s*\+\s*totalCost\s*\*\s*packageMarkupRate/);
assert.match(localPricing, /calculatedSelling\s*=\s*baseSelling\s*\/\s*\(1\s*-\s*paymentFeeRate\)/);
assert.match(localPricing, /case \.comfort:\s*return 50/);
assert.match(localPricing, /case \.luxury:\s*return 100/);
assert.match(localPricing, /roadWithMadinahPerSedanUsd = Decimal\(300\)/);
assert.match(localPricing, /localWithTrainPerSedanUsd = Decimal\(200\)/);

// Failed hotel lookup can be retried without re-running flight discovery.
assert.match(finalView, /recalculatePrice\(forceHotelRefresh:\s*true\)/);

// Exact component report is explicitly synchronized into iumrah Business.
assert.match(localPricing, /GeneratorPricingSnapshot/);
assert.match(localPricing, /local-independent-flights-v4/);
assert.match(localPricing, /supplierCostUsd:\s*totalCost/);
assert.match(bookingService, /func syncGeneratorReport/);
assert.match(bookingService, /pricingSnapshot:\s*GeneratorPricingSnapshot\?/);
assert.match(bookingStore, /syncGeneratorReportWithRetry/);
assert.match(bookingStore, /bookingService\.syncGeneratorReport/);
assert.match(bookingStore, /Task\.sleep/);
assert.match(bookingStore, /pricingSnapshot: payload\.booking\.pricingSnapshot/);

console.log('independent flights + normalized hotel pricing + Business audit contract OK');
