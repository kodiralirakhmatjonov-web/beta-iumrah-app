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

test("verified email is a unique alternate key to the canonical pilgrim", () => {
  assert.match(migration, /CREATE TABLE IF NOT EXISTS iumrah_client_account_emails/);
  assert.match(migration, /pilgrim_id INTEGER PRIMARY KEY/);
  assert.match(migration, /email_normalized TEXT NOT NULL UNIQUE/);
  assert.match(source, /SELECT pilgrim_id FROM iumrah_client_account_emails WHERE email_normalized=\?1/);
  assert.match(source, /UPDATE pilgrims SET email=\?1,updated_at=\?2 WHERE id=\?3/);
});

test("email verification and recovery are bounded and do not store raw codes", () => {
  assert.match(source, /randomVerificationCode/);
  assert.match(source, /codeHash = await passwordDigest\(code, salt, CODE_ITERATIONS\)/);
  assert.match(source, /CODE_TTL_MINUTES = 10/);
  assert.match(source, /MAX_CODE_ATTEMPTS = 5/);
  assert.match(source, /https:\/\/api\.resend\.com\/emails/);
  assert.match(source, /SET revoked_at=\?1 WHERE pilgrim_id=\?2 AND revoked_at IS NULL/);
  assert.match(source, /UPDATE iumrah_client_devices SET is_primary=0 WHERE pilgrim_id=\?1/);
  assert.doesNotMatch(migration, /code TEXT NOT NULL/);
});

test("Apple can resolve or create one canonical account without duplicating identity", () => {
  assert.match(source, /APPLE_ACCOUNT_EMAIL_REQUIRED/);
  assert.match(source, /FROM iumrah_client_account_emails e/);
  assert.match(source, /INSERT INTO pilgrims\(email,created_at,updated_at\)/);
  assert.match(source, /INSERT INTO iumrah_client_apple_links\(apple_subject,pilgrim_id,linked_at,last_used_at\)/);
  assert.match(source, /UPDATE iumrah_client_devices SET is_primary=1/);
});
