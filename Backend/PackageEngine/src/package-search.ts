import { searchOfficialCarrierBots, type InternalFlightCandidate } from "./server-flight-bots";
import type { Env } from "./env";
import { calculatePackageQuote } from "./pricing";
import { persistQuoteAudit } from "./quote-audit";
import type {
  PackageSearchMode,
  PackageSearchProductKey,
  PackageSearchRequest,
  PackageSearchSnapshot,
  PackageTier,
  ServerFlightCandidate,
  ServerGeneratedPackage,
  ServerHotelSnapshot,
  ServerItinerary,
  ServerPackageTransport,
  ServerRequoteRequest,
  Travelers,
} from "./types";

type DurableObjectStorageLike = {
  get<T>(key: string): Promise<T | undefined>;
  put<T>(key: string, value: T): Promise<void>;
  setAlarm(timestamp: number | Date): Promise<void>;
};

type DurableObjectStateLike = {
  storage: DurableObjectStorageLike;
};

type SearchStage = "hotels" | "flights" | "complete";

type InternalHotelSnapshot = ServerHotelSnapshot & {
  internalRateUsd: number;
  priceUnit: "perRoomStay" | "perRoomNight";
};

type InternalPackageHotels = {
  makkah: InternalHotelSnapshot;
  madinah: InternalHotelSnapshot | null;
};

type PersistedSearchState = {
  request: PackageSearchRequest;
  baseItinerary: ServerItinerary;
  snapshot: PackageSearchSnapshot;
  stage: SearchStage;
  offsetIndex: number;
  retryCount: number;
  outboundInternal: InternalFlightCandidate[];
  inboundInternal: InternalFlightCandidate[];
  packageHotels: Partial<Record<PackageSearchProductKey, InternalPackageHotels>>;
};

type TierDefinition = {
  key: PackageSearchProductKey;
  pricingTier: PackageTier;
  stars: 1 | 3 | 5;
  recommended: boolean;
  transport: ServerPackageTransport;
};

type CuratedHotelRow = {
  hotel_id: string;
  hotel_name: string;
  city: "Makkah" | "Madinah";
  stars: number | null;
  rating: number | null;
  review_count: number | null;
  status: string;
  updated_at: string;
  image_count: number | string | null;
  room_count: number | string | null;
  cover_image_id: string | null;
};

type InternalRateRow = {
  hotel_id: string;
  room_id: string | null;
  base_price_usd: number;
  price_unit: "perRoomStay" | "perRoomNight";
};

const SEARCH_STATE_KEY = "searchStateV1";
const QUOTE_TTL_MS = 15 * 60_000;
const MAX_POOL_PER_DIRECTION = 10;

function json(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
  });
}

