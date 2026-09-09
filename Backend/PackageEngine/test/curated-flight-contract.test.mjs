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
  assert.match(ignav, /itinerary\.legs\.every\(\(item\) => item\.stops === 0\)/);
});


test('Business curation distinguishes true round-trip fares from system-paired one-way fares', () => {
  assert.match(ignav, /"\/fares\/one-way"/);
  assert.match(ignav, /"\/fares\/round-trip"/);
  assert.match(ignav, /round_trip_compare/);
  assert.match(ignav, /open_jaw_one_way_pairing/);
  assert.match(ignav, /pairCuratedLegs/);
  assert.match(ignav, /offer_type: "paired_one_way"/);
  assert.match(ignav, /annotateCurationItinerary\(itinerary, "round_trip", "complete"\)/);
  assert.match(ignav, /broad_airline_fallback_by_leg/);
});

test('staff curation can retain Ignav unverified discovery hints without exposing fares publicly', () => {
  assert.match(ignav, /requireVerified = true/);
  assert.match(ignav, /false,\n\s*\)\)/);
  assert.match(curated, /\["verified", "unverified"\]/);
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


test('public recommendations support origin-wide JED/MED discovery and bypass stale CDN cache', () => {
  const publicBlock = curated.slice(
    curated.indexOf('export async function publicCuratedFlightRecommendations'),
    curated.indexOf('export async function curatedCalendarRows')
  );
  assert.match(publicBlock, /umrah_origin/);
  assert.match(publicBlock, /inbound_origin IS NULL AND outbound_origin = \?/);
  assert.match(publicBlock, /outbound_destination IN \('JED', 'MED'\)/);
  assert.match(publicBlock, /inbound_origin IS NULL AND outbound_origin IN \('JED', 'MED'\)/);
  assert.match(publicBlock, /inbound_origin IS NOT NULL AND outbound_origin = \?/);
  assert.match(publicBlock, /canonicalOfferType/);
  assert.match(publicBlock, /canonicalJourneyRole/);
  assert.match(publicBlock, /"no-store"/);
});

test('legacy one-leg rows are repaired instead of inheriting paired/complete schema defaults', () => {
  assert.match(curated, /function canonicalOfferType/);
  assert.match(curated, /if \(itinerary\.legs\.length === 1\) return "one_way"/);
  assert.match(curated, /function canonicalJourneyRole/);
  assert.match(curated, /storedRole === "outbound" \|\| storedRole === "return"/);
  assert.match(curated, /originIsSaudi && !destinationIsSaudi/);
  assert.match(curated, /SELECT id, itinerary_json, offer_type, journey_role, fingerprint/);
});


test('publishing uses structural fingerprints so repeat searches update instead of duplicate', () => {
  assert.match(curated, /function curatedFingerprint/);
  assert.match(curated, /WHERE fingerprint = \?/);
  assert.match(curated, /ORDER BY CASE WHEN fingerprint = \? THEN 0 ELSE 1 END/);
  assert.match(curated, /fingerprint=excluded\.fingerprint/);
});

test('calendar only consumes complete curated fares, never a single one-way leg', () => {
  const calendarBlock = curated.slice(curated.indexOf('export async function curatedCalendarRows'));
  assert.match(calendarBlock, /journey_role = 'complete'/);
});

test('calendar merges curated rows then chooses the lowest per-traveler fare for each date', () => {
  assert.match(calendar, /curatedCalendarRows/);
  assert.match(calendar, /const values: CalendarRow\[\] = \[\.\.\.\(rows\.results \?\? \[\]\), \.\.\.curatedRows\]/);
  assert.match(calendar, /row\.min_per_traveler_fare < existing\.min_per_traveler_fare/);
});
