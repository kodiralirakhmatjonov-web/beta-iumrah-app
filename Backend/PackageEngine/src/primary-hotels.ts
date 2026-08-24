import type { PackageTier, PrimaryHotelRecord } from "./types";

export type D1PreparedStatementLike = {
  bind(...values: unknown[]): D1PreparedStatementLike;
  first<T>(): Promise<T | null>;
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
    `SELECT id, package_tier, stars, city, hotel_id, room_id, base_price_usd, price_unit, active, updated_at
     FROM package_primary_hotels
     WHERE package_tier = ?1 AND stars = ?2 AND city = ?3 AND active = 1
     LIMIT 1`,
  ).bind(tier, stars, city).first<PrimaryHotelRecord>();

  if (!row) throw new Error(`Primary ${city} hotel is not configured for ${tier}/${stars}★`);
  if (requestedHotelId && requestedHotelId !== row.hotel_id) {
    throw new Error(`Selected ${city} hotel is not the configured Primary Hotel`);
  }
  return row;
}
