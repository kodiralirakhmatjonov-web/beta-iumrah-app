import assert from "node:assert/strict";
import fs from "node:fs";

const categories = fs.readFileSync(new URL("../src/room-categories.ts", import.meta.url), "utf8");
const booking = fs.readFileSync(new URL("../src/booking-control.ts", import.meta.url), "utf8");
const index = fs.readFileSync(new URL("../src/index.ts", import.meta.url), "utf8");

for (const value of ["DOUBLE", "TRIPLE", "QUADRUPLE"]) {
  assert.ok(categories.includes(`'${value}'`), `${value} must be a persisted room category`);
}
for (const column of ["makkah_room_category", "makkah_room_name", "makkah_room_id"]) {
  assert.ok(categories.includes(column), `${column} must be part of the booking schema migration`);
  assert.ok(booking.includes(column), `${column} must be written during booking updates`);
}
assert.ok(index.includes("/room-categories"), "Package Engine must expose hotel room categories to iOS");
assert.ok(booking.includes("makkahRoomCategory"), "booking payload selection must persist the room category");
console.log("room category persistence contract OK");
