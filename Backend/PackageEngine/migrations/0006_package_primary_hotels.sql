PRAGMA foreign_keys = ON;

-- Cleanup compatibility migration.
-- The protected GitHub deploy workflow still runs this historical filename and
-- performs COUNT(*) against package_primary_hotels. Keep an EMPTY compatibility
-- shell until that protected workflow is changed manually; no runtime code reads it.
CREATE TABLE IF NOT EXISTS package_primary_hotels (
  id TEXT PRIMARY KEY,
  package_tier TEXT NOT NULL,
  stars INTEGER NOT NULL,
  city TEXT NOT NULL,
  hotel_id TEXT NOT NULL,
  room_id TEXT,
  base_price_usd REAL NOT NULL DEFAULT 0,
  price_unit TEXT NOT NULL DEFAULT 'perRoomNight',
  active INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
DELETE FROM package_primary_hotels;

-- Purge tables created only for the retired server flight/search/quote experiment.
DROP TABLE IF EXISTS package_flight_cache_v1;
DROP TABLE IF EXISTS package_quote_audits_v2;

-- `primary_hotels` is the real recommendation layer used by the generator.
CREATE TABLE IF NOT EXISTS primary_hotels (
  city TEXT NOT NULL,
  star_category INTEGER NOT NULL CHECK (star_category BETWEEN 1 AND 5),
  position INTEGER NOT NULL CHECK (position BETWEEN 1 AND 3),
  hotel_id TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  PRIMARY KEY (city, star_category, position),
  UNIQUE (city, star_category, hotel_id),
  FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_primary_hotels_lookup ON primary_hotels(city, star_category, position);
