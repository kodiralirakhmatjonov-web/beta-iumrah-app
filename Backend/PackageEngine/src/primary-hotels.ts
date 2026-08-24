import type { PackageTier, PrimaryHotelRecord } from "./types";

export type D1ResultLike<T = Record<string, unknown>> = {
  results?: T[];
  success?: boolean;
  meta?: Record<string, unknown>;
};

export type D1PreparedStatementLike = {
  bind(...values: unknown[]): D1PreparedStatementLike;
  first<T>(): Promise<T | null>;
  all<T>(): Promise<D1ResultLike<T>>;
  run(): Promise<D1ResultLike>;
};

export type D1Like = {
  prepare(query: string): D1PreparedStatementLike;
};

export type PrimaryHotelMatchType =
  | "exact"
  | "sameTierNearestStars"
  | "sameStarsOtherTier"
  | "nearestConfigured";

export type ResolvedPrimaryHotel = PrimaryHotelRecord & {
  matchType: PrimaryHotelMatchType;
  requestedTier: PackageTier;
  requestedStars: number;
};

function tierRankSql(alias: string) {
  return `CASE ${alias}
    WHEN 'economy' THEN 1
    WHEN 'standard' THEN 2
    WHEN 'comfort' THEN 3
    WHEN 'luxury' THEN 4
    ELSE 99
  END`;
}

function requestedTierRank(tier: PackageTier) {
  switch (tier) {
    case "economy": return 1;
    case "standard": return 2;
    case "comfort": return 3;
    case "luxury": return 4;
  }
}

async function resolveRequestedConfiguredHotel(
  db: D1Like,
  tier: PackageTier,
  stars: number,
  city: "Makkah" | "Madinah",
  requestedHotelId: string,
): Promise<ResolvedPrimaryHotel | null> {
  const row = await db.prepare(
    `SELECT p.id, p.package_tier, p.stars, p.city, p.hotel_id, p.room_id,
            p.base_price_usd, p.price_unit, p.active, p.updated_at
     FROM package_primary_hotels p
     INNER JOIN hotels h ON h.id = p.hotel_id
     WHERE p.hotel_id = ?1
       AND p.city = ?2
       AND p.active = 1
       AND h.status = 'published'
       AND h.city = p.city
     ORDER BY
       CASE WHEN p.package_tier = ?3 AND p.stars = ?4 THEN 0 ELSE 1 END,
       CASE WHEN p.package_tier = ?3 THEN 0 ELSE 1 END,
       ABS(p.stars - ?4),
       ABS((${tierRankSql("p.package_tier")}) - ?5),
       p.updated_at DESC
     LIMIT 1`,
  ).bind(requestedHotelId, city, tier, stars, requestedTierRank(tier)).first<PrimaryHotelRecord>();

  if (!row) return null;
  return {
    ...row,
    matchType:
      row.package_tier === tier && Number(row.stars) === stars
        ? "exact"
        : row.package_tier === tier
          ? "sameTierNearestStars"
          : Number(row.stars) === stars
            ? "sameStarsOtherTier"
            : "nearestConfigured",
    requestedTier: tier,
    requestedStars: stars,
  };
}

export async function resolvePrimaryHotel(
  db: D1Like,
  tier: PackageTier,
  stars: number,
  city: "Makkah" | "Madinah",
  requestedHotelId?: string | null,
): Promise<ResolvedPrimaryHotel> {
  if (requestedHotelId) {
    const requested = await resolveRequestedConfiguredHotel(db, tier, stars, city, requestedHotelId);
    if (!requested) {
      throw new Error(`Selected ${city} hotel does not have an internal package rate yet`);
    }
    return requested;
  }

  // Beta fallback strategy: never invent a hotel price. We only reuse an already
  // configured Primary Hotel record (and therefore an already stored internal rate).
  // Priority:
  //   1) exact tier + stars
  //   2) same tier, nearest stars
  //   3) same stars, nearest package tier
  //   4) nearest configured option in the same city
  const row = await db.prepare(
    `SELECT p.id, p.package_tier, p.stars, p.city, p.hotel_id, p.room_id,
            p.base_price_usd, p.price_unit, p.active, p.updated_at,
            CASE
              WHEN p.package_tier = ?1 AND p.stars = ?2 THEN 'exact'
              WHEN p.package_tier = ?1 THEN 'sameTierNearestStars'
              WHEN p.stars = ?2 THEN 'sameStarsOtherTier'
              ELSE 'nearestConfigured'
            END AS match_type
     FROM package_primary_hotels p
     INNER JOIN hotels h ON h.id = p.hotel_id
     WHERE p.city = ?3
       AND p.active = 1
       AND h.status = 'published'
       AND h.city = p.city
     ORDER BY
       CASE
         WHEN p.package_tier = ?1 AND p.stars = ?2 THEN 0
         WHEN p.package_tier = ?1 THEN 1
         WHEN p.stars = ?2 THEN 2
         ELSE 3
       END,
       ABS(p.stars - ?2),
       ABS((${tierRankSql("p.package_tier")}) - ?4),
       p.updated_at DESC
     LIMIT 1`,
  ).bind(tier, stars, city, requestedTierRank(tier)).first<PrimaryHotelRecord & { match_type: PrimaryHotelMatchType }>();

  if (!row) {
    throw new Error(`No configured Primary Hotel is available for ${city} yet`);
  }

  return {
    id: row.id,
    package_tier: row.package_tier,
    stars: row.stars,
    city: row.city,
    hotel_id: row.hotel_id,
    room_id: row.room_id,
    base_price_usd: row.base_price_usd,
    price_unit: row.price_unit,
    active: row.active,
    updated_at: row.updated_at,
    matchType: row.match_type,
    requestedTier: tier,
    requestedStars: stars,
  };
}
