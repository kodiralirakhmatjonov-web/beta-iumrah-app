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
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(package_tier, stars, city)
);

CREATE INDEX IF NOT EXISTS idx_package_primary_hotels_lookup
ON package_primary_hotels(package_tier, stars, city, active);
