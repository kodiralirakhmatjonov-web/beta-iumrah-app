import type { Env } from "./env";

const IGNAV_BASE_URL = "https://ignav.com/api";
const IATA_AIRPORT = /^[A-Z]{3}$/;
const IATA_AIRLINE = /^[A-Z0-9]{2}$/;
const FLIGHT_NUMBER = /^[0-9]{1,4}[A-Z]?$/;
const CURRENCY = /^[A-Z]{3}$/;
const DATE = /^\d{4}-\d{2}-\d{2}$/;

const json = (value: unknown, status = 200) => new Response(JSON.stringify(value), {
  status,
  headers: {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
  },
});

type TimeRange = {
  earliest_hour?: number;
  latest_hour?: number;
  arrival_earliest_hour?: number;
  arrival_latest_hour?: number;
};

type SearchBody = {
  direction?: "outbound" | "inbound";
  origin?: string;
  destination?: string;
  departure_date?: string;
  adults?: number;
  children?: number;
  infants_in_seat?: number;
  infants_on_lap?: number;
  cabin_class?: "economy" | "premium_economy" | "business" | "first";
  max_stops?: number | null;
  min_carry_on_bags?: number | null;
  min_checked_bags?: number | null;
  max_price?: number | null;
  departure_time_range?: TimeRange | null;
  airlines_include?: string[] | null;
  airlines_exclude?: string[] | null;
  allow_self_transfer?: boolean;
};

type IgnavPrice = { amount?: number; currency?: string; status?: string };
type IgnavBag = { carry_on?: number | null; checked?: number | null };
type IgnavSegment = {
  marketing_carrier_code?: string | null;
  flight_number?: string | null;
  operating_carrier_name?: string | null;
  departure_airport?: string;
  departure_time_local?: string;
  departure_timezone?: string | null;
  departure_time_utc?: string | null;
  arrival_airport?: string;
  arrival_time_local?: string;
  arrival_timezone?: string | null;
  arrival_time_utc?: string | null;
  duration_minutes?: number;
  aircraft?: string | null;
};
type IgnavLeg = { carrier?: string | null; duration_minutes?: number | null; segments?: IgnavSegment[] };
type IgnavItinerary = {
  price?: IgnavPrice;
  outbound?: IgnavLeg;
  cabin_class?: string | null;
  bags?: IgnavBag | null;
  requires_self_transfer?: boolean | null;
  ignav_id?: string;
};
type IgnavResponse = {
  origin?: string;
  destination?: string;
  departure_date?: string;
  itineraries?: IgnavItinerary[];
};

function finiteInt(value: unknown, min: number, max: number): number | undefined {
  if (value === undefined || value === null) return undefined;
  if (!Number.isInteger(value)) return undefined;
  const n = Number(value);
  if (n < min || n > max) return undefined;
  return n;
}

function normalizeAirlines(value: unknown): string[] | undefined {
  if (value === undefined || value === null) return undefined;
  if (!Array.isArray(value) || value.length === 0 || value.length > 40) return undefined;
  const normalized = value.map((item) => String(item).trim().toUpperCase());
  if (normalized.some((code) => !IATA_AIRLINE.test(code))) return undefined;
  return [...new Set(normalized)];
}

function normalizeTimeRange(value: unknown): TimeRange | undefined {
  if (value === undefined || value === null) return undefined;
  if (typeof value !== "object") return undefined;
  const raw = value as Record<string, unknown>;
  const keys: (keyof TimeRange)[] = ["earliest_hour", "latest_hour", "arrival_earliest_hour", "arrival_latest_hour"];
  const result: TimeRange = {};
  for (const key of keys) {
    if (raw[key] === undefined || raw[key] === null) continue;
    const hour = finiteInt(raw[key], 0, 23);
    if (hour === undefined) return undefined;
    result[key] = hour;
  }
  if (result.earliest_hour !== undefined && result.latest_hour !== undefined && result.earliest_hour > result.latest_hour) return undefined;
  if (result.arrival_earliest_hour !== undefined && result.arrival_latest_hour !== undefined && result.arrival_earliest_hour > result.arrival_latest_hour) return undefined;
  return Object.keys(result).length ? result : undefined;
}

