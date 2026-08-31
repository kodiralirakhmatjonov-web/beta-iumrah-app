import type { Env } from "./env";
import { searchOfficialCarrierProvider, officialCarrierBotIds } from "./server-flight-bots";

type City = "Makkah" | "Madinah";
type Direction = "outbound" | "inbound";

type Travelers = { adults: number; children: number; infants: number; rooms?: number };

type ProviderSearchRequest = {
  providerId: string;
  direction: Direction;
  origin: string;
  destination: string;
  travelDate: string;
  dateOffset?: number;
  travelers: Travelers;
};

function json(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
  });
}

function validAirport(value: unknown): value is string {
  return typeof value === "string" && /^[A-Z]{3}$/.test(value.toUpperCase());
}

function validDay(value: unknown): value is string {
  return typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value) && Number.isFinite(Date.parse(`${value}T00:00:00Z`));
}

function normalizeTravelers(value: Travelers | undefined) {
  const adults = Math.max(1, Math.floor(Number(value?.adults ?? 1)));
  const children = Math.max(0, Math.floor(Number(value?.children ?? 0)));
  const infants = Math.max(0, Math.floor(Number(value?.infants ?? 0)));
  if (![adults, children, infants].every(Number.isFinite)) throw new Error("INVALID_TRAVELERS");
  return { adults, children, infants, rooms: Math.max(1, Math.floor(Number(value?.rooms ?? 1))) };
}

export async function providerFlightSearch(request: Request, env: Env) {
  let input: ProviderSearchRequest;
  try { input = await request.json() as ProviderSearchRequest; }
  catch { return json({ ok: false, error: "INVALID_JSON" }, 400); }

  const providerId = String(input.providerId ?? "");
  const direction = input.direction;
  const origin = String(input.origin ?? "").toUpperCase();
  const destination = String(input.destination ?? "").toUpperCase();
  const travelDate = String(input.travelDate ?? "");
  if (!officialCarrierBotIds().includes(providerId)) return json({ ok: false, error: "UNKNOWN_FLIGHT_PROVIDER" }, 400);
  if (direction !== "outbound" && direction !== "inbound") return json({ ok: false, error: "INVALID_DIRECTION" }, 400);
  if (!validAirport(origin) || !validAirport(destination) || origin === destination || !validDay(travelDate)) {
    return json({ ok: false, error: "INVALID_FLIGHT_SEARCH_ROUTE" }, 400);
  }

  try {
    const travelers = normalizeTravelers(input.travelers);
    const result = await searchOfficialCarrierProvider(env, providerId, {
      searchId: `component-${crypto.randomUUID()}`,
      direction,
      dateOffset: Number.isFinite(Number(input.dateOffset)) ? Math.trunc(Number(input.dateOffset)) : 0,
      origin,
      destination,
      travelDate,
      travelers,
    });
    return json({
      ok: true,
      providerId,
      fromCache: result.fromCache,
      candidates: result.candidates.map(({ groupFareUsd: _internal, ...candidate }) => candidate),
      searchedAt: new Date().toISOString(),
    });
  } catch (error) {
    // One airline failing is a provider-level result, not a generator-level outage.
    return json({
      ok: true,
      providerId,
      fromCache: false,
      candidates: [],
      providerError: error instanceof Error ? error.message : "PROVIDER_SEARCH_FAILED",
      searchedAt: new Date().toISOString(),
    });
  }
}

