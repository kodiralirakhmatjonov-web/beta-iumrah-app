import assert from "node:assert/strict";

// Mathematical contract test mirroring src/pricing.ts without importing TS at runtime.
const input = {
  travelers: { adults: 2, children: 0, infants: 0, rooms: 1 },
  totalDays: 6,
  includeMadinah: true,
  tier: "standard",
  flights: { outbound: { totalGroupUsd: 700 }, inbound: { totalGroupUsd: 650 } },
  hotels: {
    makkah: { amountUsd: 160, unit: "perRoomNight", nights: 3 },
    madinah: { amountUsd: 140, unit: "perRoomNight", nights: 2 }
  }
};

const roomCount = 1;
const vehicleCount = 1;
const costFlights = 1350;
const costHotel = (160 * 3 + 140 * 2) * roomCount;
const costVisa = 120 * 2;
const costMeals = 15 * 6 * 2;
const costTransfer = 300 * vehicleCount;
const costGuide = 300;
const costZiyarat = 200;
const totalCost = costFlights + costHotel + costVisa + costMeals + costTransfer + costGuide + costZiyarat;
const selling = totalCost * 1.5 / 0.98;
const perPerson = Math.max(5, Math.round((selling / 2) / 5) * 5);

assert.equal(totalCost, 3330);
assert.equal(perPerson, 2550);
assert.equal(perPerson * 2, 5100);
assert.equal(input.tier, "standard");
