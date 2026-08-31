import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeItinerary, searchDateOffsets, tierDefinitions, bestFlightPair } from '../.runtime-dist/package-search.js';
import { calculatePackageQuote } from '../.runtime-dist/pricing.js';
import { normalizeOfficialCarrierText } from '../.runtime-dist/server-flight-bots.js';

const travelers = { adults: 2, children: 0, infants: 0, rooms: 1 };
const baseRequest = {
  clientRequestId: 'runtime_contract_001',
  originCode: 'TAS',
  arrivalAirportCode: 'JED',
  startDate: '2026-09-10',
  endDate: '2026-09-17',
  flexibility: 'exact',
  includeMadinah: true,
  travelers,
};

test('Makkah-first itinerary owns correct hotel dates', () => {
  const value = normalizeItinerary(baseRequest);
  assert.equal(value.outboundDestination, 'JED');
  assert.equal(value.returnOrigin, 'MED');
  assert.equal(value.makkahCheckIn, '2026-09-10');
  assert.equal(value.makkahCheckOut, '2026-09-15');
  assert.equal(value.madinahCheckIn, '2026-09-15');
  assert.equal(value.madinahCheckOut, '2026-09-17');
});

test('Madinah-first itinerary reverses hotel dates authoritatively', () => {
  const value = normalizeItinerary({ ...baseRequest, arrivalAirportCode: 'MED' });
  assert.equal(value.outboundDestination, 'MED');
  assert.equal(value.returnOrigin, 'JED');
  assert.equal(value.madinahCheckIn, '2026-09-10');
  assert.equal(value.madinahCheckOut, '2026-09-12');
  assert.equal(value.makkahCheckIn, '2026-09-12');
  assert.equal(value.makkahCheckOut, '2026-09-17');
});

test('Sunday Umrah Club is Friday-Monday, Makkah-only, JED both ways', () => {
  const value = normalizeItinerary({
    ...baseRequest,
    startDate: '2026-09-13', // future Sunday: keep that weekend
    endDate: '2026-09-20',
    arrivalAirportCode: 'MED',
    includeMadinah: true,
    flexibility: 'weekend',
  });
  assert.equal(value.mode, 'sundayClub');
  assert.equal(value.startDate, '2026-09-11');
  assert.equal(value.endDate, '2026-09-14');
  assert.equal(value.includeMadinah, false);
  assert.equal(value.outboundDestination, 'JED');
  assert.equal(value.returnOrigin, 'JED');
  assert.deepEqual(tierDefinitions('sundayClub').map((x) => x.key), ['comfort', 'luxury']);
});

test('standard tier composition is Essential 1-star, Comfort 3-star, Luxury 5-star', () => {
  const values = tierDefinitions('standard');
  assert.deepEqual(values.map((x) => [x.key, x.pricingTier, x.stars, x.recommended]), [
    ['essential', 'economy', 1, false],
    ['comfort', 'comfort', 3, true],
    ['luxury', 'luxury', 5, false],
  ]);
});

test('flexible scheduler searches 0,-1,+1,-2,+2 and exact does not fan out', () => {
  assert.deepEqual(searchDateOffsets({ ...baseRequest, flexibility: 'plusMinusTwo' }), [0, -1, 1, -2, 2]);
  assert.deepEqual(searchDateOffsets(baseRequest), [0]);
});

function candidate(id, direction, dateOffset, fare) {
  return {
    id,
    providerId: 'uzbekistanAirways',
    sourceLabel: 'Uzbekistan Airways',
    direction,
    dateOffset,
    travelDate: dateOffset === 0 ? '2026-09-10' : '2026-09-11',
    origin: direction === 'outbound' ? 'TAS' : 'JED',
    destination: direction === 'outbound' ? 'JED' : 'TAS',
    airline: 'Uzbekistan Airways',
    airlineCode: 'HY',
    flightNumber: 'HY335',
    departureAt: '2026-09-10T05:00:00',
    arrivalAt: '2026-09-10T09:00:00',
    durationMinutes: 240,
    stops: 0,
    currency: 'USD',
    segments: [],
    groupFareUsd: fare,
  };
}

