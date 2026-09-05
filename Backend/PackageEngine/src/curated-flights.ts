import type { D1Like } from "./d1";

const IATA_AIRPORT = /^[A-Z]{3}$/;
const IATA_AIRLINE = /^[A-Z0-9]{2}$/;
const DATE = /^\d{4}-\d{2}-\d{2}$/;
const CURRENCY = /^[A-Z]{3}$/;

type CuratedLeg = {
  airline: string;
  flight_number: string;
  airline_code: string;
  origin: string;
  destination: string;
  departure_at: string;
  arrival_at: string;
  duration_minutes: number;
  stops: number;
  cabin_class: string;
  segments?: unknown[];
};

type CuratedItinerary = {
  id: string;
  source?: string;
  source_name?: string;
  observed_at: string;
  fare_scope?: string;
  price: { amount: number; currency: string; status?: string };
  legs: CuratedLeg[];
  cabin_class: string;
  bags?: { carry_on?: number | null; checked?: number | null } | null;
  requires_self_transfer?: boolean | null;
  ignav_id?: string;
};

type CuratedRow = {
  id: string;
  source_candidate_id: string;
  source_provider: string;
  outbound_origin: string;
  outbound_destination: string;
  inbound_origin: string | null;
  inbound_destination: string | null;
  outbound_date: string;
  inbound_date: string | null;
  cabin_class: string;
  airline_codes_json: string;
  airline_names_json: string;
  flight_numbers_json: string;
  itinerary_json: string;
  total_fare: number;
  per_traveler_fare: number;
  currency: string;
  traveler_count: number;
  observed_at: string;
  published: number;
  priority: number;
  created_by: string | null;
  created_at: string;
  updated_at: string;
};

function json(value: unknown, status = 200, cacheControl = "no-store") {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": cacheControl,
    },
  });
}

function safeText(value: unknown, max = 180): string {
  return typeof value === "string" ? value.trim().slice(0, max) : "";
}

function dateFromTimestamp(value: string): string {
  return value.slice(0, 10);
}

function validTimestamp(value: unknown): value is string {
  return typeof value === "string" && Number.isFinite(Date.parse(value));
}

function parseJSON<T>(value: string, fallback: T): T {
  try { return JSON.parse(value) as T; }
  catch { return fallback; }
}

function normalizeLeg(raw: unknown): CuratedLeg | null {
  if (!raw || typeof raw !== "object") return null;
  const value = raw as Record<string, unknown>;
  const airlineCode = safeText(value.airline_code, 2).toUpperCase();
  const origin = safeText(value.origin, 3).toUpperCase();
  const destination = safeText(value.destination, 3).toUpperCase();
  const departureAt = safeText(value.departure_at, 64);
  const arrivalAt = safeText(value.arrival_at, 64);
  const duration = Number(value.duration_minutes);
  const stops = Number(value.stops);
  if (!IATA_AIRPORT.test(origin) || !IATA_AIRPORT.test(destination) || origin === destination) return null;
  if (!validTimestamp(departureAt) || !validTimestamp(arrivalAt) || Date.parse(departureAt) >= Date.parse(arrivalAt)) return null;
  if (!Number.isInteger(stops) || stops < 0 || stops > 7) return null;
  if (!Number.isFinite(duration) || duration <= 0 || duration > 96 * 60) return null;
  return {
    airline: safeText(value.airline, 180) || airlineCode || "Airline",
    flight_number: safeText(value.flight_number, 80),
    airline_code: IATA_AIRLINE.test(airlineCode) ? airlineCode : "",
    origin,
    destination,
    departure_at: departureAt,
    arrival_at: arrivalAt,
    duration_minutes: Math.round(duration),
    stops,
    cabin_class: safeText(value.cabin_class, 40) || "economy",
    segments: Array.isArray(value.segments) ? value.segments.slice(0, 8) : undefined,
  };
}

