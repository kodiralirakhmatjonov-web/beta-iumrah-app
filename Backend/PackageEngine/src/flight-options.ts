import { normalizeToUsd, type FxEnvironment } from "./fx";
import { calculatePackageQuote } from "./pricing";
import { resolvePrimaryHotel, type D1Like } from "./primary-hotels";
import { legacyEstimatedHotelCost, type HotelPricingMode } from "./hotel-fallback";
import type {
  FlightFareObservation,
  FlightOptionsQuoteRequest,
  FlightQuoteContext,
  HotelCost,
  PublicFlightOptionQuote,
  PublicFlightOptionsQuoteResponse,
  PublicPackageQuote,
  Travelers,
} from "./types";

type Env = FxEnvironment & {
  PRICING_VERSION?: string;
  HOTELS_DB?: D1Like;
};

type NormalizedFare = {
  candidateId: string;
  totalGroupUsd: number;
  fxAsOf: string | null;
};

type ResolvedHotelCosts = {
  makkah: HotelCost;
  madinah: HotelCost | null;
  pricingMode: HotelPricingMode;
};

function publicOnly(result: ReturnType<typeof calculatePackageQuote>): PublicPackageQuote {
  return {
    quoteId: result.quoteId,
    pricingVersion: result.pricingVersion,
    currency: result.currency,
    pricePerPerson: result.pricePerPerson,
    totalPackagePrice: result.totalPackagePrice,
    roomCount: result.roomCount,
    vehicleCount: result.vehicleCount,
  };
}

function partyCount(travelers: Travelers) {
  return Math.max(1, travelers.adults + travelers.children + travelers.infants);
}

function adjustedContextForPair(
  context: FlightQuoteContext,
  outbound: FlightFareObservation,
  inbound: FlightFareObservation,
): FlightQuoteContext {
  const datePattern = /^\d{4}-\d{2}-\d{2}$/;
  if (!datePattern.test(outbound.travelDate) || !datePattern.test(inbound.travelDate)) return context;

  const start = Date.parse(`${outbound.travelDate}T12:00:00Z`);
  const end = Date.parse(`${inbound.travelDate}T12:00:00Z`);
  if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) return context;

  const totalNights = Math.max(1, Math.round((end - start) / 86_400_000));
  const totalDays = totalNights + 1;

  if (!context.includeMadinah || totalNights <= 1) {
    return {
      ...context,
      totalDays,
      nights: { makkah: totalNights, madinah: 0 },
    };
  }

  const makkah = Math.max(1, Math.min(totalNights - 1, Math.ceil(totalNights * 0.6)));
  const madinah = Math.max(1, totalNights - makkah);
  return {
    ...context,
    totalDays,
    nights: { makkah, madinah },
  };
}

const ALLOWED_PROVIDER_IDS = new Set([
  "uzbekistanAirways",
  "qanotSharq",
  "centrumAir",
  "silkAvia",
  "airSamarkand",
  "flyKhiva",
  "googleFlights",
  "skyscanner",
]);

function validateObservation(observation: FlightFareObservation) {
  const amount = Number(observation.amount);
  if (!Number.isFinite(amount) || amount <= 0) throw new Error(`Invalid fare amount for ${observation.candidateId}`);
  if (!/^[A-Z]{3}$/.test(String(observation.currency).toUpperCase())) throw new Error(`Invalid fare currency for ${observation.candidateId}`);
  if (observation.fareScope !== "perPassenger" && observation.fareScope !== "totalParty") {
    throw new Error(`Invalid fare scope for ${observation.candidateId}`);
  }
  if (!ALLOWED_PROVIDER_IDS.has(observation.providerId)) throw new Error(`Unknown flight provider: ${observation.providerId}`);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(observation.travelDate)) throw new Error(`Invalid travel date for ${observation.candidateId}`);
  validateFreshness(observation);
}

function validateFreshness(observation: FlightFareObservation) {
  const observed = Date.parse(observation.observedAt);
  if (!Number.isFinite(observed)) throw new Error(`Invalid observedAt for ${observation.candidateId}`);
  const ageMs = Date.now() - observed;
  if (ageMs < -5 * 60 * 1000) throw new Error(`Fare timestamp is in the future for ${observation.candidateId}`);
  if (ageMs > 20 * 60 * 1000) throw new Error(`Fare is stale for ${observation.candidateId}`);
}

async function normalizeObservation(
  observation: FlightFareObservation,
  travelers: Travelers,
  env: Env,
): Promise<NormalizedFare> {
  validateObservation(observation);
  const normalized = await normalizeToUsd(observation.amount, observation.currency, env);
  const multiplier = observation.fareScope === "perPassenger" ? partyCount(travelers) : 1;
  return {
    candidateId: observation.candidateId,
    totalGroupUsd: normalized.amountUsd * multiplier,
    fxAsOf: normalized.fxAsOf,
  };
}

async function resolveHotelCosts(context: FlightQuoteContext, env: Env): Promise<ResolvedHotelCosts> {
  if (!env.HOTELS_DB) throw new Error("HOTELS_DB binding is not configured");

  try {
    const makkah = await resolvePrimaryHotel(
      env.HOTELS_DB,
      context.tier,
      context.hotelStars,
      "Makkah",
      context.primaryHotelIds?.makkah,
    );
    const madinah = context.includeMadinah
      ? await resolvePrimaryHotel(
          env.HOTELS_DB,
          context.tier,
          context.hotelStars,
          "Madinah",
          context.primaryHotelIds?.madinah,
        )
      : null;

    return {
      makkah: {
        amountUsd: Number(makkah.base_price_usd),
        unit: makkah.price_unit,
        nights: Math.max(1, context.nights.makkah),
      },
      madinah: madinah
        ? {
            amountUsd: Number(madinah.base_price_usd),
            unit: madinah.price_unit,
            nights: Math.max(1, context.nights.madinah),
          }
        : null,
      pricingMode: "configuredPrimary",
    };
  } catch {
    // Technical beta fallback inherited from the old iumrah web estimate catalog.
    // It exists only so real flight search can be tested before every Primary Hotel
    // has a manually maintained internal rate. No component price is exposed to iOS.
    return {
      makkah: legacyEstimatedHotelCost(
        context.hotelStars,
        "Makkah",
        context.nights.makkah,
        context.travelStartDate,
      ),
      madinah: context.includeMadinah
        ? legacyEstimatedHotelCost(
            context.hotelStars,
            "Madinah",
            context.nights.madinah,
            context.travelStartDate,
          )
        : null,
      pricingMode: "legacyEstimate",
    };
  }
}

