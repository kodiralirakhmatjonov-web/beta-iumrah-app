import type { D1Like, D1PreparedStatementLike } from "./primary-hotels";
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
  const token = bookingToken(request);
  if (!validBookingId(id) || token.length < 24 || token.length > 128) return null;
  const hash = await hashBookingToken(token);
  return db.prepare(
    "SELECT id, payload_json FROM bookings WHERE id = ?1 AND access_token_hash = ?2 LIMIT 1",
  ).bind(id, hash).first<BookingRow>();
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
    payload.customization = { ...current, ziyaratMakkah, ziyaratMadinah };

    const services = Array.isArray(payload.includedServices)
      ? payload.includedServices.filter((item): item is string => typeof item === "string")
      : [];
    const nextServices = new Set(services.filter((item) => item !== "ziyaratMakkah" && item !== "ziyaratMadinah"));
    if (ziyaratMakkah) nextServices.add("ziyaratMakkah");
    if (ziyaratMadinah) nextServices.add("ziyaratMadinah");
    payload.includedServices = Array.from(nextServices);

    const now = new Date().toISOString();
    await persistBookingPayload(env.BOOKINGS_DB, id, payload, now);
    return json({ ok: true, updatedAt: now, customization: payload.customization });
  } catch (error) {
    console.error("booking-control-customization-failed", error);
    return json({ error: "BOOKING_UPDATE_FAILED" }, 500);
  }
}
