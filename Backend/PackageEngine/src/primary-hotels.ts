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

export async function resolvePrimaryHotel(
  db: D1Like,
  tier: PackageTier,
  stars: number,
  city: "Makkah" | "Madinah",
  requestedHotelId?: string | null,
): Promise<PrimaryHotelRecord> {
  const row = await db.prepare(
    `SELECT p.id, p.package_tier, p.stars, p.city, p.hotel_id, p.room_id,
            p.base_price_usd, p.price_unit, p.active, p.updated_at
     FROM package_primary_hotels p
     INNER JOIN hotels h ON h.id = p.hotel_id
     WHERE p.package_tier = ?1
       AND p.stars = ?2
       AND p.city = ?3
       AND p.active = 1
       AND h.status = 'published'
       AND h.city = p.city
       AND h.stars = p.stars
     LIMIT 1`,
  ).bind(tier, stars, city).first<PrimaryHotelRecord>();

  if (!row) throw new Error(`Primary ${city} hotel is not configured for ${tier}/${stars}★`);
  if (requestedHotelId && requestedHotelId !== row.hotel_id) {
    throw new Error(`Selected ${city} hotel is not the configured Primary Hotel`);
  }
  return row;
}
