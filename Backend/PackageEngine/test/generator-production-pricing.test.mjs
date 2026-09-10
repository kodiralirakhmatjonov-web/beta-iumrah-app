import assert from 'node:assert/strict';
import fs from 'node:fs';

const root = new URL('../../../', import.meta.url);
const hotelModels = fs.readFileSync(new URL('Sources/Models/HotelModels.swift', root), 'utf8');
const tripModels = fs.readFileSync(new URL('Sources/Models/TripModels.swift', root), 'utf8');
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
const bookingDraft = fs.readFileSync(new URL('Sources/Core/BookingDraftBuilder.swift', root), 'utf8');
const bookingControl = fs.readFileSync(new URL('Backend/PackageEngine/src/booking-control.ts', root), 'utf8');
const itineraryPlanner = fs.readFileSync(new URL('Sources/Core/BookingItineraryPlanner.swift', root), 'utf8');
const bookingDetail = fs.readFileSync(new URL('Sources/Views/Booking/BookingDetailView.swift', root), 'utf8');
const finalPackage = fs.readFileSync(new URL('Sources/Views/Package/FinalPackageView.swift', root), 'utf8');
const primaryHotel = fs.readFileSync(new URL('Sources/Views/Hotels/PrimaryHotelView.swift', root), 'utf8');
const tripBuilder = fs.readFileSync(new URL('Sources/Views/Trip/TripBuilderView.swift', root), 'utf8');
const hotelDetail = fs.readFileSync(new URL('Sources/Views/Hotels/HotelDetailView.swift', root), 'utf8');
const localization = fs.readFileSync(new URL('Sources/Core/AppLocalization.swift', root), 'utf8');
const careExplanation = fs.readFileSync(new URL('Sources/Views/Package/UmrahCarePackageExplanationView.swift', root), 'utf8');
const transferModels = fs.readFileSync(new URL('Sources/Models/TransferModels.swift', root), 'utf8');
const transferView = fs.readFileSync(new URL('Sources/Views/Package/TransferSelectionView.swift', root), 'utf8');

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
assert.match(localPricing, /local-expedia-package-v8/);

// Only verified provider fares may become package prices.
assert.match(ignavClient, /price\.status\.caseInsensitiveCompare\("verified"\) == \.orderedSame/);
assert.match(ignavWorker, /String\(price\.status \|\| ""\)\.toLowerCase\(\) !== "verified"/);

// Expedia-Packages style consumer hierarchy: only the package delta belongs on the flight card.
assert.match(flightCard, /deltaDisplay/);
assert.match(flightCard, /к пакету \/ 1 человек/);
assert.match(flightCard, /return current - baseline/);
assert.match(flightCard, /if delta < 0/);
assert.ok(!flightCard.includes('пакет всего'));
assert.ok(!flightCard.includes('пакет / 1 человек'));
assert.ok(!flightCard.includes('Тариф Ignav'));
assert.ok(!flightCard.includes('Цена билета в одну сторону'));
assert.match(outbound, /packagePricePerPerson: packagePrices\[offer\.id\]/);
assert.match(inbound, /packagePricePerPerson: packagePrices\[offer\.id\]/);
assert.ok(!outbound.includes('waiting-return'));

// Commercial/service policy: 25% normal tiers, 35% Luxury, 2% payment fee.
// Transfer is one $300 package allocation; Haramain is opt-in only.
assert.match(localPricing, /standardPackageMarkupRate\s*=\s*Decimal\(string:\s*"0\.25"\)!/);
assert.match(localPricing, /luxuryPackageMarkupRate\s*=\s*Decimal\(string:\s*"0\.35"\)!/);
assert.match(localPricing, /tier == \.luxury \? luxuryPackageMarkupRate : standardPackageMarkupRate/);
assert.match(localPricing, /paymentFeeRate\s*=\s*Decimal\(string:\s*"0\.02"\)!/);
assert.match(localPricing, /economyStandardMealPerPersonPerDayUsd = Decimal\(15\)/);
assert.match(localPricing, /comfortOptionalMealPerPersonPerServiceDayUsd = Decimal\(30\)/);
assert.match(localPricing, /luxuryOptionalMealPerPersonPerServiceDayUsd = Decimal\(50\)/);
assert.match(localPricing, /selection\.makkahLunch/);
assert.match(localPricing, /selection\.makkahDinner/);
assert.match(localPricing, /selection\.madinahDinner/);
assert.match(tripModels, /struct PackageMealSelection: Codable, Hashable/);
assert.match(tripModels, /var makkahLunch: Bool = true/);
assert.match(tripModels, /var makkahDinner: Bool = true/);
assert.match(tripModels, /var madinahDinner: Bool = true/);
assert.match(primaryHotel, /mealPlanCard\(role: role\)/);
assert.match(primaryHotel, /Toggle\("", isOn: isOn\)/);
assert.match(primaryHotel, /if role == \.makkah/);
assert.match(localPricing, /transferPerPackageUsd = Decimal\(300\)/);
assert.match(localPricing, /includeHaramainTrain: Bool = false/);
assert.match(localPricing, /haramain_train_addon/);
assert.ok(!localPricing.includes('localWithTrainPerSedanUsd'));
assert.ok(!localPricing.includes('roadWithMadinahPerSedanUsd'));


