import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

const root = new URL("../../../", import.meta.url);
const home = fs.readFileSync(new URL("Sources/Views/Tabs/HotelsHomeView.swift", root), "utf8");
const store = fs.readFileSync(new URL("Sources/State/HotelStorefrontStore.swift", root), "utf8");
const models = fs.readFileSync(new URL("Sources/Models/HotelStorefrontModels.swift", root), "utf8");
const transfer = fs.readFileSync(new URL("Sources/Views/Package/TransferSelectionView.swift", root), "utf8");
const policies = fs.readFileSync(new URL("Sources/Legal/IumrahPolicies.swift", root), "utf8");

const detailStart = home.indexOf("private struct StorefrontUmrahPackageDetailView");
const detailEnd = home.indexOf("struct HotelCareShowcaseCard");
const detail = home.slice(detailStart, detailEnd);

test("generated package detail keeps the existing visual hierarchy but upgrades hero, flights and hotel selection", () => {
  assert.match(detail, /TabView\(selection: \$heroImageIndex\)/);
  assert.match(detail, /tabViewStyle\(\.page\(indexDisplayMode: \.never\)\)/);
  assert.match(detail, /ForEach\(heroImages\.indices/);
  assert.match(detail, /PackageFlightLegDetailCard/);
  assert.match(detail, /expanded\.toggle\(\)/);
  assert.match(detail, /departureAirportTitle/);
  assert.match(detail, /arrivalAirportTitle/);
  assert.match(detail, /durationTitle/);
  assert.match(detail, /flightNumberTitle/);
  assert.match(detail, /HotelDetailView\(/);
  assert.match(detail, /selectionFlow: true/);
  assert.match(detail, /selectionRole: target\.role/);
  assert.match(detail, /selectedRoomName/);
  assert.match(detail, /Выбрать комнату/);
});

test("package checkout recalculates from the original generated fare and persists through BookingStore", () => {
  assert.match(models, /let flightFarePerPersonUSD: Decimal/);
  assert.match(models, /let fareObservedAt: String/);
  assert.match(store, /func checkoutQuote\(/);
  assert.match(store, /LocalPackagePricingEngine\.calculate\(/);
  assert.match(store, /func bookingFlightOffers\(/);
  assert.match(detail, /CounterRow\(/);
  assert.match(detail, /\$journey\.trip\.adults/);
  assert.match(detail, /\$journey\.trip\.children/);
  assert.match(detail, /\$journey\.trip\.infants/);
  assert.match(detail, /\$journey\.trip\.rooms/);
  assert.match(detail, /storefront\.checkoutQuote\(/);
  assert.match(detail, /BookingProfileCaptureSheet/);
  assert.match(detail, /let session = try await bookings\.create\(/);
  assert.match(detail, /createdBookingID = session\.id/);
  assert.match(detail, /BookingDetailView\(bookingID: bookingID\)/);
});

test("transfer chooser can be reused as a package customization screen and returns without opening FinalPackage", () => {
  assert.match(transfer, /private let selectionMode: Bool/);
  assert.match(transfer, /init\(selectionMode: Bool = false/);
  assert.match(transfer, /seedSelectionModeBasePrice\(\)/);
  assert.match(transfer, /if selectionMode \{/);
  assert.match(transfer, /onSelectionSaved\?\(\)/);
  assert.match(transfer, /dismiss\(\)/);
  assert.match(detail, /TransferSelectionView\(selectionMode: true\)/);
  assert.match(detail, /journey\.selectedTransferVehicle\?\.modelName/);
});

test("visa, personal guide and booking-confidence information are interactive and avoid hidden-component-price copy", () => {
  assert.match(detail, /Туристическая eVisa Саудовской Аравии/);
  assert.match(detail, /1 год/);
  assert.match(detail, /Многократный въезд/);
  assert.match(detail, /до 90 дней/);
  assert.match(detail, /Умры, но не Хаджа/);
  assert.match(detail, /https:\/\/visa\.visitsaudi\.com\//);
  assert.match(detail, /iumrah Guide · сопровождение/);
  assert.match(detail, /Встреча в аэропорту/);
  assert.match(detail, /Арабский язык и заселение/);
  assert.match(detail, /Зияраты/);
  assert.match(detail, /До вылета домой/);
  assert.match(detail, /Абдулазизом/);
  assert.match(detail, /tel:\+998508898845/);
  assert.match(detail, /https:\/\/t\.me\/saudiclub966/);
  assert.match(detail, /Доверие и подтверждение бронирования/);
  assert.match(detail, /iumrah Booking ID/);
  assert.match(detail, /Инвойс/);
  assert.match(detail, /Чек/);
  assert.doesNotMatch(detail, /Стоимость отдельных компонентов не показывается/);
});

test("package services show meal frequency and refund uses a money-return semantic icon", () => {
  assert.match(detail, /Мекка · 3 раза в день включено/);
  assert.match(detail, /Мекка · 3 раза в день · Медина · 2 раза в день/);
  assert.match(policies, /case \.package: return "arrow\.uturn\.backward\.circle\.fill"/);
  assert.match(detail, /Забронировать поездку/);
  assert.match(detail, /currentQuote\.totalPackagePrice/);
  assert.match(detail, /Сгенерировано iumrah Package System/);
});
