import type { D1Like } from "./d1";
import { ensureCuratedFlightSchema } from "./curated-flights";

type StorefrontLeg = {
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
};

type StorefrontItinerary = {
  id: string;
  observed_at: string;
  legs: StorefrontLeg[];
  bags?: { carry_on?: number | null; checked?: number | null } | null;
};

type CuratedRow = {
  id: string;
  outbound_origin: string;
  outbound_destination: string;
  inbound_origin: string | null;
  inbound_destination: string | null;
  outbound_date: string;
  inbound_date: string | null;
  itinerary_json: string;
  total_fare: number;
  per_traveler_fare: number;
  currency: string;
  traveler_count: number;
  observed_at: string;
  priority: number;
};

type PublicOption = {
  id: string;
  kind: "open_jaw" | "one_way";
  priority: number;
  currency: string;
  travelerCount: number;
  totalFare: number;
  perTravelerFare: number;
  observedAt: string;
  outbound: StorefrontLeg;
  inbound: StorefrontLeg | null;
  baggage: { carryOn: number | null; checked: number | null } | null;
};

function responseJSON(value: unknown, status = 200): Response {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

function parseJSON<T>(value: string): T | null {
  try { return JSON.parse(value) as T; }
  catch { return null; }
}

function validOrigin(value: string): boolean {
  return /^[A-Z]{3}$/.test(value);
}

function mapRow(row: CuratedRow): PublicOption | null {
  const itinerary = parseJSON<StorefrontItinerary>(row.itinerary_json);
  if (!itinerary || !Array.isArray(itinerary.legs) || itinerary.legs.length < 1 || itinerary.legs.length > 2) return null;
  const outbound = itinerary.legs[0];
  const inbound = itinerary.legs[1] ?? null;
  if (!outbound || outbound.stops !== 0 || (inbound && inbound.stops !== 0)) return null;

  const totalFare = Number(row.total_fare);
  const perTravelerFare = Number(row.per_traveler_fare);
  const travelerCount = Number(row.traveler_count);
  if (!Number.isFinite(totalFare) || totalFare <= 0 || !Number.isFinite(perTravelerFare) || perTravelerFare <= 0) return null;
  if (!Number.isInteger(travelerCount) || travelerCount < 1) return null;

  return {
    id: row.id,
    kind: inbound ? "open_jaw" : "one_way",
    priority: Number(row.priority) || 100,
    currency: row.currency,
    travelerCount,
    totalFare,
    perTravelerFare,
    observedAt: row.observed_at,
    outbound,
    inbound,
    baggage: itinerary.bags ? {
      carryOn: itinerary.bags.carry_on ?? null,
      checked: itinerary.bags.checked ?? null,
    } : null,
  };
}

function routeIsExactOpenJaw(option: PublicOption, origin: string): boolean {
  return option.outbound.origin === origin &&
    option.outbound.destination === "MED" &&
    option.inbound?.origin === "JED" &&
    option.inbound.destination === origin;
}

function chooseBaseline(options: PublicOption[], origin: string) {
  const exactPairs = options
    .filter((option) => option.currency.toUpperCase() === "USD" && routeIsExactOpenJaw(option, origin))
    .sort((a, b) => a.priority - b.priority || a.perTravelerFare - b.perTravelerFare || a.outbound.departure_at.localeCompare(b.outbound.departure_at));

  const paired = exactPairs[0];
  if (paired?.inbound) {
    return {
      mode: "published_open_jaw",
      travelers: 2,
      currency: "USD",
      perTravelerFareUsd: paired.perTravelerFare,
      totalFareUsd: paired.perTravelerFare * 2,
      outboundOfferID: paired.id,
      inboundOfferID: paired.id,
      outbound: paired.outbound,
      inbound: paired.inbound,
      observedAt: paired.observedAt,
    };
  }

  const outboundOptions = options
    .filter((option) => option.kind === "one_way" && option.currency.toUpperCase() === "USD" && option.outbound.origin === origin && option.outbound.destination === "MED")
    .sort((a, b) => a.priority - b.priority || a.perTravelerFare - b.perTravelerFare || a.outbound.departure_at.localeCompare(b.outbound.departure_at));
  const inboundOptions = options
    .filter((option) => option.kind === "one_way" && option.currency.toUpperCase() === "USD" && option.outbound.origin === "JED" && option.outbound.destination === origin)
    .sort((a, b) => a.priority - b.priority || a.perTravelerFare - b.perTravelerFare || a.outbound.departure_at.localeCompare(b.outbound.departure_at));

  // Storefront prices are intentionally date-independent. The pilgrim has not
  // chosen travel dates on this screen yet, so we select the best currently
  // published direct leg in each direction independently. Exact dates are
  // resolved later in the dated package builder. This keeps hotel cards priced
  // whenever Business has at least one TAS→MED and one JED→TAS publication.
  const outbound = outboundOptions[0];
  const inbound = inboundOptions[0];
  if (!outbound || !inbound) return null;

  const perTravelerFareUsd = outbound.perTravelerFare + inbound.perTravelerFare;
  return {
    mode: "combined_published_one_way",
    travelers: 2,
    currency: "USD",
    perTravelerFareUsd,
    totalFareUsd: perTravelerFareUsd * 2,
    outboundOfferID: outbound.id,
    inboundOfferID: inbound.id,
    outbound: outbound.outbound,
    inbound: inbound.outbound,
    observedAt: outbound.observedAt > inbound.observedAt ? outbound.observedAt : inbound.observedAt,
  };
}

export async function publicStorefrontFlightBoard(url: URL, db: D1Like | undefined): Promise<Response> {
  if (!db) return responseJSON({ ok: false, error: "HOTELS_DB_NOT_CONFIGURED" }, 503);
  await ensureCuratedFlightSchema(db);

  const origin = (url.searchParams.get("origin") ?? "TAS").trim().toUpperCase();
  if (!validOrigin(origin)) return responseJSON({ ok: false, error: "INVALID_ORIGIN" }, 400);

  const today = new Date().toISOString().slice(0, 10);
  const result = await db.prepare(`SELECT id, outbound_origin, outbound_destination,
      inbound_origin, inbound_destination, outbound_date, inbound_date, itinerary_json,
      total_fare, per_traveler_fare, currency, traveler_count, observed_at, priority
    FROM curated_flight_offers
    WHERE published = 1
      AND outbound_date >= ?
      AND (
        (outbound_origin = ? AND outbound_destination IN ('MED','JED')) OR
        (outbound_origin IN ('MED','JED') AND outbound_destination = ?)
      )
    ORDER BY priority ASC, outbound_date ASC, per_traveler_fare ASC
    LIMIT 100`)
    .bind(today, origin, origin)
    .all<CuratedRow>();

  const options = (result.results ?? []).map(mapRow).filter((value): value is PublicOption => value !== null);
  const baseline = chooseBaseline(options, origin);

  return responseJSON({
    ok: true,
    origin,
    generatedAt: new Date().toISOString(),
    baseline,
    options,
  });
}

export function appleAppSiteAssociation(): Response {
  const body = {
    applinks: {
      details: [{
        appIDs: ["2DQ678JTNG.com.iumrah.beta"],
        components: [
          { "/": "/h/*", comment: "Open public iumrah hotel links in the iOS app without exposing supplier identifiers." },
          { "/": "/hotel/*", comment: "Backward compatibility for hotel links shared by older beta builds." },
        ],
      }],
    },
  };
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "public, max-age=3600",
    },
  });
}

export function hotelWebFallback(_url: URL): Response {
  // Public share pages never render the internal hotel identifier. Supplier names
  // such as Expedia/Booking may exist inside the private D1 ID, but they must not
  // appear in the customer-facing URL preview or fallback page.
  const html = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>iumrah Hotels</title><meta name="description" content="Open this hotel in iumrah to see the stay and complete Umrah package price."><style>
body{margin:0;background:#f7f7f8;color:#111;font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text",sans-serif;display:grid;min-height:100vh;place-items:center}
main{width:min(560px,calc(100% - 40px));background:#fff;border:1px solid rgba(0,0,0,.06);border-radius:30px;padding:34px;box-sizing:border-box;box-shadow:0 16px 50px rgba(0,0,0,.06)}
h1{font-size:34px;margin:0 0 10px;letter-spacing:-1px}p{color:#666;line-height:1.5;margin:0}
</style></head><body><main><h1>iumrah Hotels</h1><p>Open this hotel in the iumrah app to see its curated stay details and current Umrah package price.</p></main></body></html>`;
  return new Response(html, {
    status: 200,
    headers: { "content-type": "text/html; charset=utf-8", "cache-control": "public, max-age=300" },
  });
}
