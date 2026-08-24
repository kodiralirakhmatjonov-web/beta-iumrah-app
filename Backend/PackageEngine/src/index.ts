import { calculatePackageQuote } from "./pricing";
import { quoteFlightOptions } from "./flight-options";
import { resolvePrimaryHotel, type D1Like } from "./primary-hotels";
import type { ConsumerPackageQuoteRequest, FlightOptionsQuoteRequest, PackageQuoteRequest, PublicPackageQuote } from "./types";

type Env = {
  PRICING_VERSION?: string;
  HOTELS_DB?: D1Like;
  CBU_FX_URL?: string;
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

  return calculatePackageQuote(coreInput, env.PRICING_VERSION ?? "iumrah-web-v1-beta-0.6");
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "GET" && (url.pathname === "/health" || url.pathname === "/api/package/health")) {
      return json({
        ok: true,
        service: "iumrah-package-engine",
        pricingVersion: env.PRICING_VERSION ?? "iumrah-web-v1-beta-0.6",
        hotelsDbConfigured: Boolean(env.HOTELS_DB),
      });
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
        // Public response intentionally omits base_price_usd and price_unit.
        return json({ ok: true, hotelId: row.hotel_id, roomId: row.room_id, tier: row.package_tier, stars: row.stars, city: row.city });
      } catch (error) {
        return json({ ok: false, error: error instanceof Error ? error.message : "Primary Hotel not configured" }, 404);
      }
    }

    if (request.method === "POST" && url.pathname === "/api/package/quote") {
      try {
        const input = (await request.json()) as ConsumerPackageQuoteRequest;
        const result = await resolveConsumerQuote(input, env);
        // Never expose internal component costs or margin to the consumer app.
        return json(publicOnly(result));
      } catch (error) {
        return json({ ok: false, error: error instanceof Error ? error.message : "Invalid quote request" }, 400);
      }
    }

    if (request.method === "POST" && url.pathname === "/api/package/flight-options/quote") {
      try {
        const input = await request.json();
        const result = await quoteFlightOptions(input as FlightOptionsQuoteRequest, env);
        // Raw flight fares, FX-normalized costs, hotel costs and margin never leave this worker.
        return json(result);
      } catch (error) {
        return json({ ok: false, error: error instanceof Error ? error.message : "Invalid flight options quote request" }, 400);
      }
    }

    return json({ ok: false, error: "Not found" }, 404);
  },
};
