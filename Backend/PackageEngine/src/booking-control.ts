import type { D1Like, D1PreparedStatementLike } from "./d1";
import { ensureBookingRoomColumns, findHotelRoomCategory, parseRoomCategory } from "./room-categories";

type BookingD1 = D1Like & {
  batch(statements: D1PreparedStatementLike[]): Promise<unknown[]>;
};

type BookingControlEnv = {
  HOTELS_DB?: D1Like;
  BOOKINGS_DB?: BookingD1;
};

type BookingRow = {
  id: string;
  payload_json: string;
};

function json(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

function validBookingId(id: string) {
  return /^IUM-\d{4}-[A-Z2-9]{7}$/.test(id);
}

function bytesToHex(bytes: Uint8Array) {
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function hashBookingToken(token: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token));
  return bytesToHex(new Uint8Array(digest));
}

function bookingToken(request: Request) {
  return request.headers.get("x-booking-token")?.trim() ?? "";
}

async function authorizedBooking(request: Request, id: string, db: BookingD1): Promise<BookingRow | null> {
  if (!validBookingId(id)) return null;

  const token = bookingToken(request);
  if (token.length >= 24 && token.length <= 128) {
    const hash = await hashBookingToken(token);
    const booking = await db.prepare(
      "SELECT id, payload_json FROM bookings WHERE id = ?1 AND access_token_hash = ?2 LIMIT 1",
    ).bind(id, hash).first<BookingRow>();
    if (booking) return booking;
  }

  // After iumrah ID activation, the permanent account session becomes the canonical
  // authorization for every trip. Validate ownership against HotelsWorker and only
  // then read the booking row; the PackageEngine never sees account password data.
  const authorization = request.headers.get("authorization")?.trim() ?? "";
  if (!authorization.toLowerCase().startsWith("bearer ")) return null;
  try {
    const ownershipURL = new URL(`/api/catalog/hotels/client/trips/${encodeURIComponent(id)}`, request.url);
    const response = await fetch(ownershipURL, {
      method: "GET",
      headers: { Authorization: authorization, Accept: "application/json" },
      redirect: "manual",
    });
    if (!response.ok) return null;
    return db.prepare("SELECT id, payload_json FROM bookings WHERE id = ?1 LIMIT 1").bind(id).first<BookingRow>();
  } catch {
    return null;
  }
}

async function bookingChildTables(db: BookingD1) {
  const result = await db.prepare(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
  ).all<{ name: string }>();

  const tables: string[] = [];
  for (const row of result.results ?? []) {
    const table = row.name;
    // Table names come from sqlite_master, but still restrict them before interpolation.
    if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(table) || table === "bookings") continue;
    const columns = await db.prepare(`PRAGMA table_info("${table}")`).all<{ name: string }>();
    if ((columns.results ?? []).some((column) => column.name === "booking_id")) {
      tables.push(table);
    }
  }
  return tables;
}

async function hardDeleteBookingRows(id: string, db: BookingD1): Promise<boolean> {
  const existing = await db.prepare("SELECT id FROM bookings WHERE id = ?1 LIMIT 1").bind(id).first<{ id: string }>();
  if (!existing) return false;

  const childTables = await bookingChildTables(db);
  const statements: D1PreparedStatementLike[] = childTables.map((table) =>
    db.prepare(`DELETE FROM "${table}" WHERE booking_id = ?1`).bind(id),
  );
  statements.push(db.prepare("DELETE FROM bookings WHERE id = ?1").bind(id));
  await db.batch(statements);
  return true;
}

export async function deletePilgrimBooking(request: Request, id: string, env: BookingControlEnv): Promise<Response> {
  if (!env.BOOKINGS_DB) return json({ error: "BOOKING_DB_NOT_CONFIGURED" }, 503);

  try {
    const row = await authorizedBooking(request, id, env.BOOKINGS_DB);
    if (!row) return json({ error: "BOOKING_NOT_FOUND" }, 404);
    await hardDeleteBookingRows(id, env.BOOKINGS_DB);
    return json({ ok: true, deleted: true });
  } catch (error) {
    console.error("booking-control-delete-failed", error);
    return json({ error: "BOOKING_DELETE_FAILED" }, 500);
  }
}

export async function deleteAdminBooking(id: string, env: BookingControlEnv): Promise<Response> {
  if (!env.BOOKINGS_DB) return json({ error: "BOOKING_DB_NOT_CONFIGURED" }, 503);
  if (!validBookingId(id)) return json({ error: "INVALID_BOOKING_ID" }, 400);

  try {
    const deleted = await hardDeleteBookingRows(id, env.BOOKINGS_DB);
    if (!deleted) return json({ error: "BOOKING_NOT_FOUND" }, 404);
    return json({ ok: true, deleted: true });
  } catch (error) {
    console.error("booking-control-admin-delete-failed", error);
    return json({ error: "BOOKING_DELETE_FAILED" }, 500);
  }
}

