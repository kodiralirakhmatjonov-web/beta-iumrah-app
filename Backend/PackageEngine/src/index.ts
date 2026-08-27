import { calculatePackageQuote } from "./pricing";
import { quoteFlightOptions } from "./flight-options";
import { resolvePrimaryHotel, type D1Like } from "./primary-hotels";
import { legacyEstimatedHotelCost } from "./hotel-fallback";
import { deletePrimaryHotel, listPrimaryHotels, requirePackageAdmin, upsertPrimaryHotel } from "./admin";
import { deleteAdminBooking, deletePilgrimBooking, updatePilgrimContact, updatePilgrimCustomization, updatePilgrimHotel } from "./booking-control";
import { countActiveHotelRoomCategories, ensureBookingRoomColumns, ensureHotelRoomCategories, listHotelRoomCategories } from "./room-categories";
import type { ConsumerPackageQuoteRequest, FlightOptionsQuoteRequest, PackageQuoteRequest, PublicPackageQuote } from "./types";

type Env = {
  PRICING_VERSION?: string;
  HOTELS_DB?: D1Like;
  BOOKINGS_DB?: D1Like & { batch(statements: import("./primary-hotels").D1PreparedStatementLike[]): Promise<unknown[]> };
  CBU_FX_URL?: string;
  AUTH_SESSION_URL?: string;
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

async function resolveConsumerQuote(input: ConsumerPackageQuoteRequest, env: Env) {
  if (!env.HOTELS_DB) throw new Error("HOTELS_DB binding is not configured");

  let makkahCost;
  let madinahCost = null;

  try {
    const makkah = await resolvePrimaryHotel(
      env.HOTELS_DB,
      input.tier,
      input.hotelStars,
      "Makkah",
      input.primaryHotelIds?.makkah,
    );
    makkahCost = {
      amountUsd: Number(makkah.base_price_usd),
      unit: makkah.price_unit,
      nights: Math.max(1, input.nights.makkah),
    } as const;

    if (input.includeMadinah) {
      const madinah = await resolvePrimaryHotel(
        env.HOTELS_DB,
        input.tier,
        input.hotelStars,
        "Madinah",
        input.primaryHotelIds?.madinah,
      );
      madinahCost = {
        amountUsd: Number(madinah.base_price_usd),
        unit: madinah.price_unit,
        nights: Math.max(1, input.nights.madinah),
      } as const;
    }
  } catch {
    makkahCost = legacyEstimatedHotelCost(
      input.hotelStars,
      "Makkah",
      input.nights.makkah,
      input.travelStartDate,
    );
    madinahCost = input.includeMadinah
      ? legacyEstimatedHotelCost(
          input.hotelStars,
          "Madinah",
          input.nights.madinah,
          input.travelStartDate,
        )
      : null;
  }

  const coreInput: PackageQuoteRequest = {
    tier: input.tier,
    includeMadinah: input.includeMadinah,
    totalDays: input.totalDays,
    travelers: input.travelers,
    flights: input.flights,
    hotels: {
      makkah: makkahCost,
      madinah: madinahCost,
    },
    customization: input.customization,
  };

  return calculatePackageQuote(coreInput, env.PRICING_VERSION ?? "iumrah-web-v1-beta-0.12");
}

async function publicHealth(env: Env) {
  if (!env.HOTELS_DB) {
    return json({
      ok: true,
      service: "iumrah-package-engine",
      pricingVersion: env.PRICING_VERSION ?? "iumrah-web-v1-beta-0.12",
      hotelsDbConfigured: false,
      bookingsDbConfigured: Boolean(env.BOOKINGS_DB),
      primaryHotelConfigCount: 0,
      pricingReady: false,
      flightOptionQuotingReady: false,
      legacyEstimateFallbackEnabled: true,
    });
  }

  try {
    await ensureHotelRoomCategories(env.HOTELS_DB);
    if (env.BOOKINGS_DB) await ensureBookingRoomColumns(env.BOOKINGS_DB);
    const roomCategoryCount = await countActiveHotelRoomCategories(env.HOTELS_DB);

    let makkahCount = 0;
    let madinahCount = 0;
    try {
      const result = await env.HOTELS_DB.prepare(
        `SELECT p.city, COUNT(*) AS count
         FROM package_primary_hotels p
         INNER JOIN hotels h ON h.id = p.hotel_id
         WHERE p.active = 1
           AND h.status = 'published'
           AND h.city = p.city
         GROUP BY p.city`,
      ).all<{ city: string; count: number | string }>();
      const rows = result.results ?? [];
      makkahCount = Number(rows.find((row) => row.city === "Makkah")?.count ?? 0);
      madinahCount = Number(rows.find((row) => row.city === "Madinah")?.count ?? 0);
    } catch {
      // The beta can still quote with the legacy estimate fallback if the optional
      // Primary Hotel mapping table is empty or has not been populated yet.
    }

    const count = makkahCount + madinahCount;
    return json({
      ok: true,
      service: "iumrah-package-engine",
      pricingVersion: env.PRICING_VERSION ?? "iumrah-web-v1-beta-0.12",
      hotelsDbConfigured: true,
      bookingsDbConfigured: Boolean(env.BOOKINGS_DB),
      primaryHotelConfigCount: count,
      primaryHotelConfigByCity: { Makkah: makkahCount, Madinah: madinahCount },
      pricingReady: true,
      makkahPricingReady: true,
      madinahPricingReady: true,
      fallbackResolutionEnabled: true,
      legacyEstimateFallbackEnabled: true,
      flightOptionQuotingReady: true,
      pricingMode: count > 0 ? "mixed" : "legacyEstimate",
      roomCategoriesReady: roomCategoryCount > 0,
      roomCategoryCount,
      bookingRoomColumnsReady: Boolean(env.BOOKINGS_DB),
    });
  } catch (error) {
    return json({
      ok: false,
      service: "iumrah-package-engine",
      pricingVersion: env.PRICING_VERSION ?? "iumrah-web-v1-beta-0.12",
      hotelsDbConfigured: true,
      bookingsDbConfigured: Boolean(env.BOOKINGS_DB),
      primaryHotelConfigCount: 0,
      pricingReady: false,
      flightOptionQuotingReady: false,
      legacyEstimateFallbackEnabled: true,
      error: error instanceof Error ? error.message : "D1 health check failed",
    }, 503);
  }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname.startsWith("/api/admin/package")) {
      const auth = await requirePackageAdmin(request, env);
      if (!auth.ok) return auth.response;

      if (url.pathname === "/api/admin/package/primary-hotels") {
        if (request.method === "GET") return listPrimaryHotels(env);
        if (request.method === "PUT" || request.method === "POST") return upsertPrimaryHotel(request, env);
        if (request.method === "DELETE") return deletePrimaryHotel(request, env);
        return json({ ok: false, error: "METHOD_NOT_ALLOWED" }, 405);
      }

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
      if (!env.HOTELS_DB) return json({ ok: false, error: "HOTELS_DB binding is not configured" }, 503);
      const tier = url.searchParams.get("tier") as ConsumerPackageQuoteRequest["tier"] | null;
      const stars = Number(url.searchParams.get("stars"));
      const city = url.searchParams.get("city");
      if (!tier || !Number.isInteger(stars) || (city !== "Makkah" && city !== "Madinah")) {
        return json({ ok: false, error: "tier, stars and city are required" }, 400);
      }
      try {
        const row = await resolvePrimaryHotel(env.HOTELS_DB, tier, stars, city);
        return json({
          ok: true,
          hotelId: row.hotel_id,
          roomId: row.room_id,
          tier: row.package_tier,
          stars: row.stars,
          city: row.city,
          requestedTier: row.requestedTier,
          requestedStars: row.requestedStars,
          matchType: row.matchType,
          isFallback: row.matchType !== "exact",
          pricingMode: "configuredPrimary",
        });
      } catch {
        const catalog = await env.HOTELS_DB.prepare(
          `SELECT id, stars, city
           FROM hotels
           WHERE status = 'published' AND city = ?1
           ORDER BY CASE WHEN stars = ?2 THEN 0 ELSE 1 END,
                    ABS(COALESCE(stars, ?2) - ?2),
                    updated_at DESC
           LIMIT 1`,
        ).bind(city, stars).first<{ id: string; stars: number | null; city: string }>();
        if (!catalog) return json({ ok: false, error: `No published hotel is available for ${city}` }, 404);
        return json({
          ok: true,
          hotelId: catalog.id,
          roomId: null,
          tier,
          stars: Number(catalog.stars ?? stars),
          city,
          requestedTier: tier,
          requestedStars: stars,
          matchType: "catalogFallback",
          isFallback: true,
          pricingMode: "legacyEstimate",
        });
      }
    }

    if (request.method === "POST" && url.pathname === "/api/package/quote") {
      try {
        const input = (await request.json()) as ConsumerPackageQuoteRequest;
        const result = await resolveConsumerQuote(input, env);
        return json(publicOnly(result));
      } catch (error) {
        return json({ ok: false, error: error instanceof Error ? error.message : "Invalid quote request" }, 400);
      }
    }

    if (request.method === "POST" && url.pathname === "/api/package/flight-options/quote") {
      try {
        const input = await request.json();
        const result = await quoteFlightOptions(input as FlightOptionsQuoteRequest, env);
        return json(result);
      } catch (error) {
        return json({ ok: false, error: error instanceof Error ? error.message : "Invalid flight options quote request" }, 400);
      }
    }

    return json({ ok: false, error: "Not found" }, 404);
  },
};
