import type {
  FlightLegCost,
  HotelCost,
  InternalPricingResult,
  PackageCustomization,
  PackageQuoteRequest,
  Travelers,
} from "./types";

export const PRICING_CONFIG = {
  packageMarkupRate: 0.50,
  paymentFeeRate: 0.02,
  publicRoundingStep: 5,
  visaPerTravellerUsd: 120,
  mealPerDayUsd: {
    economy: 15,
    standard: 15,
    comfort: 50,
    luxury: 200,
  },
  makkahZiyaratPerGroupUsd: 100,
  madinahZiyaratPerGroupUsd: 100,
  accompanimentWithMadinahPerGroupUsd: 300,
  accompanimentMakkahOnlyPerGroupUsd: 100,
  transfer: {
    sedanCapacity: 3,
    withMadinahPerSedanUsd: 300,
    makkahOnlyPerSedanUsd: 200,
  },
  esimUnitCostUsd: 0,
} as const;

export function roundPublicPrice(value: number) {
  const step = PRICING_CONFIG.publicRoundingStep;
  return Math.max(step, Math.round(value / step) * step);
}

export function travelerCount(travelers: Travelers) {
  return Math.max(1, travelers.adults + travelers.children + travelers.infants);
}

export function resolveRoomCount(travelers: Travelers) {
  const bedOccupants = Math.max(1, travelers.adults + travelers.children);
  const minimumRooms = Math.max(1, Math.ceil(bedOccupants / 4));
  return Math.max(travelers.rooms, minimumRooms);
}

export function resolveVehicleCount(travelers: Travelers) {
  return Math.max(1, Math.ceil(travelerCount(travelers) / PRICING_CONFIG.transfer.sedanCapacity));
}

function flightLegGroupCost(cost: FlightLegCost, travelers: Travelers) {
  if (Number.isFinite(cost.totalGroupUsd) && Number(cost.totalGroupUsd) >= 0) return Number(cost.totalGroupUsd);
  const adult = Number(cost.adultUsd ?? 0) * Math.max(0, travelers.adults);
  const child = Number(cost.childUsd ?? cost.adultUsd ?? 0) * Math.max(0, travelers.children);
  const infant = Number(cost.infantUsd ?? cost.adultUsd ?? 0) * Math.max(0, travelers.infants);
  return adult + child + infant;
}

function hotelCost(cost: HotelCost, rooms: number) {
  const nights = Math.max(1, Math.floor(cost.nights));
  return cost.amountUsd * rooms * (cost.unit === "perRoomNight" ? nights : 1);
}

function defaults(input: PackageQuoteRequest): PackageCustomization {
  return {
    accompaniment: true,
    meals: true,
    ziyaratMakkah: true,
    ziyaratMadinah: input.includeMadinah,
    esim: false,
    ...input.customization,
  };
}

export function calculatePackageQuote(input: PackageQuoteRequest, pricingVersion = "iumrah-web-v1-beta-0.5"): InternalPricingResult {
  const count = travelerCount(input.travelers);
  const rooms = resolveRoomCount(input.travelers);
  const vehicles = resolveVehicleCount(input.travelers);
  const customization = defaults(input);

  const costFlights =
    flightLegGroupCost(input.flights.outbound, input.travelers) +
    flightLegGroupCost(input.flights.inbound, input.travelers);

  const costHotel =
    hotelCost(input.hotels.makkah, rooms) +
    (input.includeMadinah && input.hotels.madinah ? hotelCost(input.hotels.madinah, rooms) : 0);

  const costVisa = PRICING_CONFIG.visaPerTravellerUsd * count;
  const mealTravellers = Math.max(0, input.travelers.adults + input.travelers.children);
  const costMeals = customization.meals
    ? PRICING_CONFIG.mealPerDayUsd[input.tier] * Math.max(1, input.totalDays) * mealTravellers
    : 0;

  const costTransfer =
    (input.includeMadinah
      ? PRICING_CONFIG.transfer.withMadinahPerSedanUsd
      : PRICING_CONFIG.transfer.makkahOnlyPerSedanUsd) * vehicles;

  const costGuide = customization.accompaniment
    ? input.includeMadinah
      ? PRICING_CONFIG.accompanimentWithMadinahPerGroupUsd
      : PRICING_CONFIG.accompanimentMakkahOnlyPerGroupUsd
    : 0;

  const costZiyarat =
    (customization.ziyaratMakkah ? PRICING_CONFIG.makkahZiyaratPerGroupUsd : 0) +
    (input.includeMadinah && customization.ziyaratMadinah ? PRICING_CONFIG.madinahZiyaratPerGroupUsd : 0);

  const costEsim = customization.esim ? PRICING_CONFIG.esimUnitCostUsd * count : 0;

  const totalCost = costFlights + costHotel + costVisa + costMeals + costTransfer + costGuide + costZiyarat + costEsim;
  const markupAmount = totalCost * PRICING_CONFIG.packageMarkupRate;
  const baseSellingPrice = totalCost + markupAmount;
  const sellingPrice = baseSellingPrice / (1 - PRICING_CONFIG.paymentFeeRate);
  const paymentFeeAmount = sellingPrice - baseSellingPrice;
  const estimatedProfit = sellingPrice - paymentFeeAmount - totalCost;

  const pricePerPerson = roundPublicPrice(sellingPrice / count);
  const totalPackagePrice = pricePerPerson * count;

  return {
    quoteId: crypto.randomUUID(),
    pricingVersion,
    currency: "USD",
    pricePerPerson,
    totalPackagePrice,
    roomCount: rooms,
    vehicleCount: vehicles,
    internal: {
      totalCost,
      costFlights,
      costHotel,
      costVisa,
      costMeals,
      costTransfer,
      costGuide,
      costZiyarat,
      costEsim,
      markupAmount,
      baseSellingPrice,
      paymentFeeAmount,
      sellingPrice,
      estimatedProfit,
    },
  };
}
