import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

const source = fs.readFileSync(new URL("../src/client-account-security.ts", import.meta.url), "utf8");
const migration = fs.readFileSync(new URL("../migrations/0006_package_primary_hotels.sql", import.meta.url), "utf8");

test("Apple is a unique external key for the canonical pilgrim id", () => {
  assert.match(migration, /apple_subject TEXT PRIMARY KEY/);
  assert.match(migration, /pilgrim_id INTEGER NOT NULL UNIQUE/);
  assert.match(source, /iumrahID: String\(Number\(pilgrim\.id\)\)\.padStart\(6, "0"\)/);
  assert.doesNotMatch(migration, /CREATE TABLE[^;]*apple[^;]*password/si);
});

test("Apple identity tokens are verified server-side and cannot be replayed", () => {
  assert.match(source, /RSASSA-PKCS1-v1_5/);
  assert.match(source, /claims\.iss !== "https:\/\/appleid\.apple\.com"/);
  assert.match(source, /!audiences\.includes\(bundleID\)/);
  assert.match(source, /claims\.nonce !== await sha256Hex\(nonce\)/);
  assert.match(source, /APPLE_TOKEN_REPLAYED/);
});

test("secondary sessions can terminate only themselves", () => {
  assert.match(source, /if \(!self && !auth\.isPrimary\) throw new RouteError\("PRIMARY_DEVICE_REQUIRED", 403\)/);
  assert.match(source, /canTerminate: isCurrent \|\| auth\.isPrimary/);
  assert.match(source, /if \(!auth\.isPrimary\) throw new RouteError\("PRIMARY_DEVICE_REQUIRED", 403\)/);
});
