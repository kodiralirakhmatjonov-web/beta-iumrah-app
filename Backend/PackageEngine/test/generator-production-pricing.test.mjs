import assert from 'node:assert/strict';
import fs from 'node:fs';

const root = new URL('../../../', import.meta.url);
const hotelModels = fs.readFileSync(new URL('Sources/Models/HotelModels.swift', root), 'utf8');
const priceModels = fs.readFileSync(new URL('Sources/HotelPricing/HotelPriceModels.swift', root), 'utf8');
const localPricing = fs.readFileSync(new URL('Sources/Services/LocalPackagePricingEngine.swift', root), 'utf8');
const coordinator = fs.readFileSync(new URL('Sources/Services/RealFlightPackageSearchService.swift', root), 'utf8');
const journey = fs.readFileSync(new URL('Sources/State/JourneyStore.swift', root), 'utf8');
const finalView = fs.readFileSync(new URL('Sources/Views/Package/FinalPackageView.swift', root), 'utf8');
const flightRows = fs.readFileSync(new URL('Sources/Views/Flights/FlightSearchProgressComponents.swift', root), 'utf8');
const flightModels = fs.readFileSync(new URL('Sources/Models/FlightModels.swift', root), 'utf8');
const outbound = fs.readFileSync(new URL('Sources/Views/Flights/OutboundFlightView.swift', root), 'utf8');
const inbound = fs.readFileSync(new URL('Sources/Views/Flights/ReturnFlightView.swift', root), 'utf8');
const flightCard = fs.readFileSync(new URL('Sources/Views/Components/FlightCard.swift', root), 'utf8');
const primaryHotel = fs.readFileSync(new URL('Sources/Views/Hotels/PrimaryHotelView.swift', root), 'utf8');
const hotelCard = fs.readFileSync(new URL('Sources/Views/Components/HotelCard.swift', root), 'utf8');
const bookingService = fs.readFileSync(new URL('Sources/Services/BookingService.swift', root), 'utf8');
const bookingStore = fs.readFileSync(new URL('Sources/State/BookingStore.swift', root), 'utf8');
const project = fs.readFileSync(new URL('project.yml', root), 'utf8');

// Hotel pricing source of truth is the shared server catalog cache, not device scraping.
assert.match(hotelModels, /struct HotelCatalogPrice/);
assert.match(hotelModels, /let nightlyUSD: Double\?/);
assert.match(hotelModels, /let expiresAt: String\?/);
assert.match(hotelModels, /var isFresh: Bool/);
assert.match(hotelModels, /let price: HotelCatalogPrice\?/);
assert.match(coordinator, /private let hotelCatalogService: HotelCatalogServicing/);
assert.match(coordinator, /HotelCatalogService\(\)/);
assert.ok(!coordinator.includes('HotelLivePriceSearchService'));
assert.match(coordinator, /unit: \.perRoomNight/);
assert.match(coordinator, /expiresAt: expiresAt/);
assert.match(coordinator, /iumrah 48h cache/);
assert.match(priceModels, /if let expiresAt/);
assert.match(project, /HotelPricing\/HotelLivePriceSearchService\.swift/);
assert.match(project, /HotelPricing\/HotelPriceBotRunner\.swift/);

// Only hotels with fresh catalog prices can enter the generator.
assert.match(journey, /all\.filter\(\\\.hasFreshCatalogPrice\)/);
assert.match(journey, /guard hotel\.hasFreshCatalogPrice/);
assert.match(primaryHotel, /selectedHotel\?\.hasFreshCatalogPrice == true/);
assert.match(hotelCard, /price\.isFresh/);

// Cached room-night rate scales once by actual rooms and actual stay nights.
assert.match(journey, /let effectiveRooms = max\(1, trip\.rooms\)/);
assert.match(journey, /case \.perRoomNight: totalUsd = usd \* Decimal\(effectiveRooms\) \* Decimal\(max\(1, window\.nights\)\)/);
assert.match(journey, /throw LocalPricingError\.missingHotelPrice\(city\)/);
assert.ok(!journey.includes('configuredHotelComponentPrice('));