function normalizeItinerary(raw: unknown): CuratedItinerary | null {
  if (!raw || typeof raw !== "object") return null;
  const value = raw as Record<string, unknown>;
  const rawPrice = value.price && typeof value.price === "object" ? value.price as Record<string, unknown> : null;
  const amount = Number(rawPrice?.amount);
  const currency = safeText(rawPrice?.currency, 3).toUpperCase();
  const status = safeText(rawPrice?.status, 40).toLowerCase();
  const legs = Array.isArray(value.legs) ? value.legs.map(normalizeLeg) : [];
  if (!Number.isFinite(amount) || amount <= 0 || amount > 1_000_000) return null;
  if (!CURRENCY.test(currency) || (status && status !== "verified")) return null;
  if (legs.length < 1 || legs.length > 2 || legs.some((item) => item === null)) return null;
  const safeLegs = legs as CuratedLeg[];
  if (safeLegs.some((leg) => leg.stops !== 0)) return null;
  const observedAt = safeText(value.observed_at, 64);
  if (!validTimestamp(observedAt)) return null;
  const id = safeText(value.id, 180) || safeText(value.ignav_id, 180);
  if (!id) return null;
  return {
    id,
    source: safeText(value.source, 40) || "ignav",
    source_name: safeText(value.source_name, 80) || "Ignav",
    observed_at: observedAt,
    fare_scope: safeText(value.fare_scope, 40) || "total_party",
    price: { amount, currency, status: status || "verified" },
    legs: safeLegs,
    cabin_class: safeText(value.cabin_class, 40) || safeLegs[0].cabin_class || "economy",
    bags: value.bags && typeof value.bags === "object" ? value.bags as CuratedItinerary["bags"] : null,
    requires_self_transfer: typeof value.requires_self_transfer === "boolean" ? value.requires_self_transfer : null,
    ignav_id: safeText(value.ignav_id, 180) || id,
  };
}

export async function ensureCuratedFlightSchema(db: D1Like): Promise<void> {
  await db.prepare(`CREATE TABLE IF NOT EXISTS curated_flight_offers (
    id TEXT PRIMARY KEY,
    source_candidate_id TEXT NOT NULL,
    source_provider TEXT NOT NULL DEFAULT 'ignav',
    outbound_origin TEXT NOT NULL,
    outbound_destination TEXT NOT NULL,
    inbound_origin TEXT,
    inbound_destination TEXT,
    outbound_date TEXT NOT NULL,
    inbound_date TEXT,
    cabin_class TEXT NOT NULL DEFAULT 'economy',
    airline_codes_json TEXT NOT NULL DEFAULT '[]',
    airline_names_json TEXT NOT NULL DEFAULT '[]',
    flight_numbers_json TEXT NOT NULL DEFAULT '[]',
    itinerary_json TEXT NOT NULL,
    total_fare REAL NOT NULL,
    per_traveler_fare REAL NOT NULL,
    currency TEXT NOT NULL,
    traveler_count INTEGER NOT NULL,
    observed_at TEXT NOT NULL,
    published INTEGER NOT NULL DEFAULT 1,
    priority INTEGER NOT NULL DEFAULT 100,
    created_by TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )`).run();
  await db.prepare(`CREATE INDEX IF NOT EXISTS idx_curated_flight_route_dates
    ON curated_flight_offers(outbound_origin, outbound_destination, inbound_origin, inbound_destination, outbound_date, inbound_date, published)`).run();
  await db.prepare(`CREATE INDEX IF NOT EXISTS idx_curated_flight_public_rank
    ON curated_flight_offers(published, outbound_date, priority, per_traveler_fare)`).run();
}

