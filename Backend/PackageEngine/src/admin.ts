import type { PackageTier, PrimaryHotelRecord } from "./types";
import type { D1Like } from "./primary-hotels";

export type PackageAdminEnv = {
  HOTELS_DB?: D1Like;
  AUTH_SESSION_URL?: string;
};

type StaffUser = {
  id?: string;
  email?: string;
  role?: string;
};

function json(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

export async function requirePackageAdmin(request: Request, env: PackageAdminEnv): Promise<{ ok: true; user: StaffUser } | { ok: false; response: Response }> {
  const cookie = request.headers.get("cookie") ?? "";
  if (!cookie) return { ok: false, response: json({ ok: false, error: "UNAUTHORIZED" }, 401) };

  let response: Response;
  try {
    response = await fetch(env.AUTH_SESSION_URL ?? "https://iumrah.app/api/auth/staff/session", {
      method: "GET",
      headers: {
        cookie,
        accept: "application/json",
        "user-agent": request.headers.get("user-agent") ?? "iumrah-business",
      },
      redirect: "manual",
    });
  } catch {
    return { ok: false, response: json({ ok: false, error: "AUTH_SERVICE_UNAVAILABLE" }, 503) };
  }

  if (!response.ok) return { ok: false, response: json({ ok: false, error: "UNAUTHORIZED" }, 401) };
  const payload = await response.json().catch(() => null) as { user?: StaffUser } | null;
  const user = payload?.user;
  const role = String(user?.role ?? "").toLowerCase();
  if (!user || !["superadmin", "admin"].includes(role)) {
    return { ok: false, response: json({ ok: false, error: "FORBIDDEN" }, 403) };
  }
  return { ok: true, user };
}

function isTier(value: unknown): value is PackageTier {
  return ["economy", "standard", "comfort", "luxury"].includes(String(value));
}

function isCity(value: unknown): value is "Makkah" | "Madinah" {
  return value === "Makkah" || value === "Madinah";
}

function positiveOrZero(value: unknown, name: string) {
  const number = Number(value);
  if (!Number.isFinite(number) || number < 0) throw new Error(`${name} must be >= 0`);
  return number;
}

function validStars(value: unknown) {
  const stars = Number(value);
  if (!Number.isInteger(stars) || stars < 1 || stars > 5) throw new Error("stars must be an integer from 1 to 5");
  return stars;
}

export async function listPrimaryHotels(env: PackageAdminEnv): Promise<Response> {
  if (!env.HOTELS_DB) return json({ ok: false, error: "HOTELS_DB binding is not configured" }, 503);
  const result = await env.HOTELS_DB.prepare(
    `SELECT p.id, p.package_tier, p.stars, p.city, p.hotel_id, p.room_id,
            p.base_price_usd, p.price_unit, p.active, p.updated_at,
            h.name AS hotel_name, h.status AS hotel_status
     FROM package_primary_hotels p
     LEFT JOIN hotels h ON h.id = p.hotel_id
     ORDER BY p.package_tier, p.stars, p.city`,
  ).all<Record<string, unknown>>();
  return json({ ok: true, primaryHotels: result.results ?? [] });
}

export async function upsertPrimaryHotel(request: Request, env: PackageAdminEnv): Promise<Response> {
  if (!env.HOTELS_DB) return json({ ok: false, error: "HOTELS_DB binding is not configured" }, 503);
  const body = await request.json().catch(() => null) as Record<string, unknown> | null;
  if (!body) return json({ ok: false, error: "Invalid JSON body" }, 400);

  try {
    if (!isTier(body.tier)) throw new Error("Invalid package tier");
    if (!isCity(body.city)) throw new Error("Invalid city");
    const stars = validStars(body.stars);
    const hotelId = String(body.hotelId ?? "").trim();
    if (!hotelId) throw new Error("hotelId is required");
    const roomId = body.roomId == null || String(body.roomId).trim() === "" ? null : String(body.roomId).trim();
    const basePriceUsd = positiveOrZero(body.basePriceUsd, "basePriceUsd");
    const priceUnit = body.priceUnit === "perRoomStay" ? "perRoomStay" : "perRoomNight";
    const active = body.active === false || body.active === 0 ? 0 : 1;

    const hotel = await env.HOTELS_DB.prepare(
      "SELECT id, city, stars, status FROM hotels WHERE id = ?1 LIMIT 1",
    ).bind(hotelId).first<{ id: string; city: string; stars: number | null; status: string }>();
    if (!hotel) throw new Error("Hotel not found in iumrah Hotels");
    if (hotel.status !== "published") throw new Error("Primary Hotel must be published");
    if (hotel.city !== body.city) throw new Error(`Hotel city is ${hotel.city}, expected ${body.city}`);
    if (hotel.stars != null && Number(hotel.stars) !== stars) throw new Error(`Hotel is ${hotel.stars}★, expected ${stars}★`);

    if (roomId) {
      const room = await env.HOTELS_DB.prepare(
        "SELECT id FROM hotel_rooms WHERE id = ?1 AND hotel_id = ?2 LIMIT 1",
      ).bind(roomId, hotelId).first<{ id: string }>();
      if (!room) throw new Error("roomId does not belong to the selected hotel");
    }

    const id = `primary:${body.tier}:${stars}:${body.city}`;
    await env.HOTELS_DB.prepare(
      `INSERT INTO package_primary_hotels
         (id, package_tier, stars, city, hotel_id, room_id, base_price_usd, price_unit, active, updated_at)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, strftime('%Y-%m-%dT%H:%M:%fZ','now'))
       ON CONFLICT(package_tier, stars, city) DO UPDATE SET
         hotel_id = excluded.hotel_id,
         room_id = excluded.room_id,
         base_price_usd = excluded.base_price_usd,
         price_unit = excluded.price_unit,
         active = excluded.active,
         updated_at = excluded.updated_at`,
    ).bind(id, body.tier, stars, body.city, hotelId, roomId, basePriceUsd, priceUnit, active).run();

    const row = await env.HOTELS_DB.prepare(
      `SELECT id, package_tier, stars, city, hotel_id, room_id, base_price_usd, price_unit, active, updated_at
       FROM package_primary_hotels WHERE package_tier = ?1 AND stars = ?2 AND city = ?3 LIMIT 1`,
    ).bind(body.tier, stars, body.city).first<PrimaryHotelRecord>();

    return json({ ok: true, primaryHotel: row });
  } catch (error) {
    return json({ ok: false, error: error instanceof Error ? error.message : "Invalid primary hotel" }, 400);
  }
}

export async function deletePrimaryHotel(request: Request, env: PackageAdminEnv): Promise<Response> {
  if (!env.HOTELS_DB) return json({ ok: false, error: "HOTELS_DB binding is not configured" }, 503);
  const url = new URL(request.url);
  const tier = url.searchParams.get("tier");
  const city = url.searchParams.get("city");
  const starsRaw = url.searchParams.get("stars");
  if (!isTier(tier) || !isCity(city)) return json({ ok: false, error: "tier, stars and city are required" }, 400);

  try {
    const stars = validStars(starsRaw);
    await env.HOTELS_DB.prepare(
      "DELETE FROM package_primary_hotels WHERE package_tier = ?1 AND stars = ?2 AND city = ?3",
    ).bind(tier, stars, city).run();
    return json({ ok: true });
  } catch (error) {
    return json({ ok: false, error: error instanceof Error ? error.message : "Invalid request" }, 400);
  }
}
