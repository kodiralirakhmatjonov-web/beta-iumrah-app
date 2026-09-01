import type { D1Like } from "./d1";
import type { Env } from "./env";

type PilgrimRow = {
  id: number;
  first_name?: string | null;
  last_name?: string | null;
  display_name?: string | null;
  phone?: string | null;
  email?: string | null;
  telegram?: string | null;
  whatsapp?: string | null;
};

type AccountAuth = {
  pilgrimID: number;
  tokenHash: string;
  pilgrim: PilgrimRow;
};

type DeviceAuth = AccountAuth & {
  deviceID: string;
  installationID: string;
  sessionID: string;
  isPrimary: boolean;
};

type DeviceInput = {
  installationID: string;
  secret: string;
  name: string;
  model: string;
  platform: string;
  osVersion: string;
  appVersion: string;
  locale: string;
};

type AppleClaims = {
  iss?: string;
  aud?: string | string[];
  exp?: number;
  iat?: number;
  sub?: string;
  nonce?: string;
};

class RouteError extends Error {
  constructor(readonly code: string, readonly status = 400) {
    super(code);
  }
}

const PASSWORD_ITERATIONS = 100_000;
const SESSION_DAYS = 90;
let appleKeyCache: { expiresAt: number; keys: JsonWebKey[] } | null = null;

function json(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
    },
  });
}

function cleanText(value: unknown, maxLength: number) {
  return String(value ?? "").trim().slice(0, maxLength);
}

function validPassword(value: unknown): value is string {
  return typeof value === "string" && value.length >= 8 && value.length <= 128;
}

function constantTimeEqual(left: string, right: string) {
  const a = new TextEncoder().encode(left);
  const b = new TextEncoder().encode(right);
  if (!a.length || a.length !== b.length) return false;
  let difference = 0;
  for (let index = 0; index < a.length; index += 1) difference |= a[index] ^ b[index];
  return difference === 0;
}