function validateSearchBody(raw: SearchBody) {
  const origin = String(raw.origin ?? "").trim().toUpperCase();
  const destination = String(raw.destination ?? "").trim().toUpperCase();
  const departureDate = String(raw.departure_date ?? "").trim();
  const adults = finiteInt(raw.adults ?? 1, 1, 9);
  const children = finiteInt(raw.children ?? 0, 0, 8);
  const infantsInSeat = finiteInt(raw.infants_in_seat ?? 0, 0, 8);
  const infantsOnLap = finiteInt(raw.infants_on_lap ?? 0, 0, 8);
  if (raw.direction !== undefined && raw.direction !== "outbound" && raw.direction !== "inbound") throw new Error("INVALID_DIRECTION");
  const cabin = raw.cabin_class ?? "economy";
  const maxStops = raw.max_stops === null || raw.max_stops === undefined ? undefined : finiteInt(raw.max_stops, 0, 2);
  const minCarryOn = raw.min_carry_on_bags === null || raw.min_carry_on_bags === undefined ? undefined : finiteInt(raw.min_carry_on_bags, 0, 9);
  const minChecked = raw.min_checked_bags === null || raw.min_checked_bags === undefined ? undefined : finiteInt(raw.min_checked_bags, 0, 9);
  const maxPrice = raw.max_price === null || raw.max_price === undefined ? undefined : finiteInt(raw.max_price, 1, 1_000_000);
  const include = normalizeAirlines(raw.airlines_include);
  const exclude = normalizeAirlines(raw.airlines_exclude);
  const timeRange = normalizeTimeRange(raw.departure_time_range);

  if (!IATA_AIRPORT.test(origin) || !IATA_AIRPORT.test(destination) || origin === destination) throw new Error("INVALID_ROUTE");
  if (!DATE.test(departureDate)) throw new Error("INVALID_DATE");
  const parsedDate = new Date(`${departureDate}T00:00:00Z`);
  if (!Number.isFinite(parsedDate.getTime()) || parsedDate.toISOString().slice(0, 10) !== departureDate) throw new Error("INVALID_DATE");
  if (raw.allow_self_transfer !== undefined && typeof raw.allow_self_transfer !== "boolean") throw new Error("INVALID_SELF_TRANSFER");
  if (adults === undefined || children === undefined || infantsInSeat === undefined || infantsOnLap === undefined) throw new Error("INVALID_PASSENGERS");
  if (adults + children + infantsInSeat + infantsOnLap > 9 || infantsOnLap > adults) throw new Error("INVALID_PASSENGERS");
  if (!["economy", "premium_economy", "business", "first"].includes(cabin)) throw new Error("INVALID_CABIN");
  if (raw.max_stops !== undefined && raw.max_stops !== null && maxStops === undefined) throw new Error("INVALID_MAX_STOPS");
  if (raw.min_carry_on_bags !== undefined && raw.min_carry_on_bags !== null && minCarryOn === undefined) throw new Error("INVALID_BAGS");
  if (raw.min_checked_bags !== undefined && raw.min_checked_bags !== null && minChecked === undefined) throw new Error("INVALID_BAGS");
  if (raw.max_price !== undefined && raw.max_price !== null && maxPrice === undefined) throw new Error("INVALID_MAX_PRICE");
  if (raw.departure_time_range !== undefined && raw.departure_time_range !== null && timeRange === undefined) throw new Error("INVALID_TIME_RANGE");
  if (raw.airlines_include !== undefined && raw.airlines_include !== null && include === undefined) throw new Error("INVALID_AIRLINES_INCLUDE");
  if (raw.airlines_exclude !== undefined && raw.airlines_exclude !== null && exclude === undefined) throw new Error("INVALID_AIRLINES_EXCLUDE");
  if (include && exclude && include.some((code) => exclude.includes(code))) throw new Error("CONFLICTING_AIRLINE_FILTERS");

  return {
    direction: raw.direction === "inbound" ? "inbound" as const : "outbound" as const,
    origin,
    destination,
    departure_date: departureDate,
    adults,
    children,
    infants_in_seat: infantsInSeat,
    infants_on_lap: infantsOnLap,
    cabin_class: cabin,
    max_stops: maxStops,
    min_carry_on_bags: minCarryOn,
    min_checked_bags: minChecked,
    max_price: maxPrice,
    departure_time_range: timeRange,
    airlines_include: include,
    airlines_exclude: exclude,
    allow_self_transfer: raw.allow_self_transfer ?? true,
    // iumrah package pricing is USD-native. Ignav currently has no UZ market,
    // so US market keeps fare currency aligned with the existing local engine.
    market: "US",
  };
}

