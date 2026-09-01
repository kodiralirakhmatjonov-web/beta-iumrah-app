import { requirePackageAdmin } from "./admin-auth";
import { deleteAdminBooking, deletePilgrimBooking, updatePilgrimContact, updatePilgrimCustomization, updatePilgrimHotel } from "./booking-control";
import { countActiveHotelRoomCategories, ensureBookingRoomColumns, ensureHotelRoomCategories, listHotelRoomCategories } from "./room-categories";
import type { Env } from "./env";
import { curatedPrimaryHotel } from "./generator-components";

function json(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

async function publicHealth(env: Env) {
  if (!env.HOTELS_DB) {
    return json({
      ok: true,
      service: "iumrah-package-engine",
      hotelsDbConfigured: false,
      bookingsDbConfigured: Boolean(env.BOOKINGS_DB),
      primaryHotelConfigCount: 0,
      primaryHotelsReady: false,
      roomCategoriesReady: false,
    });
  }

  try {
    await ensureHotelRoomCategories(env.HOTELS_DB);
    if (env.BOOKINGS_DB) await ensureBookingRoomColumns(env.BOOKINGS_DB);
    const roomCategoryCount = await countActiveHotelRoomCategories(env.HOTELS_DB);

    const result = await env.HOTELS_DB.prepare(
      `SELECT LOWER(p.city) AS city, COUNT(*) AS count
       FROM primary_hotels p
       INNER JOIN hotels h ON h.id = p.hotel_id
       WHERE h.status = 'published'
       GROUP BY LOWER(p.city)`,
    ).all<{ city: string; count: number | string }>();

    const rows = result.results ?? [];
    const makkahCount = Number(rows.find((row) => row.city === "makkah")?.count ?? 0);
    const madinahCount = Number(rows.find((row) => row.city === "madinah")?.count ?? 0);
    const count = makkahCount + madinahCount;

    return json({
      ok: true,
      service: "iumrah-package-engine",
      hotelsDbConfigured: true,
      bookingsDbConfigured: Boolean(env.BOOKINGS_DB),
      primaryHotelConfigCount: count,
      primaryHotelConfigByCity: { Makkah: makkahCount, Madinah: madinahCount },
      primaryHotelsReady: makkahCount > 0,
      roomCategoriesReady: roomCategoryCount > 0,
      roomCategoryCount,
      bookingRoomColumnsReady: Boolean(env.BOOKINGS_DB),
    });
  } catch (error) {
    return json({
      ok: false,
      service: "iumrah-package-engine",
      hotelsDbConfigured: true,
      bookingsDbConfigured: Boolean(env.BOOKINGS_DB),
      primaryHotelConfigCount: 0,
      primaryHotelsReady: false,
      roomCategoriesReady: false,
      error: error instanceof Error ? error.message : "D1 health check failed",
    }, 503);
  }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname.startsWith("/api/admin/package")) {
      const auth = await requirePackageAdmin(request);
      if (!auth.ok) return auth.response;

      const adminBookingMatch = url.pathname.match(/^\/api\/admin\/package\/booking\/(IUM-\d{4}-[A-Z2-9]{7})$/);
      if (adminBookingMatch) {
        if (request.method === "DELETE") return deleteAdminBooking(adminBookingMatch[1], env);
        return json({ ok: false, error: "METHOD_NOT_ALLOWED" }, 405);
      }
      return json({ ok: false, error: "NOT_FOUND" }, 404);
    }

    const bookingContactMatch = url.pathname.match(/^\/api\/package\/booking\/(IUM-\d{4}-[A-Z2-9]{7})\/contact$/);
    if (bookingContactMatch) {
      if (request.method === "PATCH") return updatePilgrimContact(request, bookingContactMatch[1], env);
      return json({ ok: false, error: "METHOD_NOT_ALLOWED" }, 405);
    }

    const bookingCustomizationMatch = url.pathname.match(/^\/api\/package\/booking\/(IUM-\d{4}-[A-Z2-9]{7})\/customization$/);
    if (bookingCustomizationMatch) {
      if (request.method === "PATCH") return updatePilgrimCustomization(request, bookingCustomizationMatch[1], env);
      return json({ ok: false, error: "METHOD_NOT_ALLOWED" }, 405);
    }

    const bookingMatch = url.pathname.match(/^\/api\/package\/booking\/(IUM-\d{4}-[A-Z2-9]{7})$/);
    if (bookingMatch) {
      const bookingId = bookingMatch[1];
      if (request.method === "DELETE") return deletePilgrimBooking(request, bookingId, env);
      if (request.method === "PATCH") return updatePilgrimHotel(request, bookingId, env);
      return json({ ok: false, error: "METHOD_NOT_ALLOWED" }, 405);
    }

    if (request.method === "GET" && (url.pathname === "/health" || url.pathname === "/api/package/health")) {
      return publicHealth(env);
    }

    const hotelRoomCategoriesMatch = url.pathname.match(/^\/api\/package\/hotel\/([^/]+)\/room-categories$/);
    if (request.method === "GET" && hotelRoomCategoriesMatch) {
      if (!env.HOTELS_DB) return json({ ok: false, error: "HOTELS_DB binding is not configured" }, 503);
      try {
        const hotelId = decodeURIComponent(hotelRoomCategoriesMatch[1]).trim();
        if (!hotelId || hotelId.length > 180) return json({ ok: false, error: "INVALID_HOTEL" }, 400);
        const categories = await listHotelRoomCategories(env.HOTELS_DB, hotelId);
        if (!categories) return json({ ok: false, error: "HOTEL_NOT_FOUND" }, 404);
        return json({
          ok: true,
          hotelId,
          categories: categories.map((row) => ({
            id: row.id,
            hotelId: row.hotel_id,
            category: row.category,
            displayName: row.display_name,
            maxGuests: Number(row.max_guests),
            bedConfiguration: row.bed_configuration,
            position: Number(row.position),
            source: row.source,
          })),
        });
      } catch (error) {
        return json({ ok: false, error: error instanceof Error ? error.message : "ROOM_CATEGORIES_FAILED" }, 500);
      }
    }

    if (request.method === "GET" && url.pathname === "/api/package/primary-hotel") {
      return curatedPrimaryHotel(url, env);
    }

    return json({ ok: false, error: "Not found" }, 404);
  },
};