function clean(value: unknown, max = 240) {
  return typeof value === "string" ? value.trim().slice(0, max) : "";
}

function bool(value: unknown, fallback: boolean) {
  return typeof value === "boolean" ? value : fallback;
}

async function persistBookingPayload(db: BookingD1, id: string, payload: Record<string, unknown>, now: string) {
  await db.prepare(
    `UPDATE bookings SET payload_json = ?1, updated_at = ?2 WHERE id = ?3`,
  ).bind(JSON.stringify(payload), now, id).run();
}


function normalizeIdentityName(value: unknown) {
  return clean(value, 80).normalize("NFKC").replace(/\s+/g, " ");
}

function normalizePassportNumber(value: unknown) {
  return clean(value, 40).normalize("NFKC").toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 20);
}

function validIdentityName(value: string) {
  return value.length >= 2 && value.length <= 80 && /^[\p{L}][\p{L}\s'’\-]{1,79}$/u.test(value);
}

async function identityFingerprint(firstName: string, lastName: string, passportNumber: string) {
  const canonical = [firstName, lastName, passportNumber]
    .map((value) => value.normalize("NFKC").toUpperCase())
    .join("|");
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(canonical));
  return bytesToHex(new Uint8Array(digest));
}

async function operationalBookingStatus(request: Request, id: string) {
  const url = new URL(`/api/catalog/hotels/client/trips/${encodeURIComponent(id)}`, request.url);
  const headers = new Headers({ Accept: "application/json" });
  const bookingAccess = request.headers.get("x-booking-token")?.trim();
  const authorization = request.headers.get("authorization")?.trim();
  if (bookingAccess) headers.set("x-booking-token", bookingAccess);
  if (authorization) headers.set("authorization", authorization);
  try {
    const response = await fetch(url, { method: "GET", headers, redirect: "manual" });
    if (!response.ok) return "";
    const payload = await response.json().catch(() => null) as {
      trip?: { status?: unknown };
      status?: unknown;
    } | null;
    return clean(payload?.trip?.status ?? payload?.status, 80)
      .replace(/-/g, "_")
      .toUpperCase();
  } catch {
    return "";
  }
}