async function fetchIgnav(apiKey: string, body: Record<string, unknown>) {
  let lastError: unknown;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 18_000);
    try {
      const response = await fetch(`${IGNAV_BASE_URL}/fares/one-way`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "accept": "application/json",
          "x-api-key": apiKey,
        },
        body: JSON.stringify(body),
        signal: controller.signal,
      });
      const text = await response.text();
      let payload: unknown = null;
      try { payload = text ? JSON.parse(text) : null; } catch { payload = null; }
      if (response.ok) return payload as IgnavResponse;

      const retryable = response.status === 424 || response.status === 503;
      if (!retryable || attempt === 2) {
        const upstreamCode = typeof payload === "object" && payload !== null
          ? String((payload as any)?.error?.code ?? `HTTP_${response.status}`)
          : `HTTP_${response.status}`;
        const error = new Error(`IGNAV_${upstreamCode}`) as Error & { status?: number; retryable?: boolean };
        error.status = response.status;
        error.retryable = false;
        throw error;
      }
      await new Promise((resolve) => setTimeout(resolve, 350 * (attempt + 1)));
    } catch (error) {
      lastError = error;
      const explicitlyNonRetryable = typeof error === "object" && error !== null && (error as { retryable?: boolean }).retryable === false;
      if (explicitlyNonRetryable || attempt === 2) throw error;
      await new Promise((resolve) => setTimeout(resolve, 350 * (attempt + 1)));
    } finally {
      clearTimeout(timer);
    }
  }
  throw lastError ?? new Error("IGNAV_REQUEST_FAILED");
}

function safeTimestamp(value: unknown): string | null {
  if (typeof value !== "string" || value.length < 16) return null;
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? value : null;
}

