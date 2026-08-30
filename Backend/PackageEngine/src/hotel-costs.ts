import { normalizeToUsd, type FxEnvironment } from "./fx";
import { legacyEstimatedHotelCost } from "./hotel-fallback";
import { resolvePrimaryHotel, type D1Like } from "./primary-hotels";
import type { FlightQuoteContext, HotelCost, HotelFareObservation } from "./types";

type Env = FxEnvironment & { HOTELS_DB?: D1Like };

type CostSource = "live" | "configured" | "legacy";
export type ResolvedHotelCost = HotelCost & {
  hotelId?: string | null;
  roomId?: string | null;
  source?: CostSource;
  providerId?: string | null;
};

export type ResolvedHotelCosts = {
  makkah: ResolvedHotelCost;
  madinah: ResolvedHotelCost | null;
  pricingMode: "liveProvider" | "configuredPrimary" | "legacyEstimate" | "mixed";
};

const LIVE_PROVIDERS = new Set(["booking", "expedia"]);
const LIVE_MAX_AGE_MS = 30 * 60 * 1000;

function requestedRoomCount(context: FlightQuoteContext) {
  const bedOccupants = Math.max(1, context.travelers.adults + context.travelers.children);
  return Math.max(context.travelers.rooms, Math.ceil(bedOccupants / 4), 1);
}

function effectiveHotelCost(cost: HotelCost, rooms: number) {
  if (cost.unit === "totalStay") return cost.amountUsd;
  if (cost.unit === "perRoomNight") return cost.amountUsd * rooms * Math.max(1, cost.nights);
  return cost.amountUsd * rooms;
}


function addDays(day: string, days: number) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) return null;
  const date = new Date(`${day}T12:00:00Z`);
  if (!Number.isFinite(date.getTime())) return null;
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

function expectedStayDates(context: FlightQuoteContext, city: "Makkah" | "Madinah") {
  const start = context.travelStartDate;
  if (!start) return null;
  if (city === "Makkah") {
    const checkOut = addDays(start, Math.max(1, context.nights.makkah));
    return checkOut ? { checkIn: start, checkOut } : null;
  }
  const checkIn = addDays(start, Math.max(1, context.nights.makkah));
  if (!checkIn) return null;
  const checkOut = addDays(checkIn, Math.max(1, context.nights.madinah));
  return checkOut ? { checkIn, checkOut } : null;
}

function validObservation(
  observation: HotelFareObservation,
  hotelId: string,
  city: "Makkah" | "Madinah",
  context: FlightQuoteContext,
) {
  if (observation.hotelId !== hotelId) return false;
  if (observation.city.toLowerCase() !== city.toLowerCase()) return false;
  if (!LIVE_PROVIDERS.has(String(observation.providerId).toLowerCase())) return false;
  if (!Number.isFinite(Number(observation.amount)) || Number(observation.amount) <= 0) return false;
  if (!/^[A-Z]{3}$/i.test(String(observation.currency))) return false;
  if (!["totalStay", "perRoomStay", "perRoomNight"].includes(observation.unit)) return false;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(observation.checkInDate) || !/^\d{4}-\d{2}-\d{2}$/.test(observation.checkOutDate)) return false;
  const expected = expectedStayDates(context, city);
  if (!expected || observation.checkInDate !== expected.checkIn || observation.checkOutDate !== expected.checkOut) return false;
  const observed = Date.parse(observation.observedAt);
  if (!Number.isFinite(observed)) return false;
  const age = Date.now() - observed;
  return age >= -5 * 60 * 1000 && age <= LIVE_MAX_AGE_MS;
}

async function resolveLiveCost(
  observations: HotelFareObservation[] | undefined,
  hotelId: string | null | undefined,
  city: "Makkah" | "Madinah",
  nights: number,
  context: FlightQuoteContext,
  env: Env,
): Promise<ResolvedHotelCost | null> {
  if (!hotelId || !observations?.length) return null;
  const candidates = observations.filter((item) => validObservation(item, hotelId, city, context));
  if (!candidates.length) return null;

  const normalized = await Promise.all(candidates.map(async (observation) => {
    const fx = await normalizeToUsd(Number(observation.amount), String(observation.currency).toUpperCase(), env);
    const cost: ResolvedHotelCost = {
      amountUsd: fx.amountUsd,
      unit: observation.unit,
      nights: Math.max(1, nights),
      hotelId,
      roomId: null,
      source: "live",
      providerId: observation.providerId,
    };
    return cost;
  }));

  const rooms = requestedRoomCount(context);
  return normalized.reduce((best, current) =>
    effectiveHotelCost(current, rooms) < effectiveHotelCost(best, rooms) ? current : best,
  );
}

async function resolveConfiguredCost(
  context: FlightQuoteContext,
  env: Env,
  city: "Makkah" | "Madinah",
  requestedHotelId: string | null | undefined,
  nights: number,
): Promise<ResolvedHotelCost | null> {
  if (!env.HOTELS_DB) return null;
  try {
    const row = await resolvePrimaryHotel(
      env.HOTELS_DB,
      context.tier,
      context.hotelStars,
      city,
      requestedHotelId,
    );
    return {
      amountUsd: Number(row.base_price_usd),
      unit: row.price_unit,
      nights: Math.max(1, nights),
      hotelId: row.hotel_id,
      roomId: row.room_id,
      source: "configured",
      providerId: null,
    };
  } catch {
    return null;
  }
}

function resolveLegacyCost(
  context: FlightQuoteContext,
  city: "Makkah" | "Madinah",
  nights: number,
): ResolvedHotelCost {
  return {
    ...legacyEstimatedHotelCost(context.hotelStars, city, nights, context.travelStartDate),
    source: "legacy",
    providerId: null,
  };
}

async function resolveOne(
  context: FlightQuoteContext,
  env: Env,
  city: "Makkah" | "Madinah",
): Promise<ResolvedHotelCost> {
  const hotelId = city === "Makkah" ? context.primaryHotelIds?.makkah : context.primaryHotelIds?.madinah;
  const nights = city === "Makkah" ? context.nights.makkah : context.nights.madinah;
  const observations = city === "Makkah"
    ? context.hotelPriceObservations?.makkah
    : context.hotelPriceObservations?.madinah;

  const live = await resolveLiveCost(observations, hotelId, city, nights, context, env);
  if (live) return live;

  const configured = await resolveConfiguredCost(context, env, city, hotelId, nights);
  if (configured) return configured;

  return resolveLegacyCost(context, city, nights);
}

export async function resolveHotelCosts(context: FlightQuoteContext, env: Env): Promise<ResolvedHotelCosts> {
  if (!env.HOTELS_DB) throw new Error("HOTELS_DB binding is not configured");

  const makkah = await resolveOne(context, env, "Makkah");
  const madinah = context.includeMadinah ? await resolveOne(context, env, "Madinah") : null;
  const sources = [makkah.source, madinah?.source].filter(Boolean) as CostSource[];

  let pricingMode: ResolvedHotelCosts["pricingMode"];
  if (sources.length > 0 && sources.every((source) => source === "live")) pricingMode = "liveProvider";
  else if (sources.length > 0 && sources.every((source) => source === "configured")) pricingMode = "configuredPrimary";
  else if (sources.length > 0 && sources.every((source) => source === "legacy")) pricingMode = "legacyEstimate";
  else pricingMode = "mixed";

  return { makkah, madinah, pricingMode };
}
