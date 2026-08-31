import type { Env } from "./env";
import { loadAuthoritativeQuoteAudit } from "./quote-audit";

function json(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
  });
}

function object(value: unknown): Record<string, any> | null {
  return value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, any> : null;
}

function sameString(a: unknown, b: unknown) {
  return String(a ?? "") === String(b ?? "");
}

function sameNumber(a: unknown, b: unknown) {
  return Number(a) === Number(b) && Number.isFinite(Number(a));
}

function requireMatch(condition: boolean, code: string) {
  if (!condition) throw new Error(code);
}

export async function createBookingThroughPackageGateway(request: Request, env: Env): Promise<Response> {
  if (!env.HOTELS_DB) return json({ ok: false, error: "HOTELS_DB_NOT_CONFIGURED" }, 503);
  try {
    const payload = object(await request.json());
    const booking = object(payload?.booking);
    const trace = object(booking?.generatorTrace);
    const quoteId = String(trace?.quoteId ?? "").trim();
    if (!payload || !booking || !trace || !quoteId) throw new Error("AUTHORITATIVE_QUOTE_REQUIRED");

    const stored = await loadAuthoritativeQuoteAudit(env.HOTELS_DB, quoteId);
    if (!stored || stored.authority !== "server_search") throw new Error("AUTHORITATIVE_QUOTE_NOT_FOUND");
    if (stored.expiresAt && Date.parse(stored.expiresAt) <= Date.now()) throw new Error("QUOTE_EXPIRED");

    const audit = stored.audit;
    const context = object(audit.context) ?? {};
    const itinerary = object(audit.itinerary) ?? {};
    const inputs = object(audit.selectedPricingInputs) ?? {};
    const outboundAudit = object(inputs.outbound) ?? {};
    const inboundAudit = object(inputs.inbound) ?? {};
    const makkahAudit = object(inputs.makkahHotel) ?? {};
    const madinahAudit = object(inputs.madinahHotel);
    const totals = object(audit.totals) ?? {};
    const requestInput = object(booking.input) ?? {};
    const requestTravelers = object(requestInput.travelers) ?? {};
    const auditTravelers = object(context.travelers) ?? {};
    const route = object(booking.route) ?? {};
    const stay = object(booking.stay) ?? {};
    const selection = object(booking.selection) ?? {};
    const traceOutbound = object(trace.outbound) ?? {};
    const traceInbound = object(trace.inbound) ?? {};
    const traceMakkah = object(trace.makkahHotel) ?? {};
    const traceMadinah = object(trace.madinahHotel);

    requireMatch(sameNumber(requestTravelers.adults, auditTravelers.adults), "TRAVELER_MISMATCH_ADULTS");
    requireMatch(sameNumber(requestTravelers.children, auditTravelers.children), "TRAVELER_MISMATCH_CHILDREN");
    requireMatch(sameNumber(requestTravelers.infants, auditTravelers.infants), "TRAVELER_MISMATCH_INFANTS");
    requireMatch(sameNumber(requestTravelers.rooms, auditTravelers.rooms), "TRAVELER_MISMATCH_ROOMS");

    requireMatch(sameString(requestInput.startDate, itinerary.startDate), "TRIP_START_DATE_MISMATCH");
    requireMatch(sameString(requestInput.endDate, itinerary.endDate), "TRIP_END_DATE_MISMATCH");
    requireMatch(sameString(route.originCode, itinerary.originCode), "ROUTE_ORIGIN_MISMATCH");
    requireMatch(sameString(route.outboundDestination, itinerary.outboundDestination), "ROUTE_OUTBOUND_MISMATCH");
    requireMatch(sameString(route.returnOrigin, itinerary.returnOrigin), "ROUTE_RETURN_MISMATCH");
    requireMatch(Boolean(requestInput.includeMadinah) === Boolean(itinerary.includeMadinah), "MADINAH_SCOPE_MISMATCH");
    requireMatch(sameString(stay.makkahCheckIn, itinerary.makkahCheckIn), "MAKKAH_CHECKIN_MISMATCH");
    requireMatch(sameString(stay.makkahCheckOut, itinerary.makkahCheckOut), "MAKKAH_CHECKOUT_MISMATCH");
    if (itinerary.includeMadinah) {
      requireMatch(sameString(stay.madinahCheckIn, itinerary.madinahCheckIn), "MADINAH_CHECKIN_MISMATCH");
      requireMatch(sameString(stay.madinahCheckOut, itinerary.madinahCheckOut), "MADINAH_CHECKOUT_MISMATCH");
    }

    requireMatch(sameString(traceOutbound.candidateId, outboundAudit.candidateId), "OUTBOUND_CANDIDATE_MISMATCH");
    requireMatch(sameString(traceInbound.candidateId, inboundAudit.candidateId), "INBOUND_CANDIDATE_MISMATCH");
    requireMatch(sameString(selection.makkahHotelId, makkahAudit.hotelId), "MAKKAH_HOTEL_MISMATCH");
    requireMatch(sameString(traceMakkah.hotelId, makkahAudit.hotelId), "MAKKAH_TRACE_MISMATCH");
    requireMatch(sameString(selection.makkahRoomId, makkahAudit.roomId), "MAKKAH_ROOM_MISMATCH");
    if (itinerary.includeMadinah) {
      requireMatch(Boolean(madinahAudit), "MADINAH_AUDIT_MISSING");
      requireMatch(sameString(selection.madinahHotelId, madinahAudit?.hotelId), "MADINAH_HOTEL_MISMATCH");
      requireMatch(sameString(traceMadinah?.hotelId, madinahAudit?.hotelId), "MADINAH_TRACE_MISMATCH");
      requireMatch(sameString(selection.madinahRoomId, madinahAudit?.roomId), "MADINAH_ROOM_MISMATCH");
    }

    const authoritativeTotal = Number(totals.publicTotalUsd);
    const authoritativePerPilgrim = Number(totals.publicPricePerPilgrimUsd);
    if (!Number.isFinite(authoritativeTotal) || authoritativeTotal <= 0 || !Number.isFinite(authoritativePerPilgrim) || authoritativePerPilgrim <= 0) {
      throw new Error("QUOTE_TOTAL_INVALID");
    }

    // Never forward client monetary values. The booking backend receives only the
    // server-audited public amount that belongs to this quoteId.
    booking.totalUsd = authoritativeTotal;
    booking.perPilgrimUsd = authoritativePerPilgrim;
    booking.planId = String(stored.packageKey ?? booking.planId ?? context.tier ?? "");
    payload.booking = booking;

    const upstream = env.PACKAGE_BOOKING_UPSTREAM?.trim() || new URL("/api/bookings", request.url).toString();
    const response = await fetch(upstream, {
      method: "POST",
      headers: {
        accept: "application/json",
        "content-type": "application/json",
        "user-agent": request.headers.get("user-agent") || "iumrah-package-gateway/1",
      },
      body: JSON.stringify(payload),
    });
    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers: {
        "content-type": response.headers.get("content-type") || "application/json; charset=utf-8",
        "cache-control": "no-store",
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "BOOKING_GATEWAY_REJECTED";
    const status = message === "QUOTE_EXPIRED" ? 409 : 400;
    return json({ ok: false, error: message }, status);
  }
}
