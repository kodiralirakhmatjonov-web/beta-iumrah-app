PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS package_primary_hotels (
  id TEXT PRIMARY KEY,
  package_tier TEXT NOT NULL CHECK (package_tier IN ('economy','standard','comfort','luxury')),
  stars INTEGER NOT NULL CHECK (stars BETWEEN 1 AND 5),
  city TEXT NOT NULL CHECK (city IN ('Makkah','Madinah')),
  hotel_id TEXT NOT NULL,
  room_id TEXT,
  base_price_usd REAL NOT NULL CHECK (base_price_usd >= 0),
  price_unit TEXT NOT NULL DEFAULT 'perRoomNight' CHECK (price_unit IN ('perRoomStay','perRoomNight')),
  active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  UNIQUE(package_tier, stars, city),
  FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE RESTRICT,
  FOREIGN KEY (room_id) REFERENCES hotel_rooms(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_package_primary_hotels_lookup
ON package_primary_hotels(package_tier, stars, city, active);

CREATE INDEX IF NOT EXISTS idx_package_primary_hotels_hotel
ON package_primary_hotels(hotel_id);

-- Server-first package generator (beta production architecture).
-- This mirrors the curated recommendation table managed by iumrah Business.
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

CREATE TABLE IF NOT EXISTS package_quote_audits_v2 (
  quote_id TEXT PRIMARY KEY,
  pricing_version TEXT NOT NULL,
  authority TEXT NOT NULL CHECK (authority IN ('legacy_client','server_search')),
  search_id TEXT,
  package_key TEXT,
  expires_at TEXT,
  audit_json TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_package_quote_audits_v2_search ON package_quote_audits_v2(search_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_package_quote_audits_v2_expiry ON package_quote_audits_v2(expires_at);

CREATE TABLE IF NOT EXISTS package_flight_cache_v1 (
  cache_key TEXT PRIMARY KEY,
  provider_id TEXT NOT NULL,
  result_json TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_package_flight_cache_v1_expiry ON package_flight_cache_v1(expires_at);
