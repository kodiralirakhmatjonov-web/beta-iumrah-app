import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

const root = new URL("../../../", import.meta.url);
const journey = fs.readFileSync(new URL("Sources/State/JourneyStore.swift", root), "utf8");
const store = fs.readFileSync(new URL("Sources/State/HotelStorefrontStore.swift", root), "utf8");
const models = fs.readFileSync(new URL("Sources/Models/HotelStorefrontModels.swift", root), "utf8");
const home = fs.readFileSync(new URL("Sources/Views/Tabs/HotelsHomeView.swift", root), "utf8");
const primary = fs.readFileSync(new URL("Sources/Views/Hotels/PrimaryHotelView.swift", root), "utf8");
const imageCache = fs.readFileSync(new URL("Sources/Services/HotelImageCache.swift", root), "utf8");
const hotelCard = fs.readFileSync(new URL("Sources/Views/Components/HotelCard.swift", root), "utf8");
const finalPackage = fs.readFileSync(new URL("Sources/Views/Package/FinalPackageView.swift", root), "utf8");
const bookingDetail = fs.readFileSync(new URL("Sources/Views/Booking/BookingDetailView.swift", root), "utf8");

test("Primary Hotel selection resolves the Business editorial slot before factual-star fallback", () => {
  assert.match(journey, /resolvedPrimaryHotel\(from: all, city: "Makkah"\)/);
  assert.match(journey, /resolvedPrimaryHotel\(from: all, cityAliases: aliases\)/);
  const makkahBlock = journey.slice(journey.indexOf("func loadMakkahHotels"), journey.indexOf("func loadMadinahHotels"));
  const madinahBlock = journey.slice(journey.indexOf("func loadMadinahHotels"), journey.indexOf("private func resolvedPrimaryHotel"));
  assert.doesNotMatch(makkahBlock, /primaryCandidates/);
  assert.doesNotMatch(madinahBlock, /primaryCandidates/);
  assert.match(madinahBlock, /"Madinah", "Medina", "Madina", "Medinah"/);
});

test("published flight cards calculate one-person Standard packages from fixed hotels and a 4-8 day complementary leg", () => {
  assert.match(models, /struct StorefrontFlightPackagePreview/);
  assert.match(store, /preferredNames: \["Nawazi Hotel", "Nawazi Watheer Hotel"\]/);
  assert.match(store, /preferredNames: \["Mihrab Tayyiba", "Mihrab Tayba", "Mihrab Taiba"\]/);
  assert.match(store, /\(4\.\.\.8\)\.contains\(days\)/);
  assert.match(store, /abs\(lhsDays - 7\)/);
  assert.match(store, /case "MED": return "JED"/);
  assert.match(store, /case "JED": return "MED"/);
  assert.match(store, /trip\.adults = 1/);
  assert.match(store, /trip\.packageTier = \.standard/);
  assert.match(store, /LocalPackagePricingEngine\.calculate\(/);
  assert.match(store, /journeyFareScope: \.perPassenger/);
  assert.match(store, /TripStayPlanner\.windows/);
  assert.match(store, /makkahNightly/);
  assert.match(store, /madinahNightly/);
});

test("Flights storefront has From/To airport filters and never headlines a raw component fare", () => {
  assert.match(home, /flightOriginFilter/);
  assert.match(home, /flightDestinationFilter/);
  assert.match(home, /airportFilterMenu/);
  assert.match(home, /packagePreview: storefront\.packagePreview\(for: option\)/);
  const card = home.slice(home.indexOf("private struct StorefrontFlightOptionCard"), home.indexOf("struct HotelCareShowcaseCard"));
  assert.match(card, /packagePreview\.pricePerPerson/);
  assert.match(card, /package · 1 person/);
  assert.match(card, /no 4–8 day pair/);
  assert.doesNotMatch(card, /option\.perTravelerFare/);
  const flightsBoard = home.slice(home.indexOf("private var flightsBoard"), home.indexOf("MARK: - Sunday Club"));
  assert.doesNotMatch(flightsBoard, /StorefrontBaselineFlightCard/);
});

test("panoramic hotel photos are constrained by the card viewport and the meal UI remains intact", () => {
  assert.match(imageCache, /GeometryReader \{ proxy in/);
  assert.match(imageCache, /frame\(width: proxy\.size\.width, height: proxy\.size\.height\)/);
  assert.match(primary, /let contentWidth = max\(0, viewport\.size\.width - \(IumrahDesign\.pagePadding \* 2\)\)/);
  assert.match(primary, /frame\(width: contentWidth, alignment: \.leading\)/);
  assert.match(primary, /HotelCachedImage\(rawURL: hotel\.coverImageURL\)/);
  assert.match(primary, /mealPlanCard\(role: role\)/);
  assert.match(primary, /frame\(maxWidth: \.infinity, alignment: \.leading\)/);
  assert.match(hotelCard, /HotelCachedImage\(rawURL: hotel\.coverImageURL\)/);
  assert.match(finalPackage, /HotelCachedImage\(rawURL: hotel\.coverImageURL/);
  assert.match(bookingDetail, /HotelCachedImage\(/);
  assert.doesNotMatch(finalPackage.slice(finalPackage.indexOf("private func hotelExpandedContent"), finalPackage.indexOf("private var transferExpandedContent")), /AsyncImage/);
});