function identityConfirmationJSON(row: {
  booking_id: string;
  first_name: string;
  last_name: string;
  passport_last4: string;
  status: string;
  verification_method: string;
  created_at: string;
  updated_at: string;
}, reusedIdentity: boolean) {
  return {
    bookingID: row.booking_id,
    status: row.status,
    firstName: row.first_name,
    lastName: row.last_name,
    passportLast4: row.passport_last4,
    verificationMethod: row.verification_method,
    reusedIdentity,
    submittedAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export async function getPilgrimIdentityConfirmation(request: Request, id: string, env: BookingControlEnv): Promise<Response> {
  if (!env.BOOKINGS_DB) return json({ ok: false, error: "BOOKING_DB_NOT_CONFIGURED" }, 503);
  if (!env.HOTELS_DB) return json({ ok: false, error: "HOTELS_DB_NOT_CONFIGURED" }, 503);

  try {
    const booking = await authorizedBooking(request, id, env.BOOKINGS_DB);
    if (!booking) return json({ ok: false, error: "BOOKING_NOT_FOUND" }, 404);

    const row = await env.HOTELS_DB.prepare(
      `SELECT booking_id,identity_fingerprint,first_name,last_name,passport_last4,status,
              verification_method,created_at,updated_at
       FROM iumrah_identity_confirmations WHERE booking_id=?1 LIMIT 1`,
    ).bind(id).first<{
      booking_id: string;
      identity_fingerprint: string;
      first_name: string;
      last_name: string;
      passport_last4: string;
      status: string;
      verification_method: string;
      created_at: string;
      updated_at: string;
    }>();
    if (!row) return json({ ok: false, error: "IDENTITY_CONFIRMATION_NOT_FOUND" }, 404);

    const duplicate = await env.HOTELS_DB.prepare(
      `SELECT booking_id FROM iumrah_identity_confirmations
       WHERE identity_fingerprint=?1 AND booking_id<>?2 AND status<>'rejected' LIMIT 1`,
    ).bind(row.identity_fingerprint, id).first<{ booking_id: string }>();

    return json({ ok: true, confirmation: identityConfirmationJSON(row, Boolean(duplicate)) });
  } catch (error) {
    console.error("booking-control-identity-read-failed", error);
    return json({ ok: false, error: "IDENTITY_CONFIRMATION_UNAVAILABLE" }, 500);
  }
}

export async function submitPilgrimIdentityConfirmation(request: Request, id: string, env: BookingControlEnv): Promise<Response> {
  if (!env.BOOKINGS_DB) return json({ ok: false, error: "BOOKING_DB_NOT_CONFIGURED" }, 503);
  if (!env.HOTELS_DB) return json({ ok: false, error: "HOTELS_DB_NOT_CONFIGURED" }, 503);

  let body: Record<string, unknown>;
  try {
    const value = await request.json();
    if (!value || typeof value !== "object") throw new Error("INVALID_REQUEST");
    body = value as Record<string, unknown>;
  } catch {
    return json({ ok: false, error: "INVALID_REQUEST" }, 400);
  }

  const firstName = normalizeIdentityName(body.firstName);
  const lastName = normalizeIdentityName(body.lastName);
  const passportNumber = normalizePassportNumber(body.passportNumber);
  const holderConfirmed = body.holderConfirmed === true;
  if (!validIdentityName(firstName) || !validIdentityName(lastName)
      || passportNumber.length < 5 || passportNumber.length > 20 || !holderConfirmed) {
    return json({ ok: false, error: "INVALID_IDENTITY_DETAILS" }, 400);
  }

  try {
    const booking = await authorizedBooking(request, id, env.BOOKINGS_DB);
    if (!booking) return json({ ok: false, error: "BOOKING_NOT_FOUND" }, 404);

    const status = await operationalBookingStatus(request, id);
    const allowedStatuses = new Set([
      "PAYMENT_PENDING", "PENDING_PAYMENT", "WAITING_PAYMENT", "AWAITING_PAYMENT",
      "PAYMENT_AND_DATA_PENDING", "AWAITING_PAYMENT_AND_DATA",
    ]);
    if (!allowedStatuses.has(status)) {
      return json({ ok: false, error: "IDENTITY_CONFIRMATION_NOT_AVAILABLE" }, 409);
    }

    const fingerprint = await identityFingerprint(firstName, lastName, passportNumber);
    const duplicate = await env.HOTELS_DB.prepare(
      `SELECT booking_id FROM iumrah_identity_confirmations
       WHERE identity_fingerprint=?1 AND booking_id<>?2 AND status<>'rejected' LIMIT 1`,
    ).bind(fingerprint, id).first<{ booking_id: string }>();

    const existing = await env.HOTELS_DB.prepare(
      "SELECT id,created_at FROM iumrah_identity_confirmations WHERE booking_id=?1 LIMIT 1",
    ).bind(id).first<{ id: string; created_at: string }>();
    const now = new Date().toISOString();
    const confirmationID = existing?.id ?? `identity-${crypto.randomUUID()}`;
    const createdAt = existing?.created_at ?? now;

    await env.HOTELS_DB.prepare(
      `INSERT INTO iumrah_identity_confirmations(
         id,booking_id,identity_fingerprint,first_name,last_name,passport_last4,status,
         verification_method,created_at,updated_at
       ) VALUES(?1,?2,?3,?4,?5,?6,'submitted','passport_self_confirmation',?7,?8)
       ON CONFLICT(booking_id) DO UPDATE SET
         identity_fingerprint=excluded.identity_fingerprint,
         first_name=excluded.first_name,
         last_name=excluded.last_name,
         passport_last4=excluded.passport_last4,
         status='submitted',
         verification_method='passport_self_confirmation',
         updated_at=excluded.updated_at`,
    ).bind(
      confirmationID, id, fingerprint, firstName, lastName, passportNumber.slice(-4), createdAt, now,
    ).run();

    return json({
      ok: true,
      confirmation: {
        bookingID: id,
        status: "submitted",
        firstName,
        lastName,
        passportLast4: passportNumber.slice(-4),
        verificationMethod: "passport_self_confirmation",
        reusedIdentity: Boolean(duplicate),
        submittedAt: createdAt,
        updatedAt: now,
      },
    });
  } catch (error) {
    console.error("booking-control-identity-submit-failed", error);
    return json({ ok: false, error: "IDENTITY_CONFIRMATION_UNAVAILABLE" }, 500);
  }
}


async function accountPilgrimID(request: Request, db: D1Like) {
  const authorization = request.headers.get("authorization")?.trim() ?? "";
  if (!authorization.toLowerCase().startsWith("bearer ")) return null;
  const token = authorization.slice(7).trim();
  if (!token || token.length > 256) return null;
  const tokenHash = await hashBookingToken(token);
  const row = await db.prepare(
    `SELECT pilgrim_id FROM iumrah_account_sessions
     WHERE token_hash=?1 AND revoked_at IS NULL AND expires_at>?2 LIMIT 1`,
  ).bind(tokenHash, new Date().toISOString()).first<{ pilgrim_id: number }>();
  return row ? Number(row.pilgrim_id) : null;
}

function bookingTotalUsd(payloadJSON: string) {
  try {
    const payload = JSON.parse(payloadJSON || "{}") as Record<string, unknown>;
    const direct = Number(payload.totalUsd ?? 0);
    if (Number.isFinite(direct) && direct > 0) return direct;
    const nested = payload.booking && typeof payload.booking === "object"
      ? Number((payload.booking as Record<string, unknown>).totalUsd ?? 0)
      : 0;
    return Number.isFinite(nested) && nested > 0 ? nested : 0;
  } catch {
    return 0;
  }
}

function friendsMaximumDiscount(totalUsd: number) {
  return totalUsd > 2000 ? 200 : 100;
}

async function friendsCreditBalance(db: D1Like, pilgrimID: number) {
  const row = await db.prepare(
    `SELECT COALESCE(SUM(amount_usd),0) AS balance
     FROM iumrah_friends_credit_ledger WHERE pilgrim_id=?1`,
  ).bind(pilgrimID).first<{ balance: number | string }>();
  return Math.max(0, Number(row?.balance ?? 0));
}

async function bookingIdentity(db: D1Like, bookingID: string) {
  return db.prepare(
    `SELECT identity_fingerprint,status FROM iumrah_identity_confirmations
     WHERE booking_id=?1 LIMIT 1`,
  ).bind(bookingID).first<{ identity_fingerprint: string; status: string }>();
}

async function friendsBookingSummary(
  request: Request,
  id: string,
  env: BookingControlEnv,
  booking?: BookingRow,
) {
  if (!env.BOOKINGS_DB || !env.HOTELS_DB) throw new Error("FRIENDS_DB_NOT_CONFIGURED");
  const authorized = booking ?? await authorizedBooking(request, id, env.BOOKINGS_DB);
  if (!authorized) return null;

  const totalUsd = bookingTotalUsd(authorized.payload_json);
  const maxDiscountUsd = friendsMaximumDiscount(totalUsd);
  const identity = await bookingIdentity(env.HOTELS_DB, id);
  const currentPilgrimID = await accountPilgrimID(request, env.HOTELS_DB);

  const redemptions = await env.HOTELS_DB.prepare(
    `SELECT gift_token,discount_usd,reward_status
     FROM iumrah_friends_redemptions
     WHERE booking_id=?1 AND status<>'cancelled' ORDER BY created_at ASC`,
  ).bind(id).all<{ gift_token: string; discount_usd: number; reward_status: string }>();
  const applied = redemptions.results ?? [];
  const giftDiscountUsd = applied.reduce((sum, row) => sum + Number(row.discount_usd || 0), 0);

  let creditAppliedUsd = 0;
  let availableCreditUsd = 0;
  if (currentPilgrimID) {
    const spend = await env.HOTELS_DB.prepare(
      `SELECT COALESCE(SUM(CASE WHEN amount_usd<0 THEN -amount_usd ELSE 0 END),0) AS amount
       FROM iumrah_friends_credit_ledger
       WHERE pilgrim_id=?1 AND source_type='friends_credit_spend' AND booking_id=?2`,
    ).bind(currentPilgrimID, id).first<{ amount: number | string }>();
    creditAppliedUsd = Number(spend?.amount ?? 0);
    availableCreditUsd = await friendsCreditBalance(env.HOTELS_DB, currentPilgrimID);
  }

  const totalDiscountUsd = Math.min(maxDiscountUsd, giftDiscountUsd + creditAppliedUsd);
  return {
    ok: true,
    bookingID: id,
    identityConfirmed: Boolean(identity && ["submitted", "manual_review", "confirmed"].includes(identity.status)),
    totalUsd,
    maxDiscountUsd,
    giftDiscountUsd,
    creditAppliedUsd,
    totalDiscountUsd,
    remainingAllowanceUsd: Math.max(0, maxDiscountUsd - totalDiscountUsd),
    payableUsd: Math.max(0, totalUsd - totalDiscountUsd),
    availableCreditUsd,
    appliedGifts: applied.map((row) => ({
      code: row.gift_token,
      discountUsd: Number(row.discount_usd || 100),
      rewardStatus: row.reward_status,
    })),
  };
}

async function persistFriendsSnapshot(db: BookingD1, booking: BookingRow, id: string, summary: Record<string, unknown>) {
  const payload = JSON.parse(booking.payload_json || "{}") as Record<string, unknown>;
  payload.iumrahFriends = {
    totalDiscountUsd: summary.totalDiscountUsd,
    giftDiscountUsd: summary.giftDiscountUsd,
    creditAppliedUsd: summary.creditAppliedUsd,
    payableUsd: summary.payableUsd,
    updatedAt: new Date().toISOString(),
  };
  await persistBookingPayload(db, id, payload, new Date().toISOString());
  booking.payload_json = JSON.stringify(payload);
}

export async function getPilgrimFriendsSummary(request: Request, id: string, env: BookingControlEnv): Promise<Response> {
  if (!env.BOOKINGS_DB) return json({ ok: false, error: "BOOKING_DB_NOT_CONFIGURED" }, 503);
  if (!env.HOTELS_DB) return json({ ok: false, error: "HOTELS_DB_NOT_CONFIGURED" }, 503);
  try {
    const booking = await authorizedBooking(request, id, env.BOOKINGS_DB);
    if (!booking) return json({ ok: false, error: "BOOKING_NOT_FOUND" }, 404);
    const summary = await friendsBookingSummary(request, id, env, booking);
    return json(summary);
  } catch (error) {
    console.error("booking-control-friends-summary-failed", error);
    return json({ ok: false, error: "FRIENDS_UNAVAILABLE" }, 500);
  }
}

export async function redeemPilgrimFriendGift(request: Request, id: string, env: BookingControlEnv): Promise<Response> {
  if (!env.BOOKINGS_DB) return json({ ok: false, error: "BOOKING_DB_NOT_CONFIGURED" }, 503);
  if (!env.HOTELS_DB) return json({ ok: false, error: "HOTELS_DB_NOT_CONFIGURED" }, 503);

  const payload = await request.json().catch(() => null) as { code?: unknown } | null;
  const code = clean(payload?.code, 40).normalize("NFKC").toUpperCase().replace(/\s+/g, "");
  if (!/^IUMF-[A-Z2-9]{9}$/.test(code)) return json({ ok: false, error: "FRIENDS_GIFT_INVALID" }, 400);

  try {
    const booking = await authorizedBooking(request, id, env.BOOKINGS_DB);
    if (!booking) return json({ ok: false, error: "BOOKING_NOT_FOUND" }, 404);
    const currentPilgrimID = await accountPilgrimID(request, env.HOTELS_DB);
    if (!currentPilgrimID) return json({ ok: false, error: "ACCOUNT_SESSION_REQUIRED" }, 401);

    const identity = await bookingIdentity(env.HOTELS_DB, id);
    if (!identity || !["submitted", "manual_review", "confirmed"].includes(identity.status)) {
      return json({ ok: false, error: "IDENTITY_CONFIRMATION_REQUIRED" }, 409);
    }

    const existingOtherTrip = await env.HOTELS_DB.prepare(
      `SELECT booking_id FROM iumrah_friends_redemptions
       WHERE identity_fingerprint=?1 AND booking_id<>?2 AND status<>'cancelled' LIMIT 1`,
    ).bind(identity.identity_fingerprint, id).first<{ booking_id: string }>();
    if (existingOtherTrip) return json({ ok: false, error: "FRIENDS_NEW_CUSTOMER_ONLY" }, 409);

    const before = await friendsBookingSummary(request, id, env, booking);
    if (!before || Number(before.remainingAllowanceUsd ?? 0) < 100) {
      return json({ ok: false, error: "FRIENDS_DISCOUNT_LIMIT_REACHED" }, 409);
    }

    const gift = await env.HOTELS_DB.prepare(
      `SELECT id,referrer_pilgrim_id,status FROM iumrah_friends_gifts
       WHERE gift_token=?1 LIMIT 1`,
    ).bind(code).first<{ id: string; referrer_pilgrim_id: number; status: string }>();
    if (!gift || gift.status !== "available") return json({ ok: false, error: "FRIENDS_GIFT_NOT_AVAILABLE" }, 409);
    if (Number(gift.referrer_pilgrim_id) === currentPilgrimID) {
      return json({ ok: false, error: "FRIENDS_SELF_REFERRAL" }, 409);
    }

    const now = new Date().toISOString();
    const redemptionID = `redeem-${crypto.randomUUID()}`;
    try {
      await env.HOTELS_DB.prepare(
        `INSERT INTO iumrah_friends_redemptions(
           id,gift_id,gift_token,referrer_pilgrim_id,redeemer_pilgrim_id,booking_id,
           identity_fingerprint,discount_usd,reward_usd,status,reward_status,created_at
         ) VALUES(?1,?2,?3,?4,?5,?6,?7,100,100,'pending','pending',?8)`,
      ).bind(
        redemptionID,
        gift.id,
        code,
        Number(gift.referrer_pilgrim_id),
        currentPilgrimID,
        id,
        identity.identity_fingerprint,
        now,
      ).run();
      await env.HOTELS_DB.prepare(
        `UPDATE iumrah_friends_gifts
         SET status='redeemed',redeemed_booking_id=?1,redeemed_at=?2
         WHERE id=?3 AND status='available'`,
      ).bind(id, now, gift.id).run();
    } catch {
      return json({ ok: false, error: "FRIENDS_GIFT_NOT_AVAILABLE" }, 409);
    }

    const after = await friendsBookingSummary(request, id, env, booking);
    if (after) await persistFriendsSnapshot(env.BOOKINGS_DB, booking, id, after as unknown as Record<string, unknown>);
    return json(after);
  } catch (error) {
    console.error("booking-control-friends-redeem-failed", error);
    return json({ ok: false, error: "FRIENDS_UNAVAILABLE" }, 500);
  }
}

export async function applyPilgrimFriendCredit(request: Request, id: string, env: BookingControlEnv): Promise<Response> {
  if (!env.BOOKINGS_DB) return json({ ok: false, error: "BOOKING_DB_NOT_CONFIGURED" }, 503);
  if (!env.HOTELS_DB) return json({ ok: false, error: "HOTELS_DB_NOT_CONFIGURED" }, 503);

  const body = await request.json().catch(() => null) as { amountUsd?: unknown } | null;
  const requested = Math.floor(Number(body?.amountUsd ?? 100) / 100) * 100;
  if (![100, 200].includes(requested)) return json({ ok: false, error: "FRIENDS_CREDIT_AMOUNT_INVALID" }, 400);

  try {
    const booking = await authorizedBooking(request, id, env.BOOKINGS_DB);
    if (!booking) return json({ ok: false, error: "BOOKING_NOT_FOUND" }, 404);
    const currentPilgrimID = await accountPilgrimID(request, env.HOTELS_DB);
    if (!currentPilgrimID) return json({ ok: false, error: "ACCOUNT_SESSION_REQUIRED" }, 401);

    const identity = await bookingIdentity(env.HOTELS_DB, id);
    if (!identity || !["submitted", "manual_review", "confirmed"].includes(identity.status)) {
      return json({ ok: false, error: "IDENTITY_CONFIRMATION_REQUIRED" }, 409);
    }

    const before = await friendsBookingSummary(request, id, env, booking);
    if (!before) return json({ ok: false, error: "FRIENDS_UNAVAILABLE" }, 500);
    const available = Number(before.availableCreditUsd ?? 0);
    const allowance = Number(before.remainingAllowanceUsd ?? 0);
    const usable = Math.floor(Math.min(requested, available, allowance) / 100) * 100;
    if (usable < 100) return json({ ok: false, error: "FRIENDS_CREDIT_UNAVAILABLE" }, 409);

    const now = new Date().toISOString();
    await env.HOTELS_DB.prepare(
      `INSERT INTO iumrah_friends_credit_ledger(
         id,pilgrim_id,amount_usd,source_type,source_id,booking_id,created_at
       ) VALUES(?1,?2,?3,'friends_credit_spend',?4,?5,?6)`,
    ).bind(
      `credit-${crypto.randomUUID()}`,
      currentPilgrimID,
      -usable,
      `spend-${id}-${crypto.randomUUID()}`,
      id,
      now,
    ).run();

    const after = await friendsBookingSummary(request, id, env, booking);
    if (after) await persistFriendsSnapshot(env.BOOKINGS_DB, booking, id, after as unknown as Record<string, unknown>);
    return json(after);
  } catch (error) {
    console.error("booking-control-friends-credit-failed", error);
    return json({ ok: false, error: "FRIENDS_UNAVAILABLE" }, 500);
  }
}

export async function updatePilgrimHotel(request: Request, id: string, env: BookingControlEnv): Promise<Response> {
  if (!env.BOOKINGS_DB) return json({ error: "BOOKING_DB_NOT_CONFIGURED" }, 503);
  if (!env.HOTELS_DB) return json({ error: "HOTELS_DB_NOT_CONFIGURED" }, 503);

  let body: Record<string, unknown>;
  try {
    const value = await request.json();
    if (!value || typeof value !== "object") throw new Error("INVALID_REQUEST");
    body = value as Record<string, unknown>;
  } catch {
    return json({ error: "INVALID_REQUEST" }, 400);
  }

  const roleRaw = clean(body.role, 32).toLowerCase();
  const role = roleRaw === "madinah" || roleRaw === "medina" ? "madinah" : "makkah";
  const expectedCity = role === "madinah" ? "Madinah" : "Makkah";
  const hotelId = clean(body.hotelId, 180);
  const coverImageURL = clean(body.coverImageURL, 700) || null;
  const roomId = clean(body.roomId, 180) || null;
  const requestedRoomCategory = parseRoomCategory(body.roomCategory);
  const roomSource = clean(body.roomSource, 80) || (requestedRoomCategory ? "iumrahPrimary" : roomId ? "hotelInventory" : null);
  const roomName = clean(body.roomName, 220) || null;
  const roomBeds = clean(body.roomBeds, 220) || null;
  const roomSizeM2 = typeof body.roomSizeM2 === "number" && Number.isFinite(body.roomSizeM2) ? body.roomSizeM2 : null;
  const roomMaxGuests = typeof body.roomMaxGuests === "number" && Number.isFinite(body.roomMaxGuests) ? Math.max(1, Math.round(body.roomMaxGuests)) : null;
  if (!hotelId) return json({ error: "INVALID_HOTEL" }, 400);

  try {
    const booking = await authorizedBooking(request, id, env.BOOKINGS_DB);
    if (!booking) return json({ error: "BOOKING_NOT_FOUND" }, 404);

    const hotel = await env.HOTELS_DB.prepare(
      "SELECT id, name, city FROM hotels WHERE id = ?1 AND status = 'published' LIMIT 1",
    ).bind(hotelId).first<{ id: string; name: string; city: string }>();
    if (!hotel) return json({ error: "HOTEL_NOT_FOUND" }, 404);
    const normalizedCity = String(hotel.city || "").trim().toLowerCase();
    const validCities = role === "madinah" ? ["madinah", "medina", "al madinah"] : ["makkah", "mecca"];
    if (normalizedCity && !validCities.includes(normalizedCity)) {
      return json({ error: "HOTEL_CITY_MISMATCH", expectedCity }, 409);
    }

    let canonicalRoomName = roomName;
    let canonicalRoomBeds = roomBeds;
    let canonicalRoomMaxGuests = roomMaxGuests;

    if (requestedRoomCategory) {
      const categoryRecord = await findHotelRoomCategory(env.HOTELS_DB, hotelId, requestedRoomCategory);
      if (!categoryRecord) return json({ error: "ROOM_CATEGORY_NOT_FOUND" }, 404);
      canonicalRoomName = categoryRecord.display_name;
      canonicalRoomBeds = categoryRecord.bed_configuration;
      canonicalRoomMaxGuests = categoryRecord.max_guests;
    }

    if (roomId) {
      const room = await env.HOTELS_DB.prepare(
        "SELECT id FROM hotel_rooms WHERE id = ?1 AND hotel_id = ?2 LIMIT 1",
      ).bind(roomId, hotelId).first<{ id: string }>();
      if (!room) return json({ error: "ROOM_NOT_FOUND" }, 404);
    }

    const payload = JSON.parse(booking.payload_json || "{}") as Record<string, unknown>;
    const rawHotelNames = payload.hotelNames && typeof payload.hotelNames === "object"
      ? payload.hotelNames as Record<string, unknown>
      : {};
    payload.hotelNames = {
      ...rawHotelNames,
      [role]: hotel.name,
    };

    const rawSelection = payload.selection && typeof payload.selection === "object"
      ? payload.selection as Record<string, unknown>
      : {};
    const hotelKey = role === "madinah" ? "madinahHotelId" : "makkahHotelId";
    const roomKey = role === "madinah" ? "madinahRoomId" : "makkahRoomId";
    const categoryKey = role === "madinah" ? "madinahRoomCategory" : "makkahRoomCategory";
    payload.selection = {
      ...rawSelection,
      [hotelKey]: hotelId,
      [roomKey]: roomId,
      [categoryKey]: requestedRoomCategory,
    };

    const snapshot = {
      hotelId,
      hotelName: hotel.name,
      city: hotel.city || expectedCity,
      coverImageURL,
      roomId,
      roomName: canonicalRoomName,
      roomBeds: canonicalRoomBeds,
      roomSizeM2,
      roomMaxGuests: canonicalRoomMaxGuests,
      roomCategory: requestedRoomCategory,
      roomSource,
    };
    if (role === "madinah") payload.madinahHotelSelection = snapshot;
    else payload.hotelSelection = snapshot;

    const now = new Date().toISOString();
    if (role === "makkah") {
      await ensureBookingRoomColumns(env.BOOKINGS_DB);
      await env.BOOKINGS_DB.prepare(
        `UPDATE bookings
         SET makkah_hotel = ?1,
             makkah_room_category = ?2,
             makkah_room_name = ?3,
             makkah_room_id = ?4,
             payload_json = ?5,
             updated_at = ?6
         WHERE id = ?7`,
      ).bind(
        hotel.name,
        requestedRoomCategory,
        canonicalRoomName,
        roomId,
        JSON.stringify(payload),
        now,
        id,
      ).run();
    } else {
      await persistBookingPayload(env.BOOKINGS_DB, id, payload, now);
    }

    return json({ ok: true, updatedAt: now, role, hotelSelection: snapshot });
  } catch (error) {
    console.error("booking-control-hotel-failed", error);
    return json({ error: "BOOKING_UPDATE_FAILED" }, 500);
  }
}

export async function updatePilgrimContact(request: Request, id: string, env: BookingControlEnv): Promise<Response> {
  if (!env.BOOKINGS_DB) return json({ error: "BOOKING_DB_NOT_CONFIGURED" }, 503);

  let body: Record<string, unknown>;
  try {
    const value = await request.json();
    if (!value || typeof value !== "object") throw new Error("INVALID_REQUEST");
    body = value as Record<string, unknown>;
  } catch {
    return json({ error: "INVALID_REQUEST" }, 400);
  }

  try {
    const booking = await authorizedBooking(request, id, env.BOOKINGS_DB);
    if (!booking) return json({ error: "BOOKING_NOT_FOUND" }, 404);
    const payload = JSON.parse(booking.payload_json || "{}") as Record<string, unknown>;
    const profile = payload.pilgrimProfile && typeof payload.pilgrimProfile === "object"
      ? payload.pilgrimProfile as Record<string, unknown>
      : {};
    payload.pilgrimProfile = {
      ...profile,
      telegram: clean(body.telegram, 180),
      whatsapp: clean(body.whatsapp, 100),
    };
    const now = new Date().toISOString();
    await persistBookingPayload(env.BOOKINGS_DB, id, payload, now);
    return json({ ok: true, updatedAt: now });
  } catch (error) {
    console.error("booking-control-contact-failed", error);
    return json({ error: "BOOKING_UPDATE_FAILED" }, 500);
  }
}

export async function updatePilgrimCustomization(request: Request, id: string, env: BookingControlEnv): Promise<Response> {
  if (!env.BOOKINGS_DB) return json({ error: "BOOKING_DB_NOT_CONFIGURED" }, 503);

  let body: Record<string, unknown>;
  try {
    const value = await request.json();
    if (!value || typeof value !== "object") throw new Error("INVALID_REQUEST");
    body = value as Record<string, unknown>;
  } catch {
    return json({ error: "INVALID_REQUEST" }, 400);
  }

  try {
    const booking = await authorizedBooking(request, id, env.BOOKINGS_DB);
    if (!booking) return json({ error: "BOOKING_NOT_FOUND" }, 404);
    const payload = JSON.parse(booking.payload_json || "{}") as Record<string, unknown>;
    const current = payload.customization && typeof payload.customization === "object"
      ? payload.customization as Record<string, unknown>
      : {};
    const input = payload.input && typeof payload.input === "object" ? payload.input as Record<string, unknown> : {};
    const includeMadinah = input.includeMadinah === true;
    const ziyaratMakkah = bool(body.ziyaratMakkah, current.ziyaratMakkah !== false);
    const ziyaratMadinah = includeMadinah ? bool(body.ziyaratMadinah, current.ziyaratMadinah !== false) : false;
    const esim = bool(body.esim, current.esim !== false);
    payload.customization = { ...current, ziyaratMakkah, ziyaratMadinah, esim };

    const services = Array.isArray(payload.includedServices)
      ? payload.includedServices.filter((item): item is string => typeof item === "string")
      : [];
    const nextServices = new Set(services.filter((item) => item !== "ziyaratMakkah" && item !== "ziyaratMadinah" && item !== "esim"));
    if (ziyaratMakkah) nextServices.add("ziyaratMakkah");
    if (ziyaratMadinah) nextServices.add("ziyaratMadinah");
    if (esim) nextServices.add("esim");
    payload.includedServices = Array.from(nextServices);

    const now = new Date().toISOString();
    await persistBookingPayload(env.BOOKINGS_DB, id, payload, now);
    return json({ ok: true, updatedAt: now, customization: payload.customization });
  } catch (error) {
    console.error("booking-control-customization-failed", error);
    return json({ error: "BOOKING_UPDATE_FAILED" }, 500);
  }
}