function isObject(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function cleanCode(value: unknown) {
  return String(value ?? "").trim().toUpperCase();
}

function validDate(value: unknown): value is string {
  const text = String(value ?? "");
  return /^\d{4}-\d{2}-\d{2}$/.test(text) && Number.isFinite(Date.parse(`${text}T00:00:00Z`));
}

function dateFromDay(day: string) {
  return new Date(`${day}T00:00:00Z`);
}

function dayFromDate(date: Date) {
  return date.toISOString().slice(0, 10);
}

function addDays(day: string, amount: number) {
  const date = dateFromDay(day);
  date.setUTCDate(date.getUTCDate() + amount);
  return dayFromDate(date);
}

function dayDiff(start: string, end: string) {
  return Math.round((dateFromDay(end).getTime() - dateFromDay(start).getTime()) / 86_400_000);
}

function validateTravelers(raw: unknown): Travelers {
  if (!isObject(raw)) throw new Error("INVALID_TRAVELERS");
  const adults = Number(raw.adults);
  const children = Number(raw.children ?? 0);
  const infants = Number(raw.infants ?? 0);
  const rooms = Number(raw.rooms);
  for (const [key, value] of Object.entries({ adults, children, infants, rooms })) {
    if (!Number.isInteger(value) || value < 0 || value > 30) throw new Error(`INVALID_${key.toUpperCase()}`);
  }
  if (adults < 1 || rooms < 1) throw new Error("ADULT_AND_ROOM_REQUIRED");
  if (infants > adults) throw new Error("INFANTS_EXCEED_ADULTS");
  return { adults, children, infants, rooms };
}

export function normalizePackageSearchRequest(raw: unknown): PackageSearchRequest {
  if (!isObject(raw)) throw new Error("INVALID_SEARCH_REQUEST");
  const clientRequestId = String(raw.clientRequestId ?? "").trim();
  if (!/^[A-Za-z0-9_-]{12,120}$/.test(clientRequestId)) throw new Error("INVALID_CLIENT_REQUEST_ID");
  const originCode = cleanCode(raw.originCode);
  if (!/^[A-Z]{3}$/.test(originCode) || originCode === "JED" || originCode === "MED") throw new Error("INVALID_ORIGIN_CODE");
  const arrivalAirportCode = cleanCode(raw.arrivalAirportCode);
  if (arrivalAirportCode !== "JED" && arrivalAirportCode !== "MED") throw new Error("INVALID_ARRIVAL_AIRPORT");
  if (!validDate(raw.startDate) || !validDate(raw.endDate)) throw new Error("INVALID_TRAVEL_DATES");
  const flexibility = String(raw.flexibility ?? "exact") as PackageSearchRequest["flexibility"];
  if (!["exact", "plusMinusOne", "plusMinusTwo", "weekend"].includes(flexibility)) throw new Error("INVALID_FLEXIBILITY");
  const travelers = validateTravelers(raw.travelers);
  const includeMadinah = Boolean(raw.includeMadinah);
  if (dayDiff(raw.startDate, raw.endDate) < 1) throw new Error("RETURN_MUST_BE_AFTER_DEPARTURE");
  if (dayDiff(raw.startDate, raw.endDate) > 45) throw new Error("TRIP_TOO_LONG");
  return {
    clientRequestId,
    originCode,
    arrivalAirportCode,
    startDate: raw.startDate,
    endDate: raw.endDate,
    flexibility,
    includeMadinah,
    travelers,
  };
}

function weekendFriday(referenceDay: string) {
  const reference = dateFromDay(referenceDay);
  const weekday = reference.getUTCDay(); // Sunday 0, Friday 5, Saturday 6
  let delta = (5 - weekday + 7) % 7;
  if (weekday === 6 || weekday === 0) {
    const backwards = weekday === 6 ? -1 : -2;
    const previousFriday = addDays(referenceDay, backwards);
    const today = new Date().toISOString().slice(0, 10);
    if (previousFriday >= today) delta = backwards;
  }
  reference.setUTCDate(reference.getUTCDate() + delta);
  return dayFromDate(reference);
}

export function normalizeItinerary(input: PackageSearchRequest): ServerItinerary {
  const sundayClub = input.flexibility === "weekend";
  const mode: PackageSearchMode = sundayClub ? "sundayClub" : "standard";
  const includeMadinah = sundayClub ? false : input.includeMadinah;
  const outboundDestination: "JED" | "MED" = includeMadinah ? input.arrivalAirportCode : "JED";
  const startDate = sundayClub ? weekendFriday(input.startDate) : input.startDate;
  const endDate = sundayClub ? addDays(startDate, 3) : input.endDate;
  const totalNights = Math.max(1, dayDiff(startDate, endDate));
  const totalDays = totalNights + 1;
  const makkahNights = includeMadinah && totalNights > 1
    ? Math.max(1, Math.min(totalNights - 1, Math.ceil(totalNights * 0.6)))
    : totalNights;
  const madinahNights = includeMadinah ? Math.max(1, totalNights - makkahNights) : 0;

  if (!includeMadinah) {
    return {
      mode,
      originCode: input.originCode,
      outboundDestination: "JED",
      returnOrigin: "JED",
      startDate,
      endDate,
      totalDays,
      totalNights,
      includeMadinah: false,
      makkahCheckIn: startDate,
      makkahCheckOut: endDate,
      makkahNights: totalNights,
      madinahCheckIn: null,
      madinahCheckOut: null,
      madinahNights: 0,
    };
  }

  if (outboundDestination === "MED") {
    const madinahCheckOut = addDays(startDate, madinahNights);
    return {
      mode,
      originCode: input.originCode,
      outboundDestination,
      returnOrigin: "JED",
      startDate,
      endDate,
      totalDays,
      totalNights,
      includeMadinah: true,
      makkahCheckIn: madinahCheckOut,
      makkahCheckOut: endDate,
      makkahNights,
      madinahCheckIn: startDate,
      madinahCheckOut,
      madinahNights,
    };
  }

  const makkahCheckOut = addDays(startDate, makkahNights);
  return {
    mode,
    originCode: input.originCode,
    outboundDestination,
    returnOrigin: "MED",
    startDate,
    endDate,
    totalDays,
    totalNights,
    includeMadinah: true,
    makkahCheckIn: startDate,
    makkahCheckOut,
    makkahNights,
    madinahCheckIn: makkahCheckOut,
    madinahCheckOut: endDate,
    madinahNights,
  };
}

export function shiftItinerary(base: ServerItinerary, offset: number): ServerItinerary {
  if (offset === 0) return base;
  return {
    ...base,
    startDate: addDays(base.startDate, offset),
    endDate: addDays(base.endDate, offset),
    makkahCheckIn: addDays(base.makkahCheckIn, offset),
    makkahCheckOut: addDays(base.makkahCheckOut, offset),
    madinahCheckIn: base.madinahCheckIn ? addDays(base.madinahCheckIn, offset) : null,
    madinahCheckOut: base.madinahCheckOut ? addDays(base.madinahCheckOut, offset) : null,
  };
}

export function searchDateOffsets(input: PackageSearchRequest) {
  if (input.flexibility === "weekend" || input.flexibility === "exact") return [0];
  return [0, -1, 1, -2, 2, -3, 3];
}

export function tierDefinitions(mode: PackageSearchMode): TierDefinition[] {
  const comfort: TierDefinition = {
    key: "comfort",
    pricingTier: "comfort",
    stars: 3,
    recommended: true,
    transport: { type: "haramainTrain", label: "Haramain train", haramainSarPerTraveler: 300 },
  };
  const luxury: TierDefinition = {
    key: "luxury",
    pricingTier: "luxury",
    stars: 5,
    recommended: false,
    transport: { type: "haramainTrain", label: "Haramain train", haramainSarPerTraveler: 300 },
  };
  if (mode === "sundayClub") return [comfort, luxury];
  return [
    {
      key: "essential",
      pricingTier: "economy",
      stars: 1,
      recommended: false,
      transport: { type: "road", label: "Road transfer", haramainSarPerTraveler: null },
    },
    comfort,
    luxury,
  ];
}

function emptyPackage(definition: TierDefinition, includeMadinah: boolean): ServerGeneratedPackage {
  return {
    key: definition.key,
    pricingTier: definition.pricingTier,
    stars: definition.stars,
    recommended: definition.recommended,
    status: "searching",
    blockReason: null,
    hotelMakkah: null,
    hotelMadinah: null,
    transport: includeMadinah ? definition.transport : { type: "road", label: "Local road transfer", haramainSarPerTraveler: null },
    selectedOutboundCandidateId: null,
    selectedInboundCandidateId: null,
    selectedDateOffset: 0,
    quote: null,
    quoteExpiresAt: null,
    hotelPricingMode: "unavailable",
  };
}

function initialSnapshot(searchId: string, input: PackageSearchRequest, itinerary: ServerItinerary, providerReady: boolean): PackageSearchSnapshot {
  const offsets = searchDateOffsets(input);
  return {
    ok: true,
    searchId,
    clientRequestId: input.clientRequestId,
    sequence: 1,
    status: "queued",
    mode: itinerary.mode,
    itinerary,
    packages: tierDefinitions(itinerary.mode).map((definition) => emptyPackage(definition, itinerary.includeMadinah)),
    outboundFlights: [],
    inboundFlights: [],
    searchedDateOffsets: [],
    pendingDateOffsets: offsets,
    providerReady,
    message: providerReady ? "Preparing search" : "Flight provider is not configured",
    updatedAt: new Date().toISOString(),
  };
}

function withSequence(snapshot: PackageSearchSnapshot, patch: Partial<PackageSearchSnapshot>): PackageSearchSnapshot {
  return {
    ...snapshot,
    ...patch,
    sequence: snapshot.sequence + 1,
    updatedAt: new Date().toISOString(),
  };
}

async function curatedHotel(env: Env, city: "Makkah" | "Madinah", stars: number): Promise<CuratedHotelRow | null> {
  if (!env.HOTELS_DB) throw new Error("HOTELS_DB_NOT_CONFIGURED");
  return env.HOTELS_DB.prepare(`SELECT
      h.id AS hotel_id,
      h.name AS hotel_name,
      h.city,
      h.stars,
      h.rating,
      h.review_count,
      h.status,
      h.updated_at,
      (SELECT COUNT(*) FROM hotel_images hi WHERE hi.hotel_id=h.id) AS image_count,
      (SELECT COUNT(*) FROM hotel_rooms hr WHERE hr.hotel_id=h.id) AS room_count,
      (SELECT hi.id FROM hotel_images hi WHERE hi.hotel_id=h.id ORDER BY hi.is_cover DESC,hi.position ASC,hi.created_at ASC LIMIT 1) AS cover_image_id
    FROM primary_hotels p
    JOIN hotels h ON h.id=p.hotel_id
    WHERE LOWER(p.city)=LOWER(?1) AND p.star_category=?2 AND h.status='published' AND h.stars=?2
    ORDER BY p.position ASC
    LIMIT 1`).bind(city, stars).first<CuratedHotelRow>();
}

async function exactInternalRate(
  env: Env,
  definition: TierDefinition,
  city: "Makkah" | "Madinah",
  hotelId: string,
  requestedRoomId?: string | null,
): Promise<InternalRateRow | null> {
  if (!env.HOTELS_DB) throw new Error("HOTELS_DB_NOT_CONFIGURED");
  const row = await env.HOTELS_DB.prepare(`SELECT hotel_id,room_id,base_price_usd,price_unit
      FROM package_primary_hotels
      WHERE hotel_id=?1 AND city=?2 AND package_tier=?3 AND stars=?4 AND active=1
      ORDER BY updated_at DESC LIMIT 1`)
    .bind(hotelId, city, definition.pricingTier, definition.stars)
    .first<InternalRateRow>();
  if (!row) return null;
  if (requestedRoomId && row.room_id !== requestedRoomId) return null;
  return row;
}

async function hotelByID(env: Env, hotelId: string): Promise<CuratedHotelRow | null> {
  if (!env.HOTELS_DB) throw new Error("HOTELS_DB_NOT_CONFIGURED");
  return env.HOTELS_DB.prepare(`SELECT
      h.id AS hotel_id,h.name AS hotel_name,h.city,h.stars,h.rating,h.review_count,h.status,h.updated_at,
      (SELECT COUNT(*) FROM hotel_images hi WHERE hi.hotel_id=h.id) AS image_count,
      (SELECT COUNT(*) FROM hotel_rooms hr WHERE hr.hotel_id=h.id) AS room_count,
      (SELECT hi.id FROM hotel_images hi WHERE hi.hotel_id=h.id ORDER BY hi.is_cover DESC,hi.position ASC,hi.created_at ASC LIMIT 1) AS cover_image_id
    FROM hotels h WHERE h.id=?1 AND h.status='published' LIMIT 1`)
    .bind(hotelId).first<CuratedHotelRow>();
}

function hotelSnapshot(row: CuratedHotelRow, rate: InternalRateRow, city: "Makkah" | "Madinah"): InternalHotelSnapshot {
  return {
    hotelId: row.hotel_id,
    hotelName: row.hotel_name,
    city,
    stars: row.stars == null ? null : Number(row.stars),
    rating: row.rating == null ? null : Number(row.rating),
    reviewCount: row.review_count == null ? null : Number(row.review_count),
    coverImageURL: row.cover_image_id ? `/api/catalog/hotels/${encodeURIComponent(row.hotel_id)}/images/${encodeURIComponent(row.cover_image_id)}` : null,
    imageCount: Number(row.image_count ?? 0),
    roomCount: Number(row.room_count ?? 0),
    updatedAt: row.updated_at,
    roomId: rate.room_id,
    pricingMode: "configuredPrimary",
    internalRateUsd: Number(rate.base_price_usd),
    priceUnit: rate.price_unit,
  };
}

function publicHotel(hotel: InternalHotelSnapshot): ServerHotelSnapshot {
  const { internalRateUsd: _privateRate, priceUnit: _privateUnit, ...publicValue } = hotel;
  return publicValue;
}

async function resolveDefaultHotels(env: Env, definition: TierDefinition, includeMadinah: boolean): Promise<InternalPackageHotels> {
  const makkahRow = await curatedHotel(env, "Makkah", definition.stars);
  if (!makkahRow) throw new Error(`PRIMARY_HOTEL_NOT_CONFIGURED:Makkah:${definition.stars}`);
  const makkahRate = await exactInternalRate(env, definition, "Makkah", makkahRow.hotel_id);
  if (!makkahRate) throw new Error(`PACKAGE_RATE_NOT_CONFIGURED:Makkah:${makkahRow.hotel_id}`);
  const makkah = hotelSnapshot(makkahRow, makkahRate, "Makkah");

  if (!includeMadinah) return { makkah, madinah: null };
  const madinahRow = await curatedHotel(env, "Madinah", definition.stars);
  if (!madinahRow) throw new Error(`PRIMARY_HOTEL_NOT_CONFIGURED:Madinah:${definition.stars}`);
  const madinahRate = await exactInternalRate(env, definition, "Madinah", madinahRow.hotel_id);
  if (!madinahRate) throw new Error(`PACKAGE_RATE_NOT_CONFIGURED:Madinah:${madinahRow.hotel_id}`);
  return { makkah, madinah: hotelSnapshot(madinahRow, madinahRate, "Madinah") };
}

function publicCandidate(candidate: InternalFlightCandidate): ServerFlightCandidate {
  const { groupFareUsd: _privateFare, ...publicValue } = candidate;
  return publicValue;
}

function candidateSignature(candidate: InternalFlightCandidate) {
  return candidate.segments.map((segment) => `${segment.flightNumber}:${segment.origin}:${segment.destination}:${segment.departureAt}`).join("|");
}

function mergePool(current: InternalFlightCandidate[], added: InternalFlightCandidate[]) {
  const map = new Map<string, InternalFlightCandidate>();
  for (const candidate of [...current, ...added]) {
    const signature = candidateSignature(candidate);
    const existing = map.get(signature);
    if (!existing || candidate.groupFareUsd < existing.groupFareUsd) map.set(signature, candidate);
  }
  return Array.from(map.values())
    .sort((a, b) => a.groupFareUsd - b.groupFareUsd || Math.abs(a.dateOffset) - Math.abs(b.dateOffset))
    .slice(0, MAX_POOL_PER_DIRECTION);
}

export function bestFlightPair(outbound: InternalFlightCandidate[], inbound: InternalFlightCandidate[]) {
  const offsets = new Set(outbound.map((candidate) => candidate.dateOffset));
  const pairs: Array<{ outbound: InternalFlightCandidate; inbound: InternalFlightCandidate; dateOffset: number; total: number }> = [];
  for (const offset of offsets) {
    const outs = outbound.filter((candidate) => candidate.dateOffset === offset).sort((a, b) => a.groupFareUsd - b.groupFareUsd);
    const ins = inbound.filter((candidate) => candidate.dateOffset === offset).sort((a, b) => a.groupFareUsd - b.groupFareUsd);
    if (!outs[0] || !ins[0]) continue;
    pairs.push({ outbound: outs[0], inbound: ins[0], dateOffset: offset, total: outs[0].groupFareUsd + ins[0].groupFareUsd });
  }
  return pairs.sort((a, b) => a.total - b.total || Math.abs(a.dateOffset) - Math.abs(b.dateOffset))[0] ?? null;
}

function observation(candidate: InternalFlightCandidate) {
  return {
    candidateId: candidate.id,
    amount: candidate.groupFareUsd,
    currency: "USD",
    fareScope: "totalParty" as const,
    providerId: candidate.providerId,
    observedAt: new Date().toISOString(),
    travelDate: candidate.travelDate,
    normalizedGroupUsd: candidate.groupFareUsd,
    snapshot: candidate as unknown as Record<string, unknown>,
  };
}

async function quotePackage(
  env: Env,
  searchId: string,
  definition: TierDefinition,
  itinerary: ServerItinerary,
  travelers: Travelers,
  hotels: InternalPackageHotels,
  outbound: InternalFlightCandidate,
  inbound: InternalFlightCandidate,
): Promise<{ quote: ReturnType<typeof calculatePackageQuote>; expiresAt: string }> {
  const transport = itinerary.includeMadinah ? definition.transport.type : "road";
  const quote = calculatePackageQuote({
    tier: definition.pricingTier,
    includeMadinah: itinerary.includeMadinah,
    totalDays: itinerary.totalDays,
    travelers,
    flights: {
      outbound: { totalGroupUsd: outbound.groupFareUsd },
      inbound: { totalGroupUsd: inbound.groupFareUsd },
    },
    hotels: {
      makkah: { amountUsd: hotels.makkah.internalRateUsd, unit: hotels.makkah.priceUnit, nights: itinerary.makkahNights },
      madinah: hotels.madinah ? { amountUsd: hotels.madinah.internalRateUsd, unit: hotels.madinah.priceUnit, nights: itinerary.madinahNights } : null,
    },
    intercityTransport: transport,
  }, env.PRICING_VERSION ?? "iumrah-web-v1-beta-0.15");
  const expiresAt = new Date(Date.now() + QUOTE_TTL_MS).toISOString();
  await persistQuoteAudit(env.HOTELS_DB, quote, {
    authority: "server_search",
    searchId,
    packageKey: definition.key,
    expiresAt,
    tier: definition.pricingTier,
    includeMadinah: itinerary.includeMadinah,
    totalDays: itinerary.totalDays,
    travelers,
    intercityTransport: transport,
    itinerary: itinerary as unknown as Record<string, unknown>,
    outbound: observation(outbound),
    inbound: observation(inbound),
    makkahHotel: {
      amountUsd: hotels.makkah.internalRateUsd,
      unit: hotels.makkah.priceUnit,
      nights: itinerary.makkahNights,
      hotelId: hotels.makkah.hotelId,
      roomId: hotels.makkah.roomId,
      hotelName: hotels.makkah.hotelName,
      pricingMode: hotels.makkah.pricingMode,
    },
    madinahHotel: hotels.madinah ? {
      amountUsd: hotels.madinah.internalRateUsd,
      unit: hotels.madinah.priceUnit,
      nights: itinerary.madinahNights,
      hotelId: hotels.madinah.hotelId,
      roomId: hotels.madinah.roomId,
      hotelName: hotels.madinah.hotelName,
      pricingMode: hotels.madinah.pricingMode,
    } : null,
  });
  return { quote, expiresAt };
}

async function preparePackages(env: Env, snapshot: PackageSearchSnapshot) {
  const definitions = tierDefinitions(snapshot.mode);
  const packages: ServerGeneratedPackage[] = [];
  const packageHotels: Partial<Record<PackageSearchProductKey, InternalPackageHotels>> = {};
  for (const definition of definitions) {
    try {
      const hotels = await resolveDefaultHotels(env, definition, snapshot.itinerary.includeMadinah);
      packageHotels[definition.key] = hotels;
      packages.push({
        ...emptyPackage(definition, snapshot.itinerary.includeMadinah),
        hotelMakkah: publicHotel(hotels.makkah),
        hotelMadinah: hotels.madinah ? publicHotel(hotels.madinah) : null,
        hotelPricingMode: "configuredPrimary",
      });
    } catch (error) {
      packages.push({
        ...emptyPackage(definition, snapshot.itinerary.includeMadinah),
        status: "blocked",
        blockReason: error instanceof Error ? error.message : "HOTEL_CONFIGURATION_FAILED",
      });
    }
  }
  return { packages, packageHotels };
}

async function refreshPackageQuotes(env: Env, state: PersistedSearchState) {
  const pair = bestFlightPair(state.outboundInternal, state.inboundInternal);
  if (!pair) return state.snapshot.packages;
  const itinerary = shiftItinerary(state.baseItinerary, pair.dateOffset);
  const definitions = new Map(tierDefinitions(state.snapshot.mode).map((definition) => [definition.key, definition]));
  const updated: ServerGeneratedPackage[] = [];
  for (const current of state.snapshot.packages) {
    if (current.status === "blocked" || !current.hotelMakkah) {
      updated.push(current);
      continue;
    }
    const definition = definitions.get(current.key);
    if (!definition) {
      updated.push({ ...current, status: "blocked", blockReason: "PACKAGE_DEFINITION_MISSING" });
      continue;
    }
    try {
      const hotels = state.packageHotels[current.key];
      if (!hotels) throw new Error("PACKAGE_HOTEL_INTERNAL_STATE_MISSING");
      const priced = await quotePackage(
        env,
        state.snapshot.searchId,
        definition,
        itinerary,
        state.request.travelers,
        hotels,
        pair.outbound,
        pair.inbound,
      );
      updated.push({
        ...current,
        status: "ready",
        blockReason: null,
        selectedOutboundCandidateId: pair.outbound.id,
        selectedInboundCandidateId: pair.inbound.id,
        selectedDateOffset: pair.dateOffset,
        quote: {
          quoteId: priced.quote.quoteId,
          pricingVersion: priced.quote.pricingVersion,
          currency: priced.quote.currency,
          pricePerPerson: priced.quote.pricePerPerson,
          totalPackagePrice: priced.quote.totalPackagePrice,
          roomCount: priced.quote.roomCount,
          vehicleCount: priced.quote.vehicleCount,
        },
        quoteExpiresAt: priced.expiresAt,
      });
    } catch (error) {
      updated.push({ ...current, status: "blocked", blockReason: error instanceof Error ? error.message : "QUOTE_FAILED" });
    }
  }
  return updated;
}

function snapshotStatus(packages: ServerGeneratedPackage[], searchComplete: boolean) {
  const ready = packages.filter((item) => item.status === "ready").length;
  const searching = packages.filter((item) => item.status === "searching").length;
  if (searchComplete) return ready > 0 ? "ready" as const : "failed" as const;
  if (ready > 0) return "partial" as const;
  if (searching > 0) return "searching" as const;
  return "partial" as const;
}

async function customHotel(
  env: Env,
  definition: TierDefinition,
  city: "Makkah" | "Madinah",
  hotelId: string,
  roomId?: string | null,
): Promise<InternalHotelSnapshot> {
  const row = await hotelByID(env, hotelId);
  if (!row || row.city.toLowerCase() !== city.toLowerCase()) throw new Error(`HOTEL_NOT_AVAILABLE:${city}`);
  const rate = await exactInternalRate(env, definition, city, hotelId, roomId);
  if (!rate) throw new Error(roomId ? `ROOM_RATE_NOT_CONFIGURED:${hotelId}:${roomId}` : `HOTEL_RATE_NOT_CONFIGURED:${hotelId}`);
  return hotelSnapshot(row, rate, city);
}

export class PackageSearchSession {
  private state: DurableObjectStateLike;
  private env: Env;

  constructor(state: DurableObjectStateLike, env: Env) {
    this.state = state;
    this.env = env;
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === "POST" && url.pathname === "/start") return this.start(request);
    if (request.method === "GET" && url.pathname === "/snapshot") return this.snapshot();
    if (request.method === "POST" && url.pathname === "/requote") return this.requote(request);
    return json({ ok: false, error: "NOT_FOUND" }, 404);
  }

  private async start(request: Request) {
    try {
      const normalized = normalizePackageSearchRequest(await request.json());
      const existing = await this.state.storage.get<PersistedSearchState>(SEARCH_STATE_KEY);
      if (existing) {
        if (JSON.stringify(existing.request) !== JSON.stringify(normalized)) return json({ ok: false, error: "IDEMPOTENCY_KEY_CONFLICT" }, 409);
        return json(existing.snapshot);
      }
      const itinerary = normalizeItinerary(normalized);
      const providerReady = true;
      const snapshot = initialSnapshot(normalized.clientRequestId, normalized, itinerary, providerReady);
      const state: PersistedSearchState = {
        request: normalized,
        baseItinerary: itinerary,
        snapshot,
        stage: "hotels",
        offsetIndex: 0,
        retryCount: 0,
        outboundInternal: [],
        inboundInternal: [],
        packageHotels: {},
      };
      await this.state.storage.put(SEARCH_STATE_KEY, state);
      await this.state.storage.setAlarm(Date.now() + 50);
      return json(snapshot, 202);
    } catch (error) {
      return json({ ok: false, error: error instanceof Error ? error.message : "INVALID_SEARCH_REQUEST" }, 400);
    }
  }

  private async snapshot() {
    const state = await this.state.storage.get<PersistedSearchState>(SEARCH_STATE_KEY);
    if (!state) return json({ ok: false, error: "SEARCH_NOT_FOUND" }, 404);
    return json(state.snapshot);
  }

  async alarm() {
    const state = await this.state.storage.get<PersistedSearchState>(SEARCH_STATE_KEY);
    if (!state || state.stage === "complete") return;
    try {
      if (state.stage === "hotels") {
        const prepared = await preparePackages(this.env, state.snapshot);
        state.packageHotels = prepared.packageHotels;
        state.snapshot = withSequence(state.snapshot, {
          status: "searching",
          packages: prepared.packages,
          message: "Searching official airline websites",
        });
        state.stage = "flights";
        await this.state.storage.put(SEARCH_STATE_KEY, state);
        await this.state.storage.setAlarm(Date.now() + 50);
        return;
      }

      const offsets = searchDateOffsets(state.request);
      if (state.offsetIndex >= offsets.length) {
        state.snapshot = withSequence(state.snapshot, {
          status: snapshotStatus(state.snapshot.packages, true),
          pendingDateOffsets: [],
          message: state.snapshot.packages.some((item) => item.status === "ready") ? "Search complete" : "No bookable package found",
        });
        state.stage = "complete";
        await this.state.storage.put(SEARCH_STATE_KEY, state);
        return;
      }

      const offset = offsets[state.offsetIndex];
      const itinerary = shiftItinerary(state.baseItinerary, offset);
      const [outbound, inbound] = await Promise.all([
        searchOfficialCarrierBots(this.env, {
          searchId: state.snapshot.searchId,
          direction: "outbound",
          dateOffset: offset,
          origin: itinerary.originCode,
          destination: itinerary.outboundDestination,
          travelDate: itinerary.startDate,
          travelers: state.request.travelers,
        }),
        searchOfficialCarrierBots(this.env, {
          searchId: state.snapshot.searchId,
          direction: "inbound",
          dateOffset: offset,
          origin: itinerary.returnOrigin,
          destination: itinerary.originCode,
          travelDate: itinerary.endDate,
          travelers: state.request.travelers,
        }),
      ]);
      state.outboundInternal = mergePool(state.outboundInternal, outbound.candidates);
      state.inboundInternal = mergePool(state.inboundInternal, inbound.candidates);
      const outboundFlights = state.outboundInternal.map(publicCandidate);
      const inboundFlights = state.inboundInternal.map(publicCandidate);
      state.snapshot = withSequence(state.snapshot, {
        outboundFlights,
        inboundFlights,
        searchedDateOffsets: [...state.snapshot.searchedDateOffsets.filter((item) => item !== offset), offset],
        pendingDateOffsets: offsets.slice(state.offsetIndex + 1),
        message: offsets.length > 1 && state.offsetIndex + 1 < offsets.length ? "Continuing flexible-date search" : "Finalizing packages",
      });
      state.snapshot.packages = await refreshPackageQuotes(this.env, state);
      state.snapshot = withSequence(state.snapshot, {
        packages: state.snapshot.packages,
        status: snapshotStatus(state.snapshot.packages, false),
      });
      state.offsetIndex += 1;
      state.retryCount = 0;
      await this.state.storage.put(SEARCH_STATE_KEY, state);
      await this.state.storage.setAlarm(Date.now() + 80);
    } catch (error) {
      const message = error instanceof Error ? error.message : "PACKAGE_SEARCH_FAILED";
      if (state.retryCount < 1) {
        state.retryCount += 1;
        state.snapshot = withSequence(state.snapshot, { status: "searching", message: `Retrying provider: ${message}` });
        await this.state.storage.put(SEARCH_STATE_KEY, state);
        await this.state.storage.setAlarm(Date.now() + 5_000);
        return;
      }
      state.retryCount = 0;
      state.offsetIndex += 1;
      const offsets = searchDateOffsets(state.request);
      const complete = state.offsetIndex >= offsets.length;
      state.snapshot = withSequence(state.snapshot, {
        status: complete ? snapshotStatus(state.snapshot.packages, true) : snapshotStatus(state.snapshot.packages, false),
        pendingDateOffsets: offsets.slice(state.offsetIndex),
        message,
      });
      if (complete) state.stage = "complete";
      await this.state.storage.put(SEARCH_STATE_KEY, state);
      if (!complete) await this.state.storage.setAlarm(Date.now() + 250);
    }
  }

  private async requote(request: Request) {
    const state = await this.state.storage.get<PersistedSearchState>(SEARCH_STATE_KEY);
    if (!state) return json({ ok: false, error: "SEARCH_NOT_FOUND" }, 404);
    try {
      const raw = await request.json() as Partial<ServerRequoteRequest>;
      if (!raw.packageKey || !["essential", "comfort", "luxury"].includes(raw.packageKey)) throw new Error("INVALID_PACKAGE_KEY");
      const definition = tierDefinitions(state.snapshot.mode).find((item) => item.key === raw.packageKey);
      if (!definition) throw new Error("PACKAGE_NOT_AVAILABLE_FOR_MODE");
      const outbound = state.outboundInternal.find((item) => item.id === raw.outboundCandidateId);
      const inbound = state.inboundInternal.find((item) => item.id === raw.inboundCandidateId);
      if (!outbound || !inbound) throw new Error("SERVER_FLIGHT_CANDIDATE_NOT_FOUND");
      if (outbound.dateOffset !== inbound.dateOffset) throw new Error("FLIGHT_DATE_PAIR_MISMATCH");
      const itinerary = shiftItinerary(state.baseItinerary, outbound.dateOffset);
      if (inbound.travelDate !== itinerary.endDate || outbound.travelDate !== itinerary.startDate) throw new Error("FLIGHT_DATE_PAIR_INVALID");

      const current = state.snapshot.packages.find((item) => item.key === raw.packageKey);
      const configured = state.packageHotels[raw.packageKey];
      if (!current?.hotelMakkah || !configured?.makkah) throw new Error("PACKAGE_HOTEL_NOT_READY");
      const requestedMakkahHotelId = raw.makkahHotelId ?? configured.makkah.hotelId;
      const requestedMakkahRoomId = raw.makkahRoomId ?? configured.makkah.roomId;
      const makkah = requestedMakkahHotelId !== configured.makkah.hotelId || requestedMakkahRoomId !== configured.makkah.roomId
        ? await customHotel(this.env, definition, "Makkah", requestedMakkahHotelId, requestedMakkahRoomId)
        : configured.makkah;
      let madinah: InternalHotelSnapshot | null = null;
      if (itinerary.includeMadinah) {
        if (!configured.madinah) throw new Error("PACKAGE_MADINAH_HOTEL_NOT_READY");
        const requestedMadinahHotelId = raw.madinahHotelId ?? configured.madinah.hotelId;
        const requestedMadinahRoomId = raw.madinahRoomId ?? configured.madinah.roomId;
        madinah = requestedMadinahHotelId !== configured.madinah.hotelId || requestedMadinahRoomId !== configured.madinah.roomId
          ? await customHotel(this.env, definition, "Madinah", requestedMadinahHotelId, requestedMadinahRoomId)
          : configured.madinah;
      }

      const priced = await quotePackage(this.env, state.snapshot.searchId, definition, itinerary, state.request.travelers, { makkah, madinah }, outbound, inbound);
      const updated: ServerGeneratedPackage = {
        ...current,
        hotelMakkah: publicHotel(makkah),
        hotelMadinah: madinah ? publicHotel(madinah) : null,
        status: "ready",
        blockReason: null,
        selectedOutboundCandidateId: outbound.id,
        selectedInboundCandidateId: inbound.id,
        selectedDateOffset: outbound.dateOffset,
        quote: {
          quoteId: priced.quote.quoteId,
          pricingVersion: priced.quote.pricingVersion,
          currency: priced.quote.currency,
          pricePerPerson: priced.quote.pricePerPerson,
          totalPackagePrice: priced.quote.totalPackagePrice,
          roomCount: priced.quote.roomCount,
          vehicleCount: priced.quote.vehicleCount,
        },
        quoteExpiresAt: priced.expiresAt,
      };
      return json({ ok: true, package: updated, itinerary });
    } catch (error) {
      return json({ ok: false, error: error instanceof Error ? error.message : "REQUOTE_FAILED" }, 409);
    }
  }
}