test('flight pair cannot cross flexible-date offsets', () => {
  const pair = bestFlightPair(
    [candidate('o0', 'outbound', 0, 500), candidate('o1', 'outbound', 1, 100)],
    [candidate('i0', 'inbound', 0, 500), candidate('i1', 'inbound', 1, 1200)],
  );
  assert.equal(pair.dateOffset, 0);
  assert.equal(pair.outbound.id, 'o0');
  assert.equal(pair.inbound.id, 'i0');
});

test('Haramain pricing is 300 SAR per traveler and separate from local transfer', () => {
  const common = {
    tier: 'comfort',
    includeMadinah: true,
    totalDays: 8,
    travelers,
    flights: { outbound: { totalGroupUsd: 1000 }, inbound: { totalGroupUsd: 1000 } },
    hotels: {
      makkah: { amountUsd: 100, unit: 'perRoomNight', nights: 5 },
      madinah: { amountUsd: 100, unit: 'perRoomNight', nights: 2 },
    },
  };
  const train = calculatePackageQuote({ ...common, intercityTransport: 'haramainTrain' });
  const road = calculatePackageQuote({ ...common, intercityTransport: 'road' });
  assert.equal(train.internal.costIntercity, 160); // 600 SAR / 3.75
  assert.equal(train.internal.costTransfer, 200);
  assert.equal(road.internal.costIntercity, 0);
  assert.equal(road.internal.costTransfer, 300);
});

test('negative client-like flight monetary input is rejected by production pricing', () => {
  assert.throws(() => calculatePackageQuote({
    tier: 'economy', includeMadinah: false, totalDays: 4, travelers,
    flights: { outbound: { totalGroupUsd: -10 }, inbound: { totalGroupUsd: 100 } },
    hotels: { makkah: { amountUsd: 100, unit: 'perRoomNight', nights: 3 }, madinah: null },
  }), /non-negative/);
});

function botArgs(direction = 'outbound') {
  return {
    searchId: 'runtime_contract_001', direction, dateOffset: 0,
    origin: direction === 'outbound' ? 'TAS' : 'JED',
    destination: direction === 'outbound' ? 'JED' : 'TAS',
    travelDate: '2026-09-10', travelers,
  };
}

const hyBot = { id: 'uzbekistanAirways', label: 'Uzbekistan Airways', airlineCodes: ['HY'], fareScope: 'perPassenger' };

test('official carrier parser returns exact HY335 from airline-owned result text', async () => {
  const html = `<article class="flight-card">TAS JED Uzbekistan Airways HY 335 05:10 09:20 Direct 4 h 10 min Economy USD 560.25</article>`;
  const values = await normalizeOfficialCarrierText(html, hyBot, botArgs(), {});
  assert.equal(values.length, 1);
  assert.equal(values[0].providerId, 'uzbekistanAirways');
  assert.equal(values[0].flightNumber, 'HY335');
  assert.equal(values[0].groupFareUsd, 1120.50);
  assert.equal(values[0].segments.length, 1);
});

test('official carrier parser rejects fare blocks without an exact airline flight number', async () => {
  const html = `<div>TAS JED 05:10 09:20 Direct 4 h 10 min Google Flights reference USD 560.25</div>`;
  const values = await normalizeOfficialCarrierText(html, hyBot, botArgs(), {});
  assert.equal(values.length, 0);
});

test('official carrier parser rejects ambiguous multi-flight blocks until every segment is provider-normalized', async () => {
  const html = `<div>TAS SHJ JED HY335 HY777 05:10 08:00 10:00 12:00 7 h 20 min USD 500</div>`;
  const values = await normalizeOfficialCarrierText(html, hyBot, botArgs(), {});
  assert.equal(values.length, 0);
});