// Catalog price warm-up starts beside flight discovery and final retry only rechecks catalog.
assert.match(journey, /func scheduleHotelPricePrefetch\(forceRefresh: Bool = false\)/);
assert.match(outbound, /journey\.scheduleHotelPricePrefetch\(\)/);
assert.ok(outbound.indexOf('journey.scheduleHotelPricePrefetch()') < outbound.indexOf('searchOutboundProgressive('));
assert.match(finalView, /recalculatePrice\(forceHotelRefresh:\s*true\)/);
assert.match(finalView, /каталога iumrah/);

// Round trip = two independent one-way searches and two independently selected fares.
assert.match(coordinator, /makeOneWayRequest\(\s*origin: trip\.originCode,\s*destination: trip\.outboundDestinationCode/s);
assert.match(coordinator, /makeOneWayRequest\(\s*origin: trip\.returnOriginCode,\s*destination: trip\.originCode/s);
assert.match(coordinator, /inboundOrigin: nil/);
assert.ok(!coordinator.includes('pairedInbound('));
assert.ok(!coordinator.includes('pairedOutbound('));
assert.ok(!journey.includes('chooseFlightJourney('));
assert.match(outbound, /journey\.chooseOutboundFlight\(offer\)/);
assert.match(inbound, /journey\.chooseInboundFlight\(offer\)/);

// Preserve every distinct provider itinerary; no prefix/limit/physical-leg collapse.
assert.match(coordinator, /seenResults\.insert\(journeyResultKey\(journey\)\)/);
assert.ok(coordinator.includes('let resultKey = journeyResultKey(journey)'));
assert.match(coordinator, /id: "fare:/);
assert.match(flightModels, /let fare = fareAmount\.map/);
assert.ok(!coordinator.includes('.prefix('));
assert.ok(!coordinator.includes('cheapestUniqueOffers('));
assert.match(flightRows, /id: offer\.resultIdentityKey/);
for (const source of [outbound, inbound]) assert.match(source, /indexByKey\[offer\.resultIdentityKey\]/);

// Flight cards expose one unambiguous price hierarchy: package/person first, raw Ignav fare second.
assert.match(flightCard, /Пакет на 1 человека/);
assert.match(flightCard, /packagePricePerPerson/);
assert.match(flightCard, /Авиабилет туда/);
assert.match(flightCard, /Авиабилет обратно/);
assert.match(flightCard, /Тариф Ignav · за всех пассажиров/);
assert.ok(!flightCard.includes('Цена билета в одну сторону'));
assert.match(outbound, /packagePricePerPerson: packagePrices\[offer\.id\]/);
assert.match(inbound, /packagePricePerPerson: packagePrices\[offer\.id\]/);

// Supplier flight cost is exactly outbound + inbound when round-trip.
assert.match(localPricing, /outboundFareUsd:/);
assert.match(localPricing, /inboundFareUsd:/);
assert.match(localPricing, /let flights = outboundFlights \+ inboundFlights/);
assert.match(localPricing, /code: "flight_outbound"/);
assert.match(localPricing, /code: "flight_inbound"/);
assert.match(localPricing, /journeyFare: nil/);
assert.match(localPricing, /local-independent-flights-catalog-hotels-v5/);

// Preserve existing commercial policy and untouched service rates.
assert.match(localPricing, /packageMarkupRate\s*=\s*Decimal\(string:\s*"0\.50"\)!/);
assert.match(localPricing, /baseSelling\s*=\s*totalCost\s*\+\s*totalCost\s*\*\s*packageMarkupRate/);
assert.match(localPricing, /calculatedSelling\s*=\s*baseSelling\s*\/\s*\(1\s*-\s*paymentFeeRate\)/);
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

console.log('independent Ignav flights + 48h catalog hotel pricing + Business audit contract OK');