function namespace(env: Env) {
  if (!env.SEARCH_SESSIONS) throw new Error("SEARCH_SESSIONS_NOT_CONFIGURED");
  return env.SEARCH_SESSIONS;
}

export async function createPackageSearch(request: Request, env: Env) {
  const raw = await request.json();
  const input = normalizePackageSearchRequest(raw);
  const ns = namespace(env);
  const stub = ns.get(ns.idFromName(input.clientRequestId));
  return stub.fetch(new Request("https://search.internal/start", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(input),
  }));
}

export async function getPackageSearch(searchId: string, env: Env) {
  if (!/^[A-Za-z0-9_-]{12,120}$/.test(searchId)) return json({ ok: false, error: "INVALID_SEARCH_ID" }, 400);
  const ns = namespace(env);
  return ns.get(ns.idFromName(searchId)).fetch(new Request("https://search.internal/snapshot"));
}

export async function requotePackageSearch(searchId: string, request: Request, env: Env) {
  if (!/^[A-Za-z0-9_-]{12,120}$/.test(searchId)) return json({ ok: false, error: "INVALID_SEARCH_ID" }, 400);
  const body = await request.text();
  const ns = namespace(env);
  return ns.get(ns.idFromName(searchId)).fetch(new Request("https://search.internal/requote", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body,
  }));
}
