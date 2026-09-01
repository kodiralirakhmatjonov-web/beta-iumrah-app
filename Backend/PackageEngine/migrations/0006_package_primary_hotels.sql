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

-- Every login method resolves to the canonical integer pilgrims.id. The public
-- six-digit iumrah ID is only its zero-padded presentation (for example 16 -> 000016).
CREATE TABLE IF NOT EXISTS iumrah_client_devices (
  id TEXT PRIMARY KEY,
  pilgrim_id INTEGER NOT NULL,
  installation_id TEXT NOT NULL,
  secret_hash TEXT NOT NULL,
  name TEXT NOT NULL DEFAULT 'iPhone',
  model TEXT NOT NULL DEFAULT 'iPhone',
  platform TEXT NOT NULL DEFAULT 'iOS',
  os_version TEXT NOT NULL DEFAULT '',
  app_version TEXT NOT NULL DEFAULT '',
  locale TEXT NOT NULL DEFAULT '',
  is_primary INTEGER NOT NULL DEFAULT 0 CHECK (is_primary IN (0,1)),
  created_at TEXT NOT NULL,
  first_seen_at TEXT NOT NULL,
  last_seen_at TEXT NOT NULL,
  last_city TEXT NOT NULL DEFAULT '',
  last_region TEXT NOT NULL DEFAULT '',
  last_country TEXT NOT NULL DEFAULT '',
  revoked_at TEXT,
  UNIQUE (pilgrim_id, installation_id),
  FOREIGN KEY (pilgrim_id) REFERENCES pilgrims(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_iumrah_client_devices_account
ON iumrah_client_devices(pilgrim_id, last_seen_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_iumrah_client_devices_primary
ON iumrah_client_devices(pilgrim_id)
WHERE is_primary=1 AND revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS iumrah_client_session_bindings (
  session_id TEXT PRIMARY KEY,
  token_hash TEXT NOT NULL UNIQUE,
  pilgrim_id INTEGER NOT NULL,
  device_id TEXT,
  created_at TEXT NOT NULL,
  last_seen_at TEXT NOT NULL,
  last_city TEXT NOT NULL DEFAULT '',
  last_region TEXT NOT NULL DEFAULT '',
  last_country TEXT NOT NULL DEFAULT '',
  FOREIGN KEY (token_hash) REFERENCES iumrah_account_sessions(token_hash) ON DELETE CASCADE,
  FOREIGN KEY (pilgrim_id) REFERENCES pilgrims(id) ON DELETE CASCADE,
  FOREIGN KEY (device_id) REFERENCES iumrah_client_devices(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_iumrah_client_sessions_account
ON iumrah_client_session_bindings(pilgrim_id, last_seen_at DESC);

-- Apple `sub` is a unique external credential. It never replaces or duplicates
-- pilgrims.id; it only points to the same canonical iumrah account.
CREATE TABLE IF NOT EXISTS iumrah_client_apple_links (
  apple_subject TEXT PRIMARY KEY,
  pilgrim_id INTEGER NOT NULL UNIQUE,
  linked_at TEXT NOT NULL,
  last_used_at TEXT NOT NULL,
  FOREIGN KEY (pilgrim_id) REFERENCES pilgrims(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS iumrah_client_apple_assertions (
  token_hash TEXT PRIMARY KEY,
  used_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_iumrah_client_apple_assertions_used
ON iumrah_client_apple_assertions(used_at);

CREATE TABLE IF NOT EXISTS iumrah_client_security_audit (
  id TEXT PRIMARY KEY,
  pilgrim_id INTEGER NOT NULL,
  event_type TEXT NOT NULL,
  actor_session_id TEXT,
  target_session_id TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (pilgrim_id) REFERENCES pilgrims(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_iumrah_client_security_audit_account
ON iumrah_client_security_audit(pilgrim_id, created_at DESC);