function base64URL(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function decodeBase64URL(value: string) {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized + "=".repeat((4 - (normalized.length % 4)) % 4);
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
  return bytes;
}

function randomToken(byteCount = 32) {
  const bytes = new Uint8Array(byteCount);
  crypto.getRandomValues(bytes);
  return base64URL(bytes);
}

async function sha256Hex(value: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function passwordDigest(password: string, salt: string, iterations = PASSWORD_ITERATIONS) {
  if (!Number.isInteger(iterations) || iterations <= 0 || iterations > PASSWORD_ITERATIONS) {
    throw new RouteError("UNSUPPORTED_PASSWORD_ITERATIONS", 409);
  }
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(password),
    "PBKDF2",
    false,
    ["deriveBits"],
  );
  const bits = await crypto.subtle.deriveBits({
    name: "PBKDF2",
    hash: "SHA-256",
    salt: new TextEncoder().encode(salt),
    iterations,
  }, key, 256);
  return base64URL(new Uint8Array(bits));
}

function bearerToken(request: Request) {
  const authorization = request.headers.get("authorization") ?? "";
  if (!authorization.toLowerCase().startsWith("bearer ")) return "";
  return authorization.slice(7).trim();
}

function accountProfile(pilgrim: PilgrimRow) {
  const firstName = cleanText(pilgrim.first_name, 120);
  const lastName = cleanText(pilgrim.last_name, 120);
  const displayName = cleanText(pilgrim.display_name, 240) || [firstName, lastName].filter(Boolean).join(" ");
  return {
    iumrahID: String(Number(pilgrim.id)).padStart(6, "0"),
    displayName,
    firstName,
    lastName,
    phone: cleanText(pilgrim.phone, 100),
    email: cleanText(pilgrim.email, 254),
    telegram: cleanText(pilgrim.telegram, 120),
    whatsapp: cleanText(pilgrim.whatsapp, 120),
  };
}

async function requireAccount(request: Request, db: D1Like): Promise<AccountAuth> {
  const token = bearerToken(request);
  if (!token || token.length > 256) throw new RouteError("ACCOUNT_SESSION_REQUIRED", 401);
  const tokenHash = await sha256Hex(token);
  const now = new Date().toISOString();
  const row = await db.prepare(
    `SELECT s.pilgrim_id,
            p.id,p.first_name,p.last_name,p.display_name,p.phone,
            p.email,p.telegram,p.whatsapp
     FROM iumrah_account_sessions s
     INNER JOIN pilgrims p ON p.id=s.pilgrim_id
     WHERE s.token_hash=?1 AND s.revoked_at IS NULL AND s.expires_at>?2
     LIMIT 1`,
  ).bind(tokenHash, now).first<PilgrimRow & { pilgrim_id: number }>();
  if (!row) throw new RouteError("ACCOUNT_SESSION_INVALID", 401);
  await db.prepare("UPDATE iumrah_account_sessions SET last_used_at=?1 WHERE token_hash=?2")
    .bind(now, tokenHash).run();
  return { pilgrimID: Number(row.pilgrim_id), tokenHash, pilgrim: row };
}

function requestLocation(request: Request) {
  const cf = (request as Request & { cf?: Record<string, unknown> }).cf ?? {};
  return {
    city: cleanText(cf.city, 100),
    region: cleanText(cf.region, 120),
    country: cleanText(cf.country, 8),
  };
}

function parseDevice(value: unknown): DeviceInput {
  const raw = (value && typeof value === "object" ? value : {}) as Record<string, unknown>;
  const device: DeviceInput = {
    installationID: cleanText(raw.installationID, 80),
    secret: cleanText(raw.secret, 180),
    name: cleanText(raw.name, 120) || "iPhone",
    model: cleanText(raw.model, 100) || "iPhone",
    platform: cleanText(raw.platform, 40) || "iOS",
    osVersion: cleanText(raw.osVersion, 80),
    appVersion: cleanText(raw.appVersion, 80),
    locale: cleanText(raw.locale, 24),
  };
  if (!/^[A-Za-z0-9-]{20,80}$/.test(device.installationID)
      || !/^[A-Za-z0-9_-]{32,180}$/.test(device.secret)) {
    throw new RouteError("INVALID_DEVICE_CREDENTIALS", 400);
  }
  return device;
}

async function bindCurrentSession(
  db: D1Like,
  auth: AccountAuth,
  device: DeviceInput,
  request: Request,
) {
  const now = new Date().toISOString();
  const location = requestLocation(request);
  const secretHash = await sha256Hex(device.secret);
  let deviceRow = await db.prepare(
    `SELECT id,secret_hash FROM iumrah_client_devices
     WHERE pilgrim_id=?1 AND installation_id=?2 LIMIT 1`,
  ).bind(auth.pilgrimID, device.installationID).first<{ id: string; secret_hash: string }>();

  if (deviceRow && !constantTimeEqual(deviceRow.secret_hash, secretHash)) {
    throw new RouteError("DEVICE_ID_CONFLICT", 403);
  }
  if (!deviceRow) {
    const id = `device-${crypto.randomUUID()}`;
    await db.prepare(
      `INSERT INTO iumrah_client_devices(
         id,pilgrim_id,installation_id,secret_hash,name,model,platform,os_version,
         app_version,locale,created_at,first_seen_at,last_seen_at,last_city,last_region,last_country
       ) VALUES(?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?11,?11,?12,?13,?14)`,
    ).bind(
      id, auth.pilgrimID, device.installationID, secretHash, device.name, device.model,
      device.platform, device.osVersion, device.appVersion, device.locale, now,
      location.city, location.region, location.country,
    ).run();
    deviceRow = { id, secret_hash: secretHash };
  } else {
    await db.prepare(
      `UPDATE iumrah_client_devices
       SET name=?1,model=?2,platform=?3,os_version=?4,app_version=?5,locale=?6,
           last_seen_at=?7,last_city=?8,last_region=?9,last_country=?10,revoked_at=NULL
       WHERE id=?11`,
    ).bind(
      device.name, device.model, device.platform, device.osVersion, device.appVersion,
      device.locale, now, location.city, location.region, location.country, deviceRow.id,
    ).run();
  }

  const binding = await db.prepare(
    "SELECT session_id,device_id FROM iumrah_client_session_bindings WHERE token_hash=?1 LIMIT 1",
  ).bind(auth.tokenHash).first<{ session_id: string; device_id: string | null }>();
  if (binding?.device_id && binding.device_id !== deviceRow.id) {
    throw new RouteError("SESSION_ALREADY_BOUND", 409);
  }
  if (binding) {
    await db.prepare(
      `UPDATE iumrah_client_session_bindings
       SET device_id=?1,last_seen_at=?2,last_city=?3,last_region=?4,last_country=?5
       WHERE token_hash=?6`,
    ).bind(deviceRow.id, now, location.city, location.region, location.country, auth.tokenHash).run();
    return binding.session_id;
  }
  const sessionID = `session-${crypto.randomUUID()}`;
  await db.prepare(
    `INSERT INTO iumrah_client_session_bindings(
       session_id,token_hash,pilgrim_id,device_id,created_at,last_seen_at,last_city,last_region,last_country
     ) VALUES(?1,?2,?3,?4,?5,?5,?6,?7,?8)`,
  ).bind(
    sessionID, auth.tokenHash, auth.pilgrimID, deviceRow.id, now,
    location.city, location.region, location.country,
  ).run();
  return sessionID;
}

async function requireDevice(request: Request, db: D1Like): Promise<DeviceAuth> {
  const auth = await requireAccount(request, db);
  const installationID = cleanText(request.headers.get("x-iumrah-device-id"), 80);
  const secret = cleanText(request.headers.get("x-iumrah-device-secret"), 180);
  if (!installationID || !secret) throw new RouteError("DEVICE_REGISTRATION_REQUIRED", 428);
  const secretHash = await sha256Hex(secret);
  const row = await db.prepare(
    `SELECT b.session_id,d.id AS device_id,d.installation_id,d.secret_hash,d.is_primary
     FROM iumrah_client_session_bindings b
     INNER JOIN iumrah_client_devices d ON d.id=b.device_id
     WHERE b.token_hash=?1 AND b.pilgrim_id=?2 AND d.installation_id=?3
       AND d.revoked_at IS NULL
     LIMIT 1`,
  ).bind(auth.tokenHash, auth.pilgrimID, installationID).first<{
    session_id: string;
    device_id: string;
    installation_id: string;
    secret_hash: string;
    is_primary: number;
  }>();
  if (!row || !constantTimeEqual(row.secret_hash, secretHash)) {
    throw new RouteError("DEVICE_AUTHENTICATION_FAILED", 403);
  }
  const now = new Date().toISOString();
  const location = requestLocation(request);
  await db.prepare(
    `UPDATE iumrah_client_devices
     SET last_seen_at=?1,last_city=?2,last_region=?3,last_country=?4 WHERE id=?5`,
  ).bind(now, location.city, location.region, location.country, row.device_id).run();
  await db.prepare(
    `UPDATE iumrah_client_session_bindings
     SET last_seen_at=?1,last_city=?2,last_region=?3,last_country=?4 WHERE session_id=?5`,
  ).bind(now, location.city, location.region, location.country, row.session_id).run();
  return {
    ...auth,
    deviceID: row.device_id,
    installationID: row.installation_id,
    sessionID: row.session_id,
    isPrimary: Number(row.is_primary) === 1,
  };
}

async function ensureLegacySessionHandles(db: D1Like, pilgrimID: number) {
  const now = new Date().toISOString();
  const missing = await db.prepare(
    `SELECT s.token_hash,s.created_at,s.last_used_at
     FROM iumrah_account_sessions s
     LEFT JOIN iumrah_client_session_bindings b ON b.token_hash=s.token_hash
     WHERE s.pilgrim_id=?1 AND s.revoked_at IS NULL AND s.expires_at>?2
       AND b.token_hash IS NULL`,
  ).bind(pilgrimID, now).all<{ token_hash: string; created_at: string; last_used_at: string }>();
  for (const row of missing.results ?? []) {
    await db.prepare(
      `INSERT OR IGNORE INTO iumrah_client_session_bindings(
         session_id,token_hash,pilgrim_id,device_id,created_at,last_seen_at,last_city,last_region,last_country
       ) VALUES(?1,?2,?3,NULL,?4,?5,'','','')`,
    ).bind(
      `session-${crypto.randomUUID()}`, row.token_hash, pilgrimID,
      row.created_at, row.last_used_at || row.created_at,
    ).run();
  }
}

async function securityOverview(db: D1Like, auth: DeviceAuth) {
  await ensureLegacySessionHandles(db, auth.pilgrimID);
  const now = new Date().toISOString();
  const result = await db.prepare(
    `SELECT b.session_id,b.token_hash,s.created_at,s.expires_at,
            COALESCE(s.last_used_at,b.last_seen_at) AS last_active_at,
            b.last_city,b.last_region,b.last_country,
            d.name,d.model,d.platform,d.os_version,d.app_version,d.is_primary
     FROM iumrah_account_sessions s
     INNER JOIN iumrah_client_session_bindings b ON b.token_hash=s.token_hash
     LEFT JOIN iumrah_client_devices d ON d.id=b.device_id AND d.revoked_at IS NULL
     WHERE s.pilgrim_id=?1 AND s.revoked_at IS NULL AND s.expires_at>?2
     ORDER BY CASE WHEN b.token_hash=?3 THEN 0 ELSE 1 END,
              COALESCE(s.last_used_at,b.last_seen_at) DESC`,
  ).bind(auth.pilgrimID, now, auth.tokenHash).all<{
    session_id: string;
    token_hash: string;
    created_at: string;
    expires_at: string;
    last_active_at: string;
    last_city: string;
    last_region: string;
    last_country: string;
    name: string | null;
    model: string | null;
    platform: string | null;
    os_version: string | null;
    app_version: string | null;
    is_primary: number | null;
  }>();
  const sessions = (result.results ?? []).map((row) => {
    const isCurrent = row.token_hash === auth.tokenHash;
    return {
      id: row.session_id,
      deviceName: row.name || "Unknown device",
      model: row.model || "",
      platform: row.platform || "",
      osVersion: row.os_version || "",
      appVersion: row.app_version || "",
      city: row.last_city || "",
      region: row.last_region || "",
      country: row.last_country || "",
      createdAt: row.created_at,
      lastActiveAt: row.last_active_at,
      expiresAt: row.expires_at,
      isCurrent,
      isPrimary: Number(row.is_primary ?? 0) === 1,
      canTerminate: isCurrent || auth.isPrimary,
    };
  });
  const primary = await db.prepare(
    `SELECT id FROM iumrah_client_devices
     WHERE pilgrim_id=?1 AND is_primary=1 AND revoked_at IS NULL LIMIT 1`,
  ).bind(auth.pilgrimID).first<{ id: string }>();
  const apple = await db.prepare(
    "SELECT linked_at FROM iumrah_client_apple_links WHERE pilgrim_id=?1 LIMIT 1",
  ).bind(auth.pilgrimID).first<{ linked_at: string }>();
  return {
    ok: true,
    iumrahID: String(auth.pilgrimID).padStart(6, "0"),
    currentSessionID: auth.sessionID,
    currentDeviceIsPrimary: auth.isPrimary,
    primaryDeviceProtected: Boolean(primary),
    apple: { linked: Boolean(apple), linkedAt: apple?.linked_at ?? null },
    sessions,
  };
}

async function verifyAccountPassword(db: D1Like, pilgrimID: number, password: string) {
  const row = await db.prepare(
    `SELECT password_salt,password_hash,password_iterations,failed_attempts,locked_until
     FROM iumrah_accounts WHERE pilgrim_id=?1 LIMIT 1`,
  ).bind(pilgrimID).first<{
    password_salt: string;
    password_hash: string;
    password_iterations: number;
    failed_attempts: number;
    locked_until: string | null;
  }>();
  if (!row || !validPassword(password)) throw new RouteError("INVALID_CREDENTIALS", 401);
  if (row.locked_until && Date.parse(row.locked_until) > Date.now()) {
    throw new RouteError("ACCOUNT_TEMPORARILY_LOCKED", 423);
  }
  const expected = await passwordDigest(password, row.password_salt, Number(row.password_iterations));
  if (!constantTimeEqual(expected, row.password_hash)) {
    const attempts = Number(row.failed_attempts ?? 0) + 1;
    const lockedUntil = attempts >= 6 ? new Date(Date.now() + 15 * 60_000).toISOString() : null;
    await db.prepare(
      "UPDATE iumrah_accounts SET failed_attempts=?1,locked_until=?2 WHERE pilgrim_id=?3",
    ).bind(lockedUntil ? 0 : attempts, lockedUntil, pilgrimID).run();
    throw new RouteError(lockedUntil ? "ACCOUNT_TEMPORARILY_LOCKED" : "INVALID_CREDENTIALS", lockedUntil ? 423 : 401);
  }
  await db.prepare(
    "UPDATE iumrah_accounts SET failed_attempts=0,locked_until=NULL WHERE pilgrim_id=?1",
  ).bind(pilgrimID).run();
}

async function audit(
  db: D1Like,
  pilgrimID: number,
  eventType: string,
  actorSessionID: string | null,
  targetSessionID: string | null,
) {
  await db.prepare(
    `INSERT INTO iumrah_client_security_audit(
       id,pilgrim_id,event_type,actor_session_id,target_session_id,created_at
     ) VALUES(?1,?2,?3,?4,?5,?6)`,
  ).bind(
    `audit-${crypto.randomUUID()}`, pilgrimID, eventType, actorSessionID,
    targetSessionID, new Date().toISOString(),
  ).run();
}

async function createAccountSession(db: D1Like, pilgrimID: number) {
  const token = randomToken(32);
  const tokenHash = await sha256Hex(token);
  const now = new Date();
  const expiresAt = new Date(now.getTime() + SESSION_DAYS * 86_400_000).toISOString();
  await db.prepare(
    `INSERT INTO iumrah_account_sessions(token_hash,pilgrim_id,created_at,expires_at,last_used_at)
     VALUES(?1,?2,?3,?4,?3)`,
  ).bind(tokenHash, pilgrimID, now.toISOString(), expiresAt).run();
  return { token, tokenHash, expiresAt };
}

function parseJWT(identityToken: string) {
  const pieces = identityToken.split(".");
  if (pieces.length !== 3) throw new RouteError("APPLE_TOKEN_INVALID", 401);
  try {
    const header = JSON.parse(new TextDecoder().decode(decodeBase64URL(pieces[0]))) as { alg?: string; kid?: string };
    const claims = JSON.parse(new TextDecoder().decode(decodeBase64URL(pieces[1]))) as AppleClaims;
    return { pieces, header, claims };
  } catch {
    throw new RouteError("APPLE_TOKEN_INVALID", 401);
  }
}

async function appleKeys(forceRefresh = false) {
  if (!forceRefresh && appleKeyCache && appleKeyCache.expiresAt > Date.now()) return appleKeyCache.keys;
  const response = await fetch("https://appleid.apple.com/auth/keys", {
    headers: { accept: "application/json" },
  });
  if (!response.ok) throw new RouteError("APPLE_VERIFICATION_UNAVAILABLE", 503);
  const payload = await response.json() as { keys?: JsonWebKey[] };
  if (!Array.isArray(payload.keys) || !payload.keys.length) {
    throw new RouteError("APPLE_VERIFICATION_UNAVAILABLE", 503);
  }
  appleKeyCache = { keys: payload.keys, expiresAt: Date.now() + 6 * 60 * 60_000 };
  return payload.keys;
}

async function verifyAppleIdentity(identityToken: unknown, rawNonce: unknown, bundleID: string) {
  const token = cleanText(identityToken, 12_000);
  const nonce = cleanText(rawNonce, 256);
  if (!token || nonce.length < 32) throw new RouteError("APPLE_TOKEN_INVALID", 401);
  const { pieces, header, claims } = parseJWT(token);
  if (header.alg !== "RS256" || !header.kid) throw new RouteError("APPLE_TOKEN_INVALID", 401);
  let keys = await appleKeys();
  let keyData = keys.find((item) => (item as JsonWebKey & { kid?: string }).kid === header.kid);
  if (!keyData) {
    keys = await appleKeys(true);
    keyData = keys.find((item) => (item as JsonWebKey & { kid?: string }).kid === header.kid);
  }
  if (!keyData) throw new RouteError("APPLE_SIGNING_KEY_NOT_FOUND", 503);
  const key = await crypto.subtle.importKey(
    "jwk",
    keyData,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const verified = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    key,
    decodeBase64URL(pieces[2]),
    new TextEncoder().encode(`${pieces[0]}.${pieces[1]}`),
  );
  const now = Math.floor(Date.now() / 1000);
  const audiences = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
  if (!verified
      || claims.iss !== "https://appleid.apple.com"
      || !audiences.includes(bundleID)
      || typeof claims.exp !== "number" || claims.exp <= now
      || typeof claims.iat !== "number" || claims.iat > now + 120
      || !claims.sub || claims.sub.length > 255
      || claims.nonce !== await sha256Hex(nonce)) {
    throw new RouteError("APPLE_TOKEN_INVALID", 401);
  }
  return { token, subject: claims.sub };
}

async function consumeAppleAssertion(db: D1Like, identityToken: string) {
  const digest = await sha256Hex(identityToken);
  await db.prepare("DELETE FROM iumrah_client_apple_assertions WHERE used_at<?1")
    .bind(new Date(Date.now() - 30 * 86_400_000).toISOString()).run();
  const existing = await db.prepare(
    "SELECT token_hash FROM iumrah_client_apple_assertions WHERE token_hash=?1 LIMIT 1",
  ).bind(digest).first<{ token_hash: string }>();
  if (existing) throw new RouteError("APPLE_TOKEN_REPLAYED", 409);
  await db.prepare(
    "INSERT INTO iumrah_client_apple_assertions(token_hash,used_at) VALUES(?1,?2)",
  ).bind(digest, new Date().toISOString()).run();
}

async function register(request: Request, db: D1Like) {
  const auth = await requireAccount(request, db);
  const payload = await request.json().catch(() => null) as { device?: unknown } | null;
  const device = parseDevice(payload?.device);
  await bindCurrentSession(db, auth, device, request);
  const headers = new Headers(request.headers);
  headers.set("x-iumrah-device-id", device.installationID);
  headers.set("x-iumrah-device-secret", device.secret);
  const secured = await requireDevice(new Request(request.url, { method: "GET", headers }), db);
  return json(await securityOverview(db, secured));
}

async function claimPrimary(request: Request, db: D1Like) {
  const auth = await requireDevice(request, db);
  const payload = await request.json().catch(() => null) as { password?: unknown } | null;
  await verifyAccountPassword(db, auth.pilgrimID, String(payload?.password ?? ""));
  const existing = await db.prepare(
    `SELECT id FROM iumrah_client_devices
     WHERE pilgrim_id=?1 AND is_primary=1 AND revoked_at IS NULL LIMIT 1`,
  ).bind(auth.pilgrimID).first<{ id: string }>();
  if (existing && existing.id !== auth.deviceID) {
    throw new RouteError("PRIMARY_DEVICE_ALREADY_PROTECTED", 409);
  }
  await db.prepare(
    `UPDATE iumrah_client_devices
     SET is_primary=CASE WHEN id=?1 THEN 1 ELSE 0 END WHERE pilgrim_id=?2`,
  ).bind(auth.deviceID, auth.pilgrimID).run();
  await audit(db, auth.pilgrimID, "primary_device_claimed", auth.sessionID, auth.sessionID);
  return json(await securityOverview(db, { ...auth, isPrimary: true }));
}

async function terminateSession(request: Request, db: D1Like, sessionID: string) {
  const auth = await requireDevice(request, db);
  const target = await db.prepare(
    `SELECT b.token_hash,b.session_id
     FROM iumrah_client_session_bindings b
     INNER JOIN iumrah_account_sessions s ON s.token_hash=b.token_hash
     WHERE b.session_id=?1 AND b.pilgrim_id=?2
       AND s.revoked_at IS NULL AND s.expires_at>?3 LIMIT 1`,
  ).bind(sessionID, auth.pilgrimID, new Date().toISOString()).first<{
    token_hash: string;
    session_id: string;
  }>();
  if (!target) throw new RouteError("SESSION_NOT_FOUND", 404);
  const self = target.token_hash === auth.tokenHash;
  if (!self && !auth.isPrimary) throw new RouteError("PRIMARY_DEVICE_REQUIRED", 403);
  await db.prepare("UPDATE iumrah_account_sessions SET revoked_at=?1 WHERE token_hash=?2")
    .bind(new Date().toISOString(), target.token_hash).run();
  await audit(db, auth.pilgrimID, "session_terminated", auth.sessionID, target.session_id);
  return json({ ok: true, signedOut: self });
}

async function linkApple(request: Request, env: Env, db: D1Like) {
  const auth = await requireDevice(request, db);
  if (!auth.isPrimary) throw new RouteError("PRIMARY_DEVICE_REQUIRED", 403);
  const payload = await request.json().catch(() => null) as {
    identityToken?: unknown;
    nonce?: unknown;
  } | null;
  const apple = await verifyAppleIdentity(
    payload?.identityToken,
    payload?.nonce,
    env.APPLE_BUNDLE_ID ?? "com.iumrah.beta",
  );
  await consumeAppleAssertion(db, apple.token);
  const subjectOwner = await db.prepare(
    "SELECT pilgrim_id FROM iumrah_client_apple_links WHERE apple_subject=?1 LIMIT 1",
  ).bind(apple.subject).first<{ pilgrim_id: number }>();
  if (subjectOwner && Number(subjectOwner.pilgrim_id) !== auth.pilgrimID) {
    throw new RouteError("APPLE_ID_CONNECTED_TO_ANOTHER_ACCOUNT", 409);
  }
  const accountLink = await db.prepare(
    "SELECT apple_subject FROM iumrah_client_apple_links WHERE pilgrim_id=?1 LIMIT 1",
  ).bind(auth.pilgrimID).first<{ apple_subject: string }>();
  if (accountLink && accountLink.apple_subject !== apple.subject) {
    throw new RouteError("APPLE_ID_ALREADY_CONNECTED", 409);
  }
  const now = new Date().toISOString();
  await db.prepare(
    `INSERT INTO iumrah_client_apple_links(apple_subject,pilgrim_id,linked_at,last_used_at)
     VALUES(?1,?2,?3,?3)
     ON CONFLICT(apple_subject) DO UPDATE SET last_used_at=excluded.last_used_at`,
  ).bind(apple.subject, auth.pilgrimID, now).run();
  await audit(db, auth.pilgrimID, "apple_id_linked", auth.sessionID, auth.sessionID);
  return json({ ok: true, appleLinked: true, iumrahID: String(auth.pilgrimID).padStart(6, "0") });
}

async function signInWithApple(request: Request, env: Env, db: D1Like) {
  const payload = await request.json().catch(() => null) as {
    identityToken?: unknown;
    nonce?: unknown;
    device?: unknown;
  } | null;
  const apple = await verifyAppleIdentity(
    payload?.identityToken,
    payload?.nonce,
    env.APPLE_BUNDLE_ID ?? "com.iumrah.beta",
  );
  await consumeAppleAssertion(db, apple.token);
  const row = await db.prepare(
    `SELECT p.id,p.first_name,p.last_name,p.display_name,p.phone,p.email,p.telegram,p.whatsapp
     FROM iumrah_client_apple_links a
     INNER JOIN pilgrims p ON p.id=a.pilgrim_id
     INNER JOIN iumrah_accounts account ON account.pilgrim_id=p.id
     WHERE a.apple_subject=?1 LIMIT 1`,
  ).bind(apple.subject).first<PilgrimRow>();
  if (!row) throw new RouteError("APPLE_ACCOUNT_NOT_LINKED", 409);
  const device = parseDevice(payload?.device);
  const session = await createAccountSession(db, Number(row.id));
  const auth: AccountAuth = { pilgrimID: Number(row.id), tokenHash: session.tokenHash, pilgrim: row };
  let sessionID: string;
  try {
    sessionID = await bindCurrentSession(db, auth, device, request);
  } catch (error) {
    await db.prepare("UPDATE iumrah_account_sessions SET revoked_at=?1 WHERE token_hash=?2")
      .bind(new Date().toISOString(), session.tokenHash).run();
    throw error;
  }
  const now = new Date().toISOString();
  await db.prepare("UPDATE iumrah_client_apple_links SET last_used_at=?1 WHERE apple_subject=?2")
    .bind(now, apple.subject).run();
  await db.prepare("UPDATE iumrah_accounts SET last_login_at=?1 WHERE pilgrim_id=?2")
    .bind(now, Number(row.id)).run();
  await audit(db, Number(row.id), "apple_sign_in", sessionID, sessionID);
  return json({
    ok: true,
    account: accountProfile(row),
    session: { token: session.token, expiresAt: session.expiresAt },
  });
}

export async function handleClientAccountSecurity(request: Request, env: Env, url: URL) {
  if (!env.HOTELS_DB) return json({ ok: false, error: "HOTELS_DB_NOT_CONFIGURED" }, 503);
  const db = env.HOTELS_DB;
  try {
    if (request.method === "POST" && url.pathname === "/api/package/client/account/security/register") {
      return await register(request, db);
    }
    if (request.method === "GET" && url.pathname === "/api/package/client/account/security") {
      const auth = await requireDevice(request, db);
      return json(await securityOverview(db, auth));
    }
    if (request.method === "POST" && url.pathname === "/api/package/client/account/security/claim-primary") {
      return await claimPrimary(request, db);
    }
    const sessionMatch = url.pathname.match(/^\/api\/package\/client\/account\/security\/sessions\/([^/]+)$/);
    if (request.method === "DELETE" && sessionMatch) {
      return await terminateSession(request, db, decodeURIComponent(sessionMatch[1]));
    }
    if (request.method === "POST" && url.pathname === "/api/package/client/account/apple/link") {
      return await linkApple(request, env, db);
    }
    if (request.method === "POST" && url.pathname === "/api/package/client/account/apple/sign-in") {
      return await signInWithApple(request, env, db);
    }
    return json({ ok: false, error: "NOT_FOUND" }, 404);
  } catch (error) {
    if (error instanceof RouteError) return json({ ok: false, error: error.code }, error.status);
    console.error("CLIENT_ACCOUNT_SECURITY_FAILED", error);
    return json({ ok: false, error: "ACCOUNT_SECURITY_UNAVAILABLE" }, 500);
  }
}
