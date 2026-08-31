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
    roadWithMadinahPerSedanUsd: 300,
    localWithTrainPerSedanUsd: 200,
    makkahOnlyPerSedanUsd: 200,
  },
  haramainSarPerTraveller: 300,
  sarPerUsd: 3.75,
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

function finiteNonNegative(value: unknown, field: string) {
  const number = Number(value);
  if (!Number.isFinite(number) || number < 0) throw new Error(`${field} must be a finite non-negative number`);
  return number;
}

function flightLegGroupCost(cost: FlightLegCost, travelers: Travelers) {
  if (cost.totalGroupUsd !== undefined) return finiteNonNegative(cost.totalGroupUsd, "flight totalGroupUsd");
  const adultRate = finiteNonNegative(cost.adultUsd ?? 0, "adult flight fare");
  const childRate = finiteNonNegative(cost.childUsd ?? adultRate, "child flight fare");
  const infantRate = finiteNonNegative(cost.infantUsd ?? adultRate, "infant flight fare");
  return adultRate * Math.max(0, travelers.adults) + childRate * Math.max(0, travelers.children) + infantRate * Math.max(0, travelers.infants);
}

function hotelCost(cost: HotelCost, rooms: number) {
  const amount = finiteNonNegative(cost.amountUsd, "hotel amountUsd");
  const nights = Math.max(1, Math.floor(finiteNonNegative(cost.nights, "hotel nights")));
  if (cost.unit === "totalStay") return amount;
  if (cost.unit === "perRoomStay") return amount * rooms;
  if (cost.unit === "perRoomNight") return amount * rooms * nights;
  throw new Error("Unsupported hotel price unit");
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

export function calculatePackageQuote(input: PackageQuoteRequest, pricingVersion = "iumrah-web-v1-beta-0.15"): InternalPricingResult {
  if (!["economy", "standard", "comfort", "luxury"].includes(input.tier)) throw new Error("Unsupported package tier");
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

  const usesTrain = input.includeMadinah && input.intercityTransport === "haramainTrain";
  const costTransfer = input.includeMadinah
    ? (usesTrain ? PRICING_CONFIG.transfer.localWithTrainPerSedanUsd : PRICING_CONFIG.transfer.roadWithMadinahPerSedanUsd) * vehicles
    : PRICING_CONFIG.transfer.makkahOnlyPerSedanUsd * vehicles;
  const costIntercity = usesTrain
    ? (PRICING_CONFIG.haramainSarPerTraveller / PRICING_CONFIG.sarPerUsd) * count
    : 0;

  const costGuide = customization.accompaniment
    ? input.includeMadinah
      ? PRICING_CONFIG.accompanimentWithMadinahPerGroupUsd
      : PRICING_CONFIG.accompanimentMakkahOnlyPerGroupUsd
    : 0;

  const costZiyarat =
    (customization.ziyaratMakkah ? PRICING_CONFIG.makkahZiyaratPerGroupUsd : 0) +
    (input.includeMadinah && customization.ziyaratMadinah ? PRICING_CONFIG.madinahZiyaratPerGroupUsd : 0);

  const costEsim = customization.esim ? PRICING_CONFIG.esimUnitCostUsd * count : 0;

  const totalCost = costFlights + costHotel + costVisa + costMeals + costTransfer + costIntercity + costGuide + costZiyarat + costEsim;
  const markupAmount = totalCost * PRICING_CONFIG.packageMarkupRate;
  const baseSellingPrice = totalCost + markupAmount;
  const calculatedSellingPrice = baseSellingPrice / (1 - PRICING_CONFIG.paymentFeeRate);

  const pricePerPerson = roundPublicPrice(calculatedSellingPrice / count);
  const totalPackagePrice = pricePerPerson * count;
  const paymentFeeAmount = totalPackagePrice * PRICING_CONFIG.paymentFeeRate;
  const estimatedProfit = totalPackagePrice - paymentFeeAmount - totalCost;

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
      costIntercity,
      costGuide,
      costZiyarat,
      costEsim,
      markupAmount,
      baseSellingPrice,
      paymentFeeAmount,
      sellingPrice: calculatedSellingPrice,
      estimatedProfit,
    },
  };
}
