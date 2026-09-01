import assert from 'node:assert/strict';
import fs from 'node:fs';

const categories = fs.readFileSync(new URL('../src/room-categories.ts', import.meta.url), 'utf8');
const booking = fs.readFileSync(new URL('../src/booking-control.ts', import.meta.url), 'utf8');
const index = fs.readFileSync(new URL('../src/index.ts', import.meta.url), 'utf8');

for (const value of ['DOUBLE', 'TRIPLE', 'QUADRUPLE']) {
  assert.ok(categories.includes(`'${value}'`), `${value} must remain a persisted room category`);
}
for (const column of ['makkah_room_category', 'makkah_room_name', 'makkah_room_id']) {
  assert.ok(categories.includes(column), `${column} must remain part of booking schema support`);
  assert.ok(booking.includes(column), `${column} must remain writable during booking updates`);
}
assert.ok(categories.includes('from "./d1"'));
assert.ok(booking.includes('from "./d1"'));
assert.ok(index.includes('/room-categories'));
console.log('room category persistence contract OK');
