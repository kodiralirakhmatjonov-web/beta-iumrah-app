import assert from 'node:assert/strict';
import fs from 'node:fs';

const root = new URL('../../../', import.meta.url);
const hotelModels = fs.readFileSync(new URL('Sources/Models/HotelModels.swift', root), 'utf8');
const localPricing = fs.readFileSync(new URL('Sources/Services/LocalPackagePricingEngine.swift', root), 'utf8');
const coordinator = fs.readFileSync(new URL('Sources/Services/RealFlightPackageSearchService.swift', root), 'utf8');
const ignavClient = fs.readFileSync(new URL('Sources/Services/IgnavFlightInventoryProvider.swift', root), 'utf8');
const ignavWorker = fs.readFileSync(new URL('Backend/PackageEngine/src/ignav-flights.ts', root), 'utf8');
const journey = fs.readFileSync(new URL('Sources/State/JourneyStore.swift', root), 'utf8');
const outbound = fs.readFileSync(new URL('Sources/Views/Flights/OutboundFlightView.swift', root), 'utf8');
const inbound = fs.readFileSync(new URL('Sources/Views/Flights/ReturnFlightView.swift', root), 'utf8');
const flightCard = fs.readFileSync(new URL('Sources/Views/Components/FlightCard.swift', root), 'utf8');
const bookingService = fs.readFileSync(new URL('Sources/Services/BookingService.swift', root), 'utf8');
const bookingStore = fs.readFileSync(new URL('Sources/State/BookingStore.swift', root), 'utf8');

// Hotel source of truth is Business' fresh catalog rate, expressed only as USD / room / night.
assert.match(hotelModels, /let nightlyUSD: Double\?/);
assert.match(hotelModels, /var isFresh: Bool/);
assert.match(coordinator, /price\.nightlyUSD/);
assert.match(coordinator, /unit: \.perRoomNight/);
assert.ok(!coordinator.includes('HotelLivePriceSearchService'));
assert.match(journey, /observations where observation\.unit == \.perRoomNight/);
assert.match(journey, /let effectiveRooms = max\(1, trip\.rooms\)/);
assert.match(localPricing, /nightlyUsd \* Decimal\(max\(1, rooms\)\) \* Decimal\(max\(1, nights\)\)/);
assert.match(localPricing, /unit: "perRoomNight"/);
assert.ok(!localPricing.includes('case .totalStay'));
assert.ok(!localPricing.includes('case .perRoomStay'));

// Roundtrip/open-jaw pricing is one complete Ignav itinerary, not two independent one-way purchases.
assert.match(coordinator, /inboundOrigin: trip\.isRoundTripFlight \? trip\.returnOriginCode : nil/);
assert.match(coordinator, /inboundDestination: trip\.isRoundTripFlight \? trip\.originCode : nil/);
assert.match(coordinator, /returnOffers\(from: cachedJourneys, matching: outbound\)/);
assert.match(coordinator, /fareAmount: journey\.totalFare/);
assert.match(coordinator, /paired: FlightPairedLeg\(candidate: inbound\)/);
assert.ok(!coordinator.includes('makeOneWayRequest('));
assert.match(journey, /pricingOffer = value/);
assert.match(journey, /let journeyFareUsd = try await LocalFXRateService\.shared\.usd\(rawFare/);
assert.match(localPricing, /let flights = try groupFare\(journeyFareUsd/);
assert.match(localPricing, /code: trip\.isRoundTripFlight \? "flight_roundtrip" : "flight_outbound"/);
assert.match(localPricing, /journeyFare: journeyInput/);
assert.match(localPricing, /outbound: nil/);
assert.match(localPricing, /inbound: nil/);
assert.match(localPricing, /local-expedia-package-v6/);

// Only verified provider fares may become package prices.
assert.match(ignavClient, /price\.status\.caseInsensitiveCompare\("verified"\) == \.orderedSame/);
assert.match(ignavWorker, /String\(price\.status \|\| ""\)\.toLowerCase\(\) !== "verified"/);

// Expedia-Packages style consumer hierarchy: delta first, package/person and package total underneath.
assert.match(flightCard, /deltaDisplay/);
assert.match(flightCard, /к пакету \/ 1 человек/);
assert.match(flightCard, /пакет \/ 1 человек/);
assert.match(flightCard, /пакет всего/);
assert.ok(!flightCard.includes('Тариф Ignav'));
assert.ok(!flightCard.includes('Цена билета в одну сторону'));
assert.match(outbound, /packagePricePerPerson: packagePrices\[offer\.id\]/);
assert.match(inbound, /packagePricePerPerson: packagePrices\[offer\.id\]/);
assert.ok(!outbound.includes('waiting-return'));

// Preserve the existing commercial/service policy outside flights and hotels.
assert.match(localPricing, /packageMarkupRate\s*=\s*Decimal\(string:\s*"0\.50"\)!/);
assert.match(localPricing, /paymentFeeRate\s*=\s*Decimal\(string:\s*"0\.02"\)!/);
assert.match(localPricing, /case \.comfort:\s*return 50/);
assert.match(localPricing, /case \.luxury:\s*return 100/);
assert.match(localPricing, /roadWithMadinahPerSedanUsd = Decimal\(300\)/);
assert.match(localPricing, /localWithTrainPerSedanUsd = Decimal\(200\)/);

// Exact component report remains synchronized into iumrah Business.
assert.match(localPricing, /GeneratorPricingSnapshot/);
assert.match(localPricing, /supplierCostUsd:\s*totalCost/);
assert.match(bookingService, /func syncGeneratorReport/);
assert.match(bookingStore, /syncGeneratorReportWithRetry/);
assert.match(bookingStore, /bookingService\.syncGeneratorReport/);

console.log('Expedia-style complete-itinerary flights + exact nightly hotel multiplication contract OK');
