import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

const root = new URL("../../../", import.meta.url);
const home = fs.readFileSync(new URL("Sources/Views/Tabs/HotelsHomeView.swift", root), "utf8");
const store = fs.readFileSync(new URL("Sources/State/HotelStorefrontStore.swift", root), "utf8");
const models = fs.readFileSync(new URL("Sources/Models/HotelStorefrontModels.swift", root), "utf8");
const transfer = fs.readFileSync(new URL("Sources/Views/Package/TransferSelectionView.swift", root), "utf8");
const policies = fs.readFileSync(new URL("Sources/Legal/IumrahPolicies.swift", root), "utf8");

const detailStart = home.indexOf("struct StorefrontUmrahPackageDetailView");
const detailEnd = home.indexOf("struct HotelCareShowcaseCard", detailStart);
const detail = detailStart >= 0
  ? home.slice(detailStart, detailEnd >= 0 ? detailEnd : undefined)
  : home;

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

test("transfer chooser stays reachable from package customization and preserves the selected transfer", () => {
  assert.match(transfer, /struct TransferSelectionView: View/);
  assert.match(transfer, /selectedTransferVehicle/);
  assert.match(detail, /TransferSelectionView\(\)/);
  assert.match(detail, /journey\.selectedTransferVehicle\?\.modelName/);
});
test("visa, personal guide, founder care and booking confidence are clearly separated", () => {
  assert.match(detail, /Официальная туристическая eVisa Саудовской Аравии/);
  assert.match(detail, /1 год/);
  assert.match(detail, /Многократн/);
  assert.match(detail, /90 дней/);
  assert.match(detail, /Умр/);
  assert.match(detail, /https:\/\/visa\.visitsaudi\.com\//);
  assert.match(detail, /iumrah Guide · сопровождение/);
  assert.match(detail, /Встреча после прилёта/);
  assert.match(detail, /Умра и зияраты/);
  assert.match(detail, /До обратного вылета/);
  assert.match(detail, /Абдулазиз/);
  assert.match(detail, /tel:\+998508898845/);
  assert.match(detail, /https:\/\/t\.me\/saudiclub966/);
  assert.match(detail, /Доверие и подтверждение бронирования/);
  assert.match(detail, /Живой контакт до оплаты/);
  assert.match(detail, /Инвойс и чек/);
  assert.match(detail, /Ответственность iumrah/);
  assert.match(detail, /Ответственность авиакомпании/);
  assert.match(detail, /Возврат — отдельная политика/);
  assert.doesNotMatch(detail, /Стоимость отдельных компонентов не показывается/);
});
test("Comfort and Luxury meals default to breakfast-only and expose optional lunch/dinner", () => {
  assert.match(detail, /Завтрак включён · обед и ужин по желанию/);
  assert.match(detail, /Включено · без доплаты/);
  assert.match(detail, /mealToggleRow\(\.lunch/);
  assert.match(detail, /mealToggleRow\(\.dinner/);
  assert.match(policies, /case \.package: return "arrow\.uturn\.backward\.circle\.fill"/);
  assert.match(detail, /Забронировать поездку/);
  assert.match(detail, /currentQuote\.totalPackagePrice/);
  assert.match(detail, /Сгенерировано iumrah Configurator/);
});
