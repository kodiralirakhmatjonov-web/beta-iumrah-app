import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

const root = new URL("../../../", import.meta.url);
const journey = fs.readFileSync(new URL("Sources/State/JourneyStore.swift", root), "utf8");
const finalPackage = fs.readFileSync(new URL("Sources/Views/Package/FinalPackageView.swift", root), "utf8");
const pricing = fs.readFileSync(new URL("Sources/Services/LocalPackagePricingEngine.swift", root), "utf8");

const comparisonBuilder = journey.slice(
  journey.indexOf("func buildPackageTierComparisons"),
  journey.indexOf("private func returnOffer")
);

const comparisonPricing = journey.slice(
  journey.indexOf("private func makePackageTierComparisonOption"),
  journey.indexOf("private func comparisonMakkahCatalog")
);

test("final package comparison keeps the exact selected flight itinerary and fare source", () => {
  assert.match(comparisonBuilder, /guard let outbound = selectedOutbound, outbound\.isVerifiedForBooking/);
  assert.match(comparisonBuilder, /guard let value = selectedInbound/);
  assert.match(comparisonBuilder, /returnOffer\(value, matches: outbound\)/);
  assert.match(comparisonBuilder, /pricingOffer = value/);
  assert.match(comparisonBuilder, /pricingOffer = outbound/);
  assert.match(comparisonBuilder, /LocalFXRateService\.shared\.usd\(rawFare, currency: pricingOffer\.currency\)/);
  assert.match(comparisonPricing, /journeyFareUsd: flight\.journeyFareUsd/);
  assert.match(comparisonPricing, /journeyFareScope: flight\.fareScope/);
  assert.match(comparisonPricing, /pricingOffer: flight\.pricingOffer/);
  assert.match(comparisonPricing, /outboundOffer: flight\.outboundOffer/);
  assert.match(comparisonPricing, /inboundOffer: flight\.inboundOffer/);
});

test("comparison hotel policy uses the agreed named hotels and Business Primary Hotel economy fallback", () => {
  assert.match(comparisonBuilder, /"Nawazi Hotel", "Nawazi Watheer Hotel"/);
  assert.match(comparisonBuilder, /"Mihrab Tayyiba", "Mihrab Tayba", "Mihrab Taiba"/);
  assert.match(comparisonBuilder, /"Shohada Hotel", "Al Shohada Hotel", "Shuhada Hotel", "Al Shuhada Hotel"/);
  assert.match(comparisonBuilder, /"Address Jabal Omar Makkah", "Address Jabal Omar", "Jabal Omar Address"/);
  assert.match(comparisonBuilder, /"Pullman Zamzam Madina", "Pullman Zamzam Madinah", "Pullman Zamzam"/);
  assert.match(comparisonBuilder, /if let policy = comparisonHotelPolicy\(for: tier, city: city\) \{[\s\S]*?return fixedComparisonHotel\(/);
  assert.match(comparisonBuilder, /let requestedStars = \[2, 1\]/);
  assert.match(comparisonBuilder, /packageEngine\.primaryHotel\(tier: tier, stars: stars, city: city\)/);
});

test("comparison recomputes hotel room nights but does not silently add Luxury Yukon or paid Comfort-Luxury meals", () => {
  assert.match(comparisonPricing, /TripStayPlanner\.windows\(for: comparisonTrip/);
  assert.match(comparisonPricing, /nightlyUsd: makkahNightly/);
  assert.match(comparisonPricing, /nights: windows\.makkah\.nights/);
  assert.match(comparisonPricing, /rooms: rooms/);
  assert.match(comparisonPricing, /makkahLunch: false/);
  assert.match(comparisonPricing, /makkahDinner: false/);
  assert.match(comparisonPricing, /madinahDinner: false/);
  assert.match(comparisonPricing, /transferVehicle: selectedTransferVehicle/);
  assert.doesNotMatch(comparisonPricing, /transferVehicle:\s*\.yukon/);
  assert.doesNotMatch(comparisonPricing, /selectedTransferVehicle\s*=\s*\.yukon/);
  assert.match(pricing, /luxuryPackageMarkupRate\s*=\s*Decimal\(string:\s*"0\.35"\)!/);
  assert.match(pricing, /tier == \.luxury \? luxuryPackageMarkupRate : standardPackageMarkupRate/);
});

test("carousel comparison is explicit, reversible UX and keeps booking details below it", () => {
  assert.match(finalPackage, /ScrollView\(\.horizontal, showsIndicators: false\)/);
  assert.match(finalPackage, /PackageTier\.allCases/);
  assert.match(finalPackage, /\.scrollTargetBehavior\(\.viewAligned\)/);
  assert.match(finalPackage, /\.scrollPosition\(id: \$focusedComparisonTier\)/);
  assert.match(finalPackage, /option\.tier != journey\.trip\.packageTier/);
  assert.match(finalPackage, /Task \{ await applyPackageTierComparison\(option\) \}/);
  assert.match(finalPackage, /packageRecommendationCard/);
  assert.match(finalPackage, /packageDifferenceCard/);
  assert.match(finalPackage, /includedServicesCard/);
  assert.match(finalPackage, /safeAreaInset\(edge: \.bottom/);
  assert.match(finalPackage, /fixedFlightComparisonNote/);
});
