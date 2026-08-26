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

export async function deletePilgrimBooking(request: Request, id: string, env: BookingControlEnv): Promise<Response> {
  if (!env.BOOKINGS_DB) return json({ error: "BOOKING_DB_NOT_CONFIGURED" }, 503);

  try {
    const row = await authorizedBooking(request, id, env.BOOKINGS_DB);
    if (!row) return json({ error: "BOOKING_NOT_FOUND" }, 404);

    const childTables = await bookingChildTables(env.BOOKINGS_DB);
    const statements: D1PreparedStatementLike[] = childTables.map((table) =>
      env.BOOKINGS_DB!.prepare(`DELETE FROM "${table}" WHERE booking_id = ?1`).bind(id),
    );
    statements.push(env.BOOKINGS_DB.prepare("DELETE FROM bookings WHERE id = ?1").bind(id));
    await env.BOOKINGS_DB.batch(statements);

    return json({ ok: true, deleted: true });
  } catch (error) {
    console.error("booking-control-delete-failed", error);
    return json({ error: "BOOKING_DELETE_FAILED" }, 500);
  }
}

function clean(value: unknown, max = 240) {
  return typeof value === "string" ? value.trim().slice(0, max) : "";
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

    await ensureBookingRoomColumns(env.BOOKINGS_DB);

    const payload = JSON.parse(booking.payload_json || "{}") as Record<string, unknown>;
    const rawHotelNames = payload.hotelNames && typeof payload.hotelNames === "object"
      ? payload.hotelNames as Record<string, unknown>
      : {};
    payload.hotelNames = { ...rawHotelNames, makkah: hotel.name };

    const rawSelection = payload.selection && typeof payload.selection === "object"
      ? payload.selection as Record<string, unknown>
      : {};
    payload.selection = {
      ...rawSelection,
      makkahHotelId: hotelId,
      makkahRoomId: roomId,
      makkahRoomCategory: requestedRoomCategory,
    };
    payload.hotelSelection = {
      hotelId,
      hotelName: hotel.name,
      city: hotel.city,
      coverImageURL,
      roomId,
      roomName: canonicalRoomName,
      roomBeds: canonicalRoomBeds,
      roomSizeM2,
      roomMaxGuests: canonicalRoomMaxGuests,
      roomCategory: requestedRoomCategory,
      roomSource,
    };

    const now = new Date().toISOString();
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

    return json({ ok: true, updatedAt: now, hotelSelection: payload.hotelSelection });
  } catch (error) {
    console.error("booking-control-hotel-failed", error);
    return json({ error: "BOOKING_UPDATE_FAILED" }, 500);
  }
}