// Transfer V3 contract: Carnival is the default match, MapKit discovery runs for a
// randomized 20–40 second window without exposing the target duration, Yukon is an
// exact +$750 VIP public upgrade, and Haramain is an inline $150 Standard seat add-on.
assert.match(journey, /func recommendedTransferVehicle\(\) -> TransferVehicleKind \{[\s\S]*\.carnival/);
assert.match(transferModels, /guard self == \.yukon, scope == \.makkahAndMadinah else \{ return 0 \}/);
assert.match(transferModels, /return Decimal\(750\)/);
assert.match(transferModels, /case \.economy: return Decimal\(150\)/);
assert.match(transferModels, /case \.business: return Decimal\(200\)/);
assert.match(transferView, /searchDuration = Int\.random\(in: 20\.\.\.40\)/);
assert.match(transferView, /import MapKit/);
assert.match(transferView, /TransferLiveSearchMap/);
assert.match(transferView, /showsTraffic: true/);
assert.match(transferView, /RadialGradient/);
assert.match(transferView, /currentPriceText: currentPackagePriceTitle/);
assert.match(transferView, /HaramainPhotoGallery/);
assert.match(transferView, /Подключить поезд к поездке/);
assert.ok(!transferView.includes('HaramainTrainBookingSheet'));
assert.match(finalPackage, /expandableServiceRow/);
assert.match(finalPackage, /transferExpandedContent/);
assert.match(finalPackage, /visaExpandedContent/);
assert.match(finalPackage, /mealsExpandedContent/);
assert.match(localPricing, /let publicAddOns = vehicleUpgrade \+ trainAddOn/);

// Exact component report remains synchronized into iumrah Business.
assert.match(localPricing, /GeneratorPricingSnapshot/);
assert.match(localPricing, /supplierCostUsd:\s*totalCost/);
assert.match(bookingService, /func syncGeneratorReport/);
assert.match(bookingStore, /syncGeneratorReportWithRetry/);
assert.match(bookingStore, /bookingService\.syncGeneratorReport/);

// Client privacy/UI contract: no raw hotel price or flight-provider branding in customer cards.
assert.ok(!primaryHotel.includes('nightlyUSD'));
assert.ok(!primaryHotel.includes('providerDisplayName'));
assert.ok(!finalPackage.includes('Ignav'));
assert.ok(!flightCard.includes('sourceLabel'));

// V7 brand contract: no ticket-type switch, no supplier hotel identity, no manual-price language.
assert.ok(!tripBuilder.includes('flightTripTypeCard'));
assert.match(tripBuilder, /journey\.trip\.flightTripType = \.roundTrip/);
assert.ok(!hotelDetail.includes('nightlyUSD'));
assert.ok(!hotelDetail.includes('Booking.com'));
assert.ok(!hotelDetail.includes('Expedia'));
assert.match(hotelDetail, /iumrah Hotels/);
assert.match(hotelModels, /var providerDisplayName: String \{ "iumrah Hotels" \}/);
assert.equal((localization.match(/"booking_number_short"/g) || []).length, 4);
assert.ok(!localization.includes('confirmed manually before booking'));
assert.ok(!localization.includes('подтверждается вручную перед бронированием'));
assert.match(finalPackage, /Цена вашего Umrah-пакета/);
assert.ok(!careExplanation.includes('.scaledToFill()'));

// eSIM is included by default and can be removed through the same confirmation workflow.
assert.match(bookingDraft, /"esim"/);
assert.match(bookingDraft, /esim: true/);
assert.match(bookingControl, /const esim = bool\(body\.esim/);
assert.match(bookingControl, /nextServices\.add\("esim"\)/);
assert.match(bookingDetail, /UmrahMobileLogo/);
assert.match(bookingDetail, /updateESIM/);

// Package-aware itinerary planning uses the actual stay split and arrival city.
assert.match(itineraryPlanner, /madinahFirst/);
assert.match(itineraryPlanner, /booking\.stay\.makkahCheckIn/);
assert.match(itineraryPlanner, /madinahZiyarat/);
assert.match(itineraryPlanner, /airportTransfer/);

console.log('Expedia-style complete-itinerary flights + exact nightly hotel multiplication contract OK');