function normalizeItinerary(itinerary: IgnavItinerary, request: ReturnType<typeof validateSearchBody>, observedAt: string) {
  const price = itinerary.price;
  const leg = itinerary.outbound;
  const segments = Array.isArray(leg?.segments) ? leg!.segments! : [];
  if (!price || price.status !== "verified" || typeof price.amount !== "number" || !Number.isFinite(price.amount) || price.amount <= 0) return null;
  const currency = String(price.currency ?? "").toUpperCase();
  if (!CURRENCY.test(currency) || segments.length === 0 || segments.length > 4) return null;
  if (typeof itinerary.ignav_id !== "string" || itinerary.ignav_id.length < 8 || itinerary.ignav_id.length > 160) return null;

  const normalizedSegments = segments.map((segment) => {
    const airlineCode = String(segment.marketing_carrier_code ?? "").trim().toUpperCase();
    const number = String(segment.flight_number ?? "").trim().toUpperCase().replace(/^\D+/, "");
    const origin = String(segment.departure_airport ?? "").trim().toUpperCase();
    const destination = String(segment.arrival_airport ?? "").trim().toUpperCase();
    const departureLocal = safeTimestamp(segment.departure_time_local);
    const arrivalLocal = safeTimestamp(segment.arrival_time_local);
    const departureUTC = safeTimestamp(segment.departure_time_utc);
    const arrivalUTC = safeTimestamp(segment.arrival_time_utc);
    const duration = Number(segment.duration_minutes ?? 0);
    if (!IATA_AIRLINE.test(airlineCode) || !FLIGHT_NUMBER.test(number) || !IATA_AIRPORT.test(origin) || !IATA_AIRPORT.test(destination)) return null;
    if (!departureLocal || !arrivalLocal || !departureUTC || !arrivalUTC || duration <= 0 || duration > 48 * 60) return null;
    return {
      marketing_carrier_code: airlineCode,
      flight_number: number,
      operating_carrier_name: typeof segment.operating_carrier_name === "string" ? segment.operating_carrier_name.trim() || null : null,
      departure_airport: origin,
      departure_time_local: departureLocal,
      departure_timezone: typeof segment.departure_timezone === "string" ? segment.departure_timezone : null,
      departure_time_utc: departureUTC,
      arrival_airport: destination,
      arrival_time_local: arrivalLocal,
      arrival_timezone: typeof segment.arrival_timezone === "string" ? segment.arrival_timezone : null,
      arrival_time_utc: arrivalUTC,
      duration_minutes: duration,
      aircraft: typeof segment.aircraft === "string" ? segment.aircraft.trim() || null : null,
    };
  });

  if (normalizedSegments.some((segment) => segment === null)) return null;
  const safeSegments = normalizedSegments as NonNullable<(typeof normalizedSegments)[number]>[];
  if (safeSegments[0].departure_airport !== request.origin || safeSegments.at(-1)?.arrival_airport !== request.destination) return null;
  if (!safeSegments[0].departure_time_local.startsWith(request.departure_date)) return null;
  for (let index = 1; index < safeSegments.length; index += 1) {
    if (safeSegments[index - 1].arrival_airport !== safeSegments[index].departure_airport) return null;
    if (Date.parse(safeSegments[index].departure_time_utc) < Date.parse(safeSegments[index - 1].arrival_time_utc)) return null;
  }

  // Ignav leg duration includes connection time. Never synthesize it by summing
  // segment durations because that would silently omit layovers.
  const duration = Number(leg?.duration_minutes ?? 0);
  if (!Number.isFinite(duration) || duration <= 0 || duration > 72 * 60) return null;

  const bags = itinerary.bags && typeof itinerary.bags === "object" ? {
    carry_on: Number.isInteger(itinerary.bags.carry_on) && Number(itinerary.bags.carry_on) >= 0 ? Number(itinerary.bags.carry_on) : null,
    checked: Number.isInteger(itinerary.bags.checked) && Number(itinerary.bags.checked) >= 0 ? Number(itinerary.bags.checked) : null,
  } : null;

  const primary = safeSegments[0];
  return {
    id: itinerary.ignav_id,
    source: "ignav",
    source_name: "Ignav",
    direction: request.direction,
    observed_at: observedAt,
    fare_scope: "total_party",
    price: { amount: price.amount, currency, status: "verified" },
    airline: typeof leg?.carrier === "string" && leg.carrier.trim() ? leg.carrier.trim() : (primary.operating_carrier_name ?? primary.marketing_carrier_code),
    flight_number: `${primary.marketing_carrier_code} ${primary.flight_number}`,
    airline_code: primary.marketing_carrier_code,
    origin: request.origin,
    destination: request.destination,
    departure_at: primary.departure_time_utc,
    arrival_at: safeSegments.at(-1)!.arrival_time_utc,
    duration_minutes: duration,
    stops: safeSegments.length - 1,
    cabin_class: typeof itinerary.cabin_class === "string" ? itinerary.cabin_class : request.cabin_class,
    bags,
    requires_self_transfer: itinerary.requires_self_transfer ?? null,
    ignav_id: itinerary.ignav_id,
    segments: safeSegments,
  };
}

export async function searchIgnavFlights(request: Request, env: Env): Promise<Response> {
  if (!env.IGNAV_API_KEY) return json({ ok: false, error: "FLIGHT_PROVIDER_NOT_CONFIGURED" }, 503);
  let raw: SearchBody;
  try {
    raw = (await request.json()) as SearchBody;
  } catch {
    return json({ ok: false, error: "INVALID_JSON" }, 400);
  }

  let body: ReturnType<typeof validateSearchBody>;
  try {
    body = validateSearchBody(raw);
  } catch (error) {
    return json({ ok: false, error: error instanceof Error ? error.message : "INVALID_REQUEST" }, 400);
  }

  try {
    const { direction, ...ignavRequest } = body;
    const observedAt = new Date().toISOString();
    const upstream = await fetchIgnav(env.IGNAV_API_KEY, ignavRequest);
    const itineraries = (upstream.itineraries ?? [])
      .map((itinerary) => normalizeItinerary(itinerary, body, observedAt))
      .filter((value): value is NonNullable<typeof value> => value !== null);

    return json({
      ok: true,
      source: "ignav",
      direction,
      origin: body.origin,
      destination: body.destination,
      departure_date: body.departure_date,
      observed_at: observedAt,
      itineraries,
    });
  } catch (error) {
    const status = Number((error as any)?.status ?? 0);
    const retryable = status === 424 || status === 503 || status === 0;
    return json({
      ok: false,
      error: "FLIGHT_SEARCH_UPSTREAM_FAILED",
      retryable,
      upstream_status: status || null,
    }, retryable ? 503 : 502);
  }
}
