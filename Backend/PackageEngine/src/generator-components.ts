import type { Env } from "./env";

type City = "Makkah" | "Madinah";

function json(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
  });
}

/**
 * Resolves the recommended Primary Hotel maintained by iumrah Business.
 *
 * This endpoint deliberately does not expose or calculate a package hotel rate.
 * The selected hotel's current stay price is verified separately by the client
 * hotel-price service for the actual dates, guests and room/category.
 */
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
        pricingMode: "liveVerificationRequired",
        position: Number(curated.position),
      });
    }

    // Keep generation usable when Business has not curated a slot yet, but this
    // is still only hotel selection. It never fabricates a price.
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
      pricingMode: "liveVerificationRequired",
      position: null,
    });
  } catch (error) {
    return json({ ok: false, error: error instanceof Error ? error.message : "PRIMARY_HOTEL_LOOKUP_FAILED" }, 500);
  }
}
