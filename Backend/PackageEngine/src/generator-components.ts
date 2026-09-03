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
 * Generator eligibility is coupled to the hotel catalog's server-maintained
 * 48-hour price cache. Beta never scrapes Booking/Expedia directly.
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
    const now = new Date().toISOString();
    const curated = await env.HOTELS_DB.prepare(
      `SELECT p.position, h.id AS hotel_id, h.stars, h.city
       FROM primary_hotels p
       INNER JOIN hotels h ON h.id = p.hotel_id
       INNER JOIN hotel_price_cache hp ON hp.hotel_id = h.id
       WHERE LOWER(p.city) = LOWER(?1)
         AND p.star_category = ?2
         AND h.status = 'published'
         AND h.stars = ?2
         AND hp.status = 'fresh'
         AND hp.nightly_price_usd IS NOT NULL
         AND hp.expires_at > ?3
       ORDER BY p.position ASC
       LIMIT 1`,
    ).bind(city, stars, now).first<{ position: number; hotel_id: string; stars: number | null; city: string }>();

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
        pricingMode: "catalog48h",
        position: Number(curated.position),
      });
    }

    // Keep generation usable when Business has not curated a slot yet, but this
    // is still only hotel selection. It never fabricates a price.
    const catalog = await env.HOTELS_DB.prepare(
      `SELECT h.id, h.stars, h.city
       FROM hotels h
       INNER JOIN hotel_price_cache hp ON hp.hotel_id = h.id
       WHERE h.status = 'published'
         AND LOWER(h.city) = LOWER(?1)
         AND h.stars = ?2
         AND hp.status = 'fresh'
         AND hp.nightly_price_usd IS NOT NULL
         AND hp.expires_at > ?3
       ORDER BY h.rating DESC, h.review_count DESC, h.updated_at DESC
       LIMIT 1`,
    ).bind(city, stars, now).first<{ id: string; stars: number | null; city: string }>();

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
      pricingMode: "catalog48h",
      position: null,
    });
  } catch (error) {
    return json({ ok: false, error: error instanceof Error ? error.message : "PRIMARY_HOTEL_LOOKUP_FAILED" }, 500);
  }
}
