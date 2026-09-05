import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const curated = fs.readFileSync(new URL('../src/curated-flights.ts', import.meta.url), 'utf8');
const ignav = fs.readFileSync(new URL('../src/ignav-flights.ts', import.meta.url), 'utf8');
const index = fs.readFileSync(new URL('../src/index.ts', import.meta.url), 'utf8');
const calendar = fs.readFileSync(new URL('../src/flight-cache.ts', import.meta.url), 'utf8');

test('Business curation search keeps provider nonstop and airline filters behind staff auth', () => {
  assert.match(index, /url\.pathname\.startsWith\("\/api\/admin\/package"\)/);
  assert.match(index, /\/api\/admin\/package\/flights\/curation-search/);
  assert.match(ignav, /function validateCurationSearchBody/);
  assert.match(ignav, /airlines_include: include/);
  assert.match(ignav, /allow_self_transfer: raw\.allow_self_transfer \?\? false/);
  assert.match(ignav, /itinerary\.legs\.every\(\(leg\) => leg\.stops === 0\)/);
});

test('curated public recommendations deliberately omit supplier fare fields', () => {
  const publicBlock = curated.slice(
    curated.indexOf('export async function publicCuratedFlightRecommendations'),
    curated.indexOf('export async function curatedCalendarRows')
  );
  assert.match(publicBlock, /recommendations/);
  assert.doesNotMatch(publicBlock, /totalFare:/);
  assert.doesNotMatch(publicBlock, /perTravelerFare:/);
  assert.doesNotMatch(publicBlock, /min_per_traveler_fare/);
});

test('calendar merges curated rows then chooses the lowest per-traveler fare for each date', () => {
  assert.match(calendar, /curatedCalendarRows/);
  assert.match(calendar, /const values: CalendarRow\[\] = \[\.\.\.\(rows\.results \?\? \[\]\), \.\.\.curatedRows\]/);
  assert.match(calendar, /row\.min_per_traveler_fare < existing\.min_per_traveler_fare/);
});