export async function curatedPrimaryHotel(url: URL, env: Env) {
  if (!env.HOTELS_DB) return json({ ok: false, error: "HOTELS_DB binding is not configured" }, 503);
  const stars = Number(url.searchParams.get("stars"));
  const rawCity = url.searchParams.get("city");
  const city: City | null = rawCity === "Makkah" ? "Makkah" : rawCity === "Madinah" ? "Madinah" : null;
  if (!city || !Number.isInteger(stars) || stars < 1 || stars > 5) {
    return json({ ok: false, error: "stars and city are required" }, 400);
  }

  try {
    const curated = await env.HOTELS_DB.prepare(
      `SELECT p.position, h.id AS hotel_id, h.stars, h.city
       FROM primary_hotels p
       INNER JOIN hotels h ON h.id = p.hotel_id
       WHERE LOWER(p.city) = LOWER(?1)
         AND p.star_category = ?2
         AND h.status = 'published'
         AND h.stars = ?2
       ORDER BY p.position ASC
       LIMIT 1`,
    ).bind(city, stars).first<{ position: number; hotel_id: string; stars: number | null; city: string }>();

    if (curated) {
      return json({
        ok: true,
        hotelId: curated.hotel_id,
        roomId: null,
        tier: url.searchParams.get("tier") ?? null,
        stars: Number(curated.stars ?? stars),
        city,
        requestedTier: url.searchParams.get("tier") ?? null,
        requestedStars: stars,
        matchType: "curatedPrimary",
        isFallback: false,
        pricingMode: "recommendationOnly",
        position: Number(curated.position),
      });
    }

    const catalog = await env.HOTELS_DB.prepare(
      `SELECT id, stars, city
       FROM hotels
       WHERE status = 'published'
         AND LOWER(city) = LOWER(?1)
         AND stars = ?2
       ORDER BY rating DESC, review_count DESC, updated_at DESC
       LIMIT 1`,
    ).bind(city, stars).first<{ id: string; stars: number | null; city: string }>();
    if (!catalog) return json({ ok: false, error: `No published ${stars}-star hotel is available for ${city}` }, 404);
    return json({
      ok: true,
      hotelId: catalog.id,
      roomId: null,
      tier: url.searchParams.get("tier") ?? null,
      stars: Number(catalog.stars ?? stars),
      city,
      requestedTier: url.searchParams.get("tier") ?? null,
      requestedStars: stars,
      matchType: "catalogFallback",
      isFallback: true,
      pricingMode: "recommendationOnly",
      position: null,
    });
  } catch (error) {
    return json({ ok: false, error: error instanceof Error ? error.message : "PRIMARY_HOTEL_LOOKUP_FAILED" }, 500);
  }
}

export async function configuredHotelComponent(url: URL, env: Env) {
  if (!env.HOTELS_DB) return json({ ok: false, error: "HOTELS_DB binding is not configured" }, 503);
  const hotelId = (url.searchParams.get("hotelId") ?? "").trim();
  const roomId = (url.searchParams.get("roomId") ?? "").trim();
  if (!hotelId || hotelId.length > 180) return json({ ok: false, error: "hotelId is required" }, 400);

  try {
    const row = await env.HOTELS_DB.prepare(
      `SELECT hotel_id, room_id, base_price_usd, price_unit, updated_at
       FROM package_primary_hotels
       WHERE hotel_id = ?1
         AND active = 1
         AND (?2 = '' OR room_id = ?2)
       ORDER BY CASE WHEN ?2 <> '' AND room_id = ?2 THEN 0 ELSE 1 END, updated_at DESC
       LIMIT 1`,
    ).bind(hotelId, roomId).first<{
      hotel_id: string; room_id: string | null; base_price_usd: number; price_unit: string; updated_at: string;
    }>();
    if (!row) return json({ ok: false, error: "CONFIGURED_RATE_NOT_FOUND" }, 404);
    // If a concrete room was selected, never silently return another room's rate.
    if (roomId && row.room_id !== roomId) return json({ ok: false, error: "ROOM_RATE_NOT_FOUND" }, 404);
    return json({
      ok: true,
      hotelId: row.hotel_id,
      roomId: row.room_id,
      amount: Number(row.base_price_usd),
      currency: "USD",
      unit: row.price_unit,
      source: "configuredPrimary",
      observedAt: row.updated_at,
    });
  } catch (error) {
    return json({ ok: false, error: error instanceof Error ? error.message : "HOTEL_COMPONENT_LOOKUP_FAILED" }, 500);
  }
}