function buildQuote(
  context: FlightQuoteContext,
  outboundGroupUsd: number,
  inboundGroupUsd: number,
  hotels: ResolvedHotelCosts,
  env: Env,
) {
  return calculatePackageQuote(
    {
      tier: context.tier,
      includeMadinah: context.includeMadinah,
      totalDays: context.totalDays,
      travelers: context.travelers,
      flights: {
        outbound: { totalGroupUsd: outboundGroupUsd },
        inbound: { totalGroupUsd: inboundGroupUsd },
      },
      hotels: {
        makkah: hotels.makkah,
        madinah: hotels.madinah,
      },
      customization: context.customization,
    },
    env.PRICING_VERSION ?? "iumrah-web-v1-beta-0.9",
  );
}

export async function quoteFlightOptions(
  input: FlightOptionsQuoteRequest,
  env: Env,
): Promise<PublicFlightOptionsQuoteResponse> {
  const travelers = input.context.travelers;
  const outboundCount = input.phase === "outbound" ? input.outboundCandidates.length : 1;
  const returnCount = input.returnCandidates.length;
  if (outboundCount > 24 || returnCount > 24) throw new Error("Too many flight candidates in one quote request");
  const hotels = await resolveHotelCosts(input.context, env);

  if (input.phase === "outbound") {
    if (input.outboundCandidates.length === 0 || input.returnCandidates.length === 0) {
      throw new Error("Outbound and return candidates are required");
    }

    const normalizedReturns = await Promise.all(
      input.returnCandidates.map((candidate) => normalizeObservation(candidate, travelers, env)),
    );
    const referenceReturn = normalizedReturns.reduce((best, current) =>
      current.totalGroupUsd < best.totalGroupUsd ? current : best,
    );

    const normalizedOutbound = await Promise.all(
      input.outboundCandidates.map((candidate) => normalizeObservation(candidate, travelers, env)),
    );

    const returnObservation = input.returnCandidates.find((candidate) => candidate.candidateId === referenceReturn.candidateId)!;
    const outboundObservationMap = new Map(input.outboundCandidates.map((candidate) => [candidate.candidateId, candidate]));
    const options: PublicFlightOptionQuote[] = normalizedOutbound.map((candidate) => {
      const outboundObservation = outboundObservationMap.get(candidate.candidateId)!;
      const pairContext = adjustedContextForPair(input.context, outboundObservation, returnObservation);
      const pairHotels: ResolvedHotelCosts = {
        makkah: { ...hotels.makkah, nights: pairContext.nights.makkah },
        madinah: hotels.madinah ? { ...hotels.madinah, nights: pairContext.nights.madinah } : null,
        pricingMode: hotels.pricingMode,
      };
      const quote = buildQuote(pairContext, candidate.totalGroupUsd, referenceReturn.totalGroupUsd, pairHotels, env);
      return { candidateId: candidate.candidateId, ...publicOnly(quote) };
    });

    options.sort((a, b) => a.pricePerPerson - b.pricePerPerson);
    const fxAsOf = referenceReturn.fxAsOf ?? normalizedOutbound.find((candidate) => candidate.fxAsOf)?.fxAsOf ?? null;
    return {
      ok: true,
      phase: "outbound",
      options,
      referenceReturnCandidateId: referenceReturn.candidateId,
      fxAsOf,
      hotelPricingMode: hotels.pricingMode,
    };
  }

  if (input.returnCandidates.length === 0) throw new Error("Return candidates are required");
  const outbound = await normalizeObservation(input.selectedOutbound, travelers, env);
  const normalizedReturns = await Promise.all(
    input.returnCandidates.map((candidate) => normalizeObservation(candidate, travelers, env)),
  );

  const returnObservationMap = new Map(input.returnCandidates.map((candidate) => [candidate.candidateId, candidate]));
  const options: PublicFlightOptionQuote[] = normalizedReturns.map((candidate) => {
    const returnObservation = returnObservationMap.get(candidate.candidateId)!;
    const pairContext = adjustedContextForPair(input.context, input.selectedOutbound, returnObservation);
    const pairHotels: ResolvedHotelCosts = {
      makkah: { ...hotels.makkah, nights: pairContext.nights.makkah },
      madinah: hotels.madinah ? { ...hotels.madinah, nights: pairContext.nights.madinah } : null,
      pricingMode: hotels.pricingMode,
    };
    const quote = buildQuote(pairContext, outbound.totalGroupUsd, candidate.totalGroupUsd, pairHotels, env);
    return { candidateId: candidate.candidateId, ...publicOnly(quote) };
  });
  options.sort((a, b) => a.pricePerPerson - b.pricePerPerson);
  const fxAsOf = outbound.fxAsOf ?? normalizedReturns.find((candidate) => candidate.fxAsOf)?.fxAsOf ?? null;
  return { ok: true, phase: "return", options, fxAsOf, hotelPricingMode: hotels.pricingMode };
}
