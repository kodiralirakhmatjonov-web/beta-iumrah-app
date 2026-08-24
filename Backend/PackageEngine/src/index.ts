import { calculatePackageQuote } from "./pricing";
import { quoteFlightOptions } from "./flight-options";
import { resolvePrimaryHotel, type D1Like } from "./primary-hotels";
import { deletePrimaryHotel, listPrimaryHotels, requirePackageAdmin, upsertPrimaryHotel } from "./admin";
import type { ConsumerPackageQuoteRequest, FlightOptionsQuoteRequest, PackageQuoteRequest, PublicPackageQuote } from "./types";

type Env = {
  PRICING_VERSION?: string;
  HOTELS_DB?: D1Like;
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

  const makkah = await resolvePrimaryHotel(
    env.HOTELS_DB,
    input.tier,
    input.hotelStars,
    "Makkah",
    input.primaryHotelIds?.makkah,
  );

  const madinah = input.includeMadinah
    ? await resolvePrimaryHotel(
        env.HOTELS_DB,
        input.tier,
        input.hotelStars,
        "Madinah",
        input.primaryHotelIds?.madinah,
      )
    : null;

  const coreInput: PackageQuoteRequest = {
    tier: input.tier,
    includeMadinah: input.includeMadinah,
    totalDays: input.totalDays,
    travelers: input.travelers,
    flights: input.flights,
    hotels: {
      makkah: {
        amountUsd: Number(makkah.base_price_usd),
        unit: makkah.price_unit,
        nights: Math.max(1, input.nights.makkah),
      },
      madinah: madinah
        ? {
            amountUsd: Number(madinah.base_price_usd),
            unit: madinah.price_unit,
            nights: Math.max(1, input.nights.madinah),
          }
        : null,
    },
    customization: input.customization,
  };

  return calculatePackageQuote(coreInput, env.PRICING_VERSION ?? "iumrah-web-v1-beta-0.9");
}

async function publicHealth(env: Env) {
  if (!env.HOTELS_DB) {
    return json({
      ok: true,
      service: "iumrah-package-engine",
      pricingVersion: env.PRICING_VERSION ?? "iumrah-web-v1-beta-0.9",
      hotelsDbConfigured: false,
      primaryHotelConfigCount: 0,
      pricingReady: false,
      flightOptionQuotingReady: false,
    });
  }

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
    const makkahCount = Number(rows.find((row) => row.city === "Makkah")?.count ?? 0);
    const madinahCount = Number(rows.find((row) => row.city === "Madinah")?.count ?? 0);
    const count = makkahCount + madinahCount;
    return json({
      ok: true,
      service: "iumrah-package-engine",
      pricingVersion: env.PRICING_VERSION ?? "iumrah-web-v1-beta-0.9",
      hotelsDbConfigured: true,
      primaryHotelConfigCount: count,
      primaryHotelConfigByCity: { Makkah: makkahCount, Madinah: madinahCount },
      pricingReady: makkahCount > 0,
      makkahPricingReady: makkahCount > 0,
      madinahPricingReady: madinahCount > 0,
      fallbackResolutionEnabled: true,
      flightOptionQuotingReady: makkahCount > 0,
    });
  } catch (error) {
    return json({
      ok: false,
      service: "iumrah-package-engine",
      pricingVersion: env.PRICING_VERSION ?? "iumrah-web-v1-beta-0.9",
      hotelsDbConfigured: true,
      primaryHotelConfigCount: 0,
      pricingReady: false,
      flightOptionQuotingReady: false,
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

      return json({ ok: false, error: "NOT_FOUND" }, 404);
    }

    if (request.method === "GET" && (url.pathname === "/health" || url.pathname === "/api/package/health")) {
      return publicHealth(env);
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
        });
      } catch (error) {
        return json({ ok: false, error: error instanceof Error ? error.message : "Primary Hotel not configured" }, 404);
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
