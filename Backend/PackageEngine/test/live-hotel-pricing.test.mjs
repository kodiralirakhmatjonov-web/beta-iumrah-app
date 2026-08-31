import assert from "node:assert/strict";
import fs from "node:fs";

const pricing = fs.readFileSync(new URL("../src/pricing.ts", import.meta.url), "utf8");
const hotelCosts = fs.readFileSync(new URL("../src/hotel-costs.ts", import.meta.url), "utf8");
const flightOptions = fs.readFileSync(new URL("../src/flight-options.ts", import.meta.url), "utf8");

// A Booking/Expedia total for the requested stay must never be multiplied by
// room count a second time in the Package Engine.
assert.match(pricing, /if \(cost\.unit === "totalStay"\) return amount/);

// Live hotel observations must be pinned to the exact selected hotel and stay.
assert.match(hotelCosts, /observation\.hotelId !== hotelId/);
assert.match(hotelCosts, /observation\.checkInDate !== expected\.checkIn/);
assert.match(hotelCosts, /observation\.checkOutDate !== expected\.checkOut/);
assert.match(hotelCosts, /LIVE_PROVIDERS = new Set\(\["booking", "expedia"\]\)/);

// Every flight-option package quote resolves hotel costs for that exact date pair.
assert.match(flightOptions, /const pairContext = adjustedContextForPair/);
assert.match(flightOptions, /await resolveHotelCosts\(pairContext, env\)/);

console.log("live hotel pricing contract OK");
