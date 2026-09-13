import assert from 'node:assert/strict';
import fs from 'node:fs';

const root = new URL('../../../', import.meta.url);
const pricing = fs.readFileSync(new URL('Backend/PackageEngine/src/pricing.ts', root), 'utf8');
const packageSearch = fs.readFileSync(new URL('Backend/PackageEngine/src/package-search.ts', root), 'utf8');
const quoteAudit = fs.readFileSync(new URL('Backend/PackageEngine/src/quote-audit.ts', root), 'utf8');
const bookingGateway = fs.readFileSync(new URL('Backend/PackageEngine/src/booking-gateway.ts', root), 'utf8');
const localPricing = fs.readFileSync(new URL('Sources/Services/LocalPackagePricingEngine.swift', root), 'utf8');
const remoteEngine = fs.readFileSync(new URL('Sources/Services/RemotePackageEngineClient.swift', root), 'utf8');
const journey = fs.readFileSync(new URL('Sources/State/JourneyStore.swift', root), 'utf8');
const bookingStore = fs.readFileSync(new URL('Sources/State/BookingStore.swift', root), 'utf8');
const bookingDraft = fs.readFileSync(new URL('Sources/Core/BookingDraftBuilder.swift', root), 'utf8');
const tripModels = fs.readFileSync(new URL('Sources/Models/TripModels.swift', root), 'utf8');
const flightModels = fs.readFileSync(new URL('Sources/Models/FlightModels.swift', root), 'utf8');
const bookingModels = fs.readFileSync(new URL('Sources/Models/BookingModels.swift', root), 'utf8');
const flightCard = fs.readFileSync(new URL('Sources/Views/Components/FlightCard.swift', root), 'utf8');
const finalPackage = fs.readFileSync(new URL('Sources/Views/Package/FinalPackageView.swift', root), 'utf8');
const primaryHotel = fs.readFileSync(new URL('Sources/Views/Hotels/PrimaryHotelView.swift', root), 'utf8');
const transferModels = fs.readFileSync(new URL('Sources/Models/TransferModels.swift', root), 'utf8');
const transferView = fs.readFileSync(new URL('Sources/Views/Package/TransferSelectionView.swift', root), 'utf8');

// The confidential commercial motor is server-owned.
assert.match(pricing, /const STANDARD_MARKUP = 0\.25/);
assert.match(pricing, /const LUXURY_MARKUP = 0\.35/);
assert.match(pricing, /const PAYMENT_FEE = 0\.02/);
assert.match(pricing, /const VISA = 120/);
assert.match(pricing, /const TRANSFER = 300/);
assert.match(pricing, /server-expedia-package-v9/);
assert.match(pricing, /supplierCostUsd/);
assert.match(pricing, /estimatedProfitUsd/);
assert.doesNotMatch(localPricing, /0\.25|0\.35|PAYMENT_FEE|supplierCostUsd|estimatedProfitUsd|static func calculate/);

// Client sends selections/identifiers, never authoritative supplier costs.
assert.match(remoteEngine, /func packageQuote\(/);
assert.match(remoteEngine, /providerItineraryId:/);
assert.match(remoteEngine, /hotelId:/);
assert.doesNotMatch(remoteEngine, /supplierCostUsd/);
assert.match(journey, /packageEngine\.packageQuote\(/);
assert.doesNotMatch(journey, /LocalPackagePricingEngine\.calculate/);

// Worker re-resolves flight and hotel prices from server stores and does not persist a quote before booking.
assert.match(packageSearch, /resolveJourneyFare\(/);
assert.match(packageSearch, /resolveServerHotelPricing\(env\.HOTELS_DB/);
assert.match(packageSearch, /sealPricingSnapshot\(calculated\.snapshot/);
assert.doesNotMatch(packageSearch, /INSERT\s+INTO\s+package_quote/i);
assert.doesNotMatch(packageSearch, /UPDATE\s+pilgrim_trips/i);

// Full internal report is encrypted/opaque before booking, then committed only after a real booking exists.
assert.match(quoteAudit, /AES-GCM/);
assert.match(quoteAudit, /sealPricingSnapshot/);
assert.match(bookingGateway, /authorizedBooking/);
assert.match(bookingGateway, /unsealPricingSnapshot/);
assert.match(bookingGateway, /UPDATE pilgrim_trips/);
assert.match(bookingGateway, /pricing_snapshot_json/);
assert.match(bookingGateway, /pending_package_pricing_reports/);
assert.match(bookingGateway, /PRICING_REPORT_ALREADY_COMMITTED/);
assert.match(bookingStore, /pendingGeneratorQuoteProof/);
assert.match(bookingStore, /commitPricingReport/);
assert.match(bookingStore, /authoritativeQuoteRequired/);
assert.doesNotMatch(bookingDraft, /pricingSnapshot/);
assert.doesNotMatch(bookingModels, /pricingSnapshot|GeneratorPricingSnapshot/);
assert.doesNotMatch(flightModels, /GeneratorPricingSnapshot|supplierCostUsd|markupRate|estimatedProfitUsd/);

// Product pricing rules remain identical, only their execution boundary changed.
assert.match(pricing, /ECONOMY_STANDARD_MEAL = 15/);
assert.match(pricing, /COMFORT_OPTIONAL_MEAL = 30/);
assert.match(pricing, /LUXURY_OPTIONAL_MEAL = 50/);
assert.match(pricing, /vehicleUpgrade = input\.transferVehicle === "yukon".*750/);
assert.match(pricing, /trainSeat = input\.haramainFareClass === "business" \? 200 : 150/);
assert.match(tripModels, /struct PackageMealSelection: Codable, Hashable/);
assert.match(tripModels, /var makkahLunch: Bool = false/);
assert.match(primaryHotel, /mealPlanCard\(role: role\)/);
assert.match(transferModels, /return Decimal\(750\)/);
assert.match(transferView, /Подключить поезд к поездке/);

// Customer UI remains package-price oriented and does not expose the provider/cost report.
assert.match(flightCard, /deltaDisplay/);
assert.ok(!flightCard.includes('Тариф Ignav'));
assert.ok(!finalPackage.includes('Ignav'));
assert.ok(!primaryHotel.includes('providerDisplayName'));
assert.match(finalPackage, /Цена вашего Umrah-пакета/);

console.log('secure server generator + post-booking Business report contract OK');