function mapAdminRow(row: CuratedRow) {
  return {
    id: row.id,
    sourceCandidateID: row.source_candidate_id,
    sourceProvider: row.source_provider,
    outboundOrigin: row.outbound_origin,
    outboundDestination: row.outbound_destination,
    inboundOrigin: row.inbound_origin,
    inboundDestination: row.inbound_destination,
    outboundDate: row.outbound_date,
    inboundDate: row.inbound_date,
    cabinClass: row.cabin_class,
    airlineCodes: parseJSON<string[]>(row.airline_codes_json, []),
    airlineNames: parseJSON<string[]>(row.airline_names_json, []),
    flightNumbers: parseJSON<string[]>(row.flight_numbers_json, []),
    itinerary: parseJSON<CuratedItinerary | null>(row.itinerary_json, null),
    totalFare: Number(row.total_fare),
    perTravelerFare: Number(row.per_traveler_fare),
    currency: row.currency,
    travelerCount: Number(row.traveler_count),
    observedAt: row.observed_at,
    published: Number(row.published) === 1,
    priority: Number(row.priority),
    createdBy: row.created_by,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export async function listCuratedFlightsAdmin(db: D1Like | undefined): Promise<Response> {
  if (!db) return json({ ok: false, error: "HOTELS_DB_NOT_CONFIGURED" }, 503);
  await ensureCuratedFlightSchema(db);
  const today = new Date().toISOString().slice(0, 10);
  const result = await db.prepare(`SELECT * FROM curated_flight_offers
    WHERE outbound_date >= ?
    ORDER BY published DESC, priority ASC, outbound_date ASC, per_traveler_fare ASC
    LIMIT 300`).bind(today).all<CuratedRow>();
  return json({ ok: true, offers: (result.results ?? []).map(mapAdminRow) });
}

export async function saveCuratedFlightAdmin(request: Request, db: D1Like | undefined, createdBy?: string): Promise<Response> {
  if (!db) return json({ ok: false, error: "HOTELS_DB_NOT_CONFIGURED" }, 503);
  await ensureCuratedFlightSchema(db);
  const payload = await request.json().catch(() => null) as Record<string, unknown> | null;
  if (!payload) return json({ ok: false, error: "INVALID_JSON" }, 400);
  const itinerary = normalizeItinerary(payload.itinerary);
  if (!itinerary) return json({ ok: false, error: "INVALID_CURATED_ITINERARY" }, 400);
  const travelerCount = Number(payload.travelerCount);
  if (!Number.isInteger(travelerCount) || travelerCount < 1 || travelerCount > 9) return json({ ok: false, error: "INVALID_TRAVELER_COUNT" }, 400);
  const published = payload.published === undefined ? true : payload.published === true;
  const priorityRaw = Number(payload.priority ?? 100);
  const priority = Number.isFinite(priorityRaw) ? Math.max(0, Math.min(9999, Math.round(priorityRaw))) : 100;
  const outbound = itinerary.legs[0];
  const inbound = itinerary.legs[1] ?? null;
  const outboundDate = dateFromTimestamp(outbound.departure_at);
  const inboundDate = inbound ? dateFromTimestamp(inbound.departure_at) : null;
  if (!DATE.test(outboundDate) || (inboundDate !== null && !DATE.test(inboundDate))) return json({ ok: false, error: "INVALID_CURATED_DATE" }, 400);
  const airlineCodes = [...new Set(itinerary.legs.map((leg) => leg.airline_code).filter(Boolean))];
  const airlineNames = [...new Set(itinerary.legs.map((leg) => leg.airline).filter(Boolean))];
  const flightNumbers = itinerary.legs.map((leg) => leg.flight_number).filter(Boolean);
  const perTravelerFare = itinerary.price.amount / travelerCount;
  const now = new Date().toISOString();

  const existing = await db.prepare(`SELECT id, created_at FROM curated_flight_offers
    WHERE source_candidate_id = ? AND outbound_date = ? AND COALESCE(inbound_date,'') = COALESCE(?, '')
    LIMIT 1`).bind(itinerary.id, outboundDate, inboundDate).first<{ id: string; created_at: string }>();
  const id = existing?.id ?? `curated-${crypto.randomUUID()}`;
  const createdAt = existing?.created_at ?? now;

  await db.prepare(`INSERT INTO curated_flight_offers (
    id, source_candidate_id, source_provider,
    outbound_origin, outbound_destination, inbound_origin, inbound_destination,
    outbound_date, inbound_date, cabin_class,
    airline_codes_json, airline_names_json, flight_numbers_json, itinerary_json,
    total_fare, per_traveler_fare, currency, traveler_count, observed_at,
    published, priority, created_by, created_at, updated_at
  ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ON CONFLICT(id) DO UPDATE SET
    source_candidate_id=excluded.source_candidate_id,
    source_provider=excluded.source_provider,
    outbound_origin=excluded.outbound_origin,
    outbound_destination=excluded.outbound_destination,
    inbound_origin=excluded.inbound_origin,
    inbound_destination=excluded.inbound_destination,
    outbound_date=excluded.outbound_date,
    inbound_date=excluded.inbound_date,
    cabin_class=excluded.cabin_class,
    airline_codes_json=excluded.airline_codes_json,
    airline_names_json=excluded.airline_names_json,
    flight_numbers_json=excluded.flight_numbers_json,
    itinerary_json=excluded.itinerary_json,
    total_fare=excluded.total_fare,
    per_traveler_fare=excluded.per_traveler_fare,
    currency=excluded.currency,
    traveler_count=excluded.traveler_count,
    observed_at=excluded.observed_at,
    published=excluded.published,
    priority=excluded.priority,
    created_by=excluded.created_by,
    updated_at=excluded.updated_at`)
    .bind(
      id, itinerary.id, itinerary.source ?? "ignav",
      outbound.origin, outbound.destination, inbound?.origin ?? null, inbound?.destination ?? null,
      outboundDate, inboundDate, itinerary.cabin_class,
      JSON.stringify(airlineCodes), JSON.stringify(airlineNames), JSON.stringify(flightNumbers), JSON.stringify(itinerary),
      itinerary.price.amount, perTravelerFare, itinerary.price.currency, travelerCount, itinerary.observed_at,
      published ? 1 : 0, priority, safeText(createdBy, 180) || null, createdAt, now,
    ).run();

  const row = await db.prepare(`SELECT * FROM curated_flight_offers WHERE id=? LIMIT 1`).bind(id).first<CuratedRow>();
  return json({ ok: true, offer: row ? mapAdminRow(row) : null });
}

export async function deleteCuratedFlightAdmin(id: string, db: D1Like | undefined): Promise<Response> {
  if (!db) return json({ ok: false, error: "HOTELS_DB_NOT_CONFIGURED" }, 503);
  await ensureCuratedFlightSchema(db);
  const cleanID = safeText(id, 180);
  if (!cleanID) return json({ ok: false, error: "INVALID_CURATED_FLIGHT_ID" }, 400);
  await db.prepare(`DELETE FROM curated_flight_offers WHERE id=?`).bind(cleanID).run();
  return json({ ok: true, deletedID: cleanID });
}

function validAirportParam(url: URL, key: string, required = true): string | null {
  const value = url.searchParams.get(key)?.trim().toUpperCase() ?? "";
  if (!value && !required) return null;
  return IATA_AIRPORT.test(value) ? value : null;
}

export async function publicCuratedFlightRecommendations(url: URL, db: D1Like | undefined): Promise<Response> {
  if (!db) return json({ ok: false, error: "HOTELS_DB_NOT_CONFIGURED" }, 503);
  await ensureCuratedFlightSchema(db);
  const outboundOrigin = validAirportParam(url, "outbound_origin");
  const outboundDestination = validAirportParam(url, "outbound_destination");
  const inboundOrigin = validAirportParam(url, "inbound_origin", false);
  const inboundDestination = validAirportParam(url, "inbound_destination", false);
  if (!outboundOrigin || !outboundDestination || outboundOrigin === outboundDestination ||
      (url.searchParams.has("inbound_origin") && !inboundOrigin) ||
      (url.searchParams.has("inbound_destination") && !inboundDestination)) {
    return json({ ok: false, error: "INVALID_CURATED_ROUTE" }, 400);
  }
  const from = safeText(url.searchParams.get("from"), 10) || new Date().toISOString().slice(0, 10);
  const to = safeText(url.searchParams.get("to"), 10) || "9999-12-31";
  if (!DATE.test(from) || !DATE.test(to) || from > to) return json({ ok: false, error: "INVALID_CURATED_RANGE" }, 400);

  const result = await db.prepare(`SELECT * FROM curated_flight_offers
    WHERE published = 1
      AND outbound_origin = ? AND outbound_destination = ?
      AND COALESCE(inbound_origin,'') = COALESCE(?, '')
      AND COALESCE(inbound_destination,'') = COALESCE(?, '')
      AND outbound_date BETWEEN ? AND ?
    ORDER BY priority ASC, per_traveler_fare ASC, outbound_date ASC
    LIMIT 24`)
    .bind(outboundOrigin, outboundDestination, inboundOrigin, inboundDestination, from, to)
    .all<CuratedRow>();

  const recommendations = (result.results ?? []).map((row) => {
    const itinerary = parseJSON<CuratedItinerary | null>(row.itinerary_json, null);
    if (!itinerary) return null;
    return {
      id: row.id,
      outboundDate: row.outbound_date,
      inboundDate: row.inbound_date,
      cabinClass: row.cabin_class,
      airlineCodes: parseJSON<string[]>(row.airline_codes_json, []),
      airlineNames: parseJSON<string[]>(row.airline_names_json, []),
      flightNumbers: parseJSON<string[]>(row.flight_numbers_json, []),
      observedAt: row.observed_at,
      outbound: itinerary.legs[0],
      inbound: itinerary.legs[1] ?? null,
      nonstop: itinerary.legs.every((leg) => leg.stops === 0),
      recommendationLabel: "iumrah recommends",
    };
  }).filter((value): value is NonNullable<typeof value> => value !== null);

  return json({ ok: true, recommendations, generatedAt: new Date().toISOString() }, 200, "public, max-age=60, s-maxage=300");
}

export async function curatedCalendarRows(
  db: D1Like,
  query: {
    outboundOrigin: string;
    outboundDestination: string;
    inboundOrigin: string | null;
    inboundDestination: string | null;
    cabinClass: string;
    travelerCount: number;
    from: string;
    to: string;
    selectedOutbound: string | null;
  },
): Promise<Array<{
  outbound_date: string;
  inbound_date: string | null;
  min_total_fare: number;
  min_per_traveler_fare: number;
  currency: string;
  observed_at: string;
}>> {
  await ensureCuratedFlightSchema(db);
  const result = await db.prepare(`SELECT outbound_date, inbound_date,
      per_traveler_fare * ? AS min_total_fare, per_traveler_fare AS min_per_traveler_fare,
      currency, observed_at
    FROM curated_flight_offers
    WHERE published = 1
      AND outbound_origin = ? AND outbound_destination = ?
      AND COALESCE(inbound_origin,'') = COALESCE(?, '')
      AND COALESCE(inbound_destination,'') = COALESCE(?, '')
      AND cabin_class = ?
      AND outbound_date BETWEEN ? AND ?
      AND (? IS NULL OR outbound_date = ?)
    ORDER BY outbound_date ASC, per_traveler_fare ASC`)
    .bind(
      query.travelerCount,
      query.outboundOrigin, query.outboundDestination, query.inboundOrigin, query.inboundDestination,
      query.cabinClass, query.from, query.to, query.selectedOutbound, query.selectedOutbound,
    ).all<{
      outbound_date: string;
      inbound_date: string | null;
      min_total_fare: number;
      min_per_traveler_fare: number;
      currency: string;
      observed_at: string;
    }>();
  return result.results ?? [];
}
