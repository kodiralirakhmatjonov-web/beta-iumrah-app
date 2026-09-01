import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { normalizeItinerary, searchDateOffsets, tierDefinitions, bestFlightPair } from '../.runtime-dist/package-search.js';
import { calculatePackageQuote } from '../.runtime-dist/pricing.js';
import { normalizeOfficialCarrierText, officialCarrierBotCapabilities, officialCarrierBotCount } from '../.runtime-dist/server-flight-bots.js';
import { providerFlightSearch } from '../.runtime-dist/generator-components.js';

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

test('weekly flexible scheduler searches a full seven-day window and exact does not fan out', () => {
  assert.deepEqual(searchDateOffsets({ ...baseRequest, flexibility: 'plusMinusTwo' }), [0, -1, 1, -2, 2, -3, 3]);
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



test('provider search reports source failure instead of pretending the airline has no flights', async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => { throw new Error('NETWORK_TEST_FAILURE'); };
  try {
    const request = new Request('https://iumrah.app/api/package/flights/provider-search', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        providerId: 'uzbekistanAirways',
        direction: 'outbound',
        origin: 'TAS',
        destination: 'JED',
        travelDate: '2026-09-10',
        dateOffset: 0,
        travelers,
      }),
    });
    const response = await providerFlightSearch(request, {});
    const body = await response.json();
    assert.equal(body.ok, true);
    assert.deepEqual(body.candidates, []);
    assert.match(body.providerError, /NETWORK_TEST_FAILURE/);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

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

const hyBot = { id: 'uzbekistanAirways', label: 'Uzbekistan Airways', airlineCodes: ['HY'], fareScope: 'perPassenger', startURL: 'https://booking.uzairways.com/', officialHosts: ['booking.uzairways.com'] };
const hhBot = { id: 'qanotSharq', label: 'Qanot Sharq', airlineCodes: ['HH'], fareScope: 'perPassenger', startURL: 'https://booking.qanotsharq.com/websky_grs/', officialHosts: ['booking.qanotsharq.com'] };
const fixture = (name) => fs.readFileSync(new URL(`./fixtures/${name}`, import.meta.url), 'utf8');

test('production carrier registry exposes only four reviewed providers and only Uzbekistan Airways is server-capable', () => {
  const capabilities = officialCarrierBotCapabilities();
  assert.deepEqual(capabilities.map((item) => item.id), [
    'uzbekistanAirways',
    'qanotSharq',
    'centrumAir',
    'airSamarkand',
  ]);
  assert.equal(officialCarrierBotCount(), 1);
  assert.deepEqual(
    capabilities.map((item) => [item.id, item.serverMode]),
    [
      ['uzbekistanAirways', 'uzbekistanForm'],
      ['qanotSharq', 'deviceOnly'],
      ['centrumAir', 'deviceOnly'],
      ['airSamarkand', 'deviceOnly'],
    ],
  );
});

test('official carrier parser returns exact HY335 from airline-owned result text', async () => {
  const html = fixture('uzbekistan-hy335.html');
  const values = await normalizeOfficialCarrierText(html, hyBot, botArgs(), {});
  assert.equal(values.length, 1);
  assert.equal(values[0].providerId, 'uzbekistanAirways');
  assert.equal(values[0].flightNumber, 'HY335');
  assert.equal(values[0].groupFareUsd, 560.25);
  assert.equal(values[0].segments.length, 1);
});



test('official carrier parser accepts a direct same-day result without fabricating duration', async () => {
  const html = `<div>10 September 2026 TAS JED Uzbekistan Airways HY335 05:10 09:20 Direct Grand total USD 560.25</div>`;
  const values = await normalizeOfficialCarrierText(html, hyBot, botArgs(), {});
  assert.equal(values.length, 1);
  assert.equal(values[0].durationMinutes, 0);
  assert.equal(values[0].segments[0].durationMinutes, 0);
});

test('official carrier parser rejects fare blocks without an exact airline flight number', async () => {
  const html = `<div>10 September 2026 TAS JED 05:10 09:20 Direct 4 h 10 min Google Flights reference USD 560.25</div>`;
  const values = await normalizeOfficialCarrierText(html, hyBot, botArgs(), {});
  assert.equal(values.length, 0);
});

test('official carrier parser rejects ambiguous multi-flight blocks until every segment is provider-normalized', async () => {
  const html = `<div>10 September 2026 TAS SHJ JED HY335 HY777 05:10 08:00 10:00 12:00 7 h 20 min USD 500</div>`;
  const values = await normalizeOfficialCarrierText(html, hyBot, botArgs(), {});
  assert.equal(values.length, 0);
});


test('Qanot parser returns exact HH573 with source fare and currency', async () => {
  const values = await normalizeOfficialCarrierText(fixture('qanot-hh573.html'), hhBot, botArgs(), {});
  assert.equal(values.length, 1);
  assert.equal(values[0].flightNumber, 'HH573');
  assert.equal(values[0].currency, 'USD');
  assert.equal(values[0].groupFareUsd, 415);
});

test('official carrier parser rejects the wrong route', async () => {
  const html = `<div>10 September 2026 TAS MED Uzbekistan Airways HY335 05:10 09:20 Direct 4 h 10 min USD 560.25</div>`;
  assert.equal((await normalizeOfficialCarrierText(html, hyBot, botArgs(), {})).length, 0);
});

test('official carrier parser rejects the wrong date', async () => {
  const html = `<div>11 September 2026 TAS JED Uzbekistan Airways HY335 05:10 09:20 Direct 4 h 10 min USD 560.25</div>`;
  assert.equal((await normalizeOfficialCarrierText(html, hyBot, botArgs(), {})).length, 0);
});

test('official carrier parser rejects a missing fare', async () => {
  const html = `<div>10 September 2026 TAS JED Uzbekistan Airways HY335 05:10 09:20 Direct 4 h 10 min</div>`;
  assert.equal((await normalizeOfficialCarrierText(html, hyBot, botArgs(), {})).length, 0);
});

test('official carrier parser rejects a negative fare instead of stripping the sign', async () => {
  const html = `<div>10 September 2026 TAS JED Uzbekistan Airways HY335 05:10 09:20 Direct 4 h 10 min USD -560.25</div>`;
  assert.equal((await normalizeOfficialCarrierText(html, hyBot, botArgs(), {})).length, 0);
});


test('official carrier parser preserves decimal-comma and mixed grouping fares', async () => {
  const decimalComma = `<div>10 September 2026 TAS JED Uzbekistan Airways HY335 05:10 09:20 Direct Grand total USD 560,25</div>`;
  const commaValues = await normalizeOfficialCarrierText(decimalComma, hyBot, botArgs(), {});
  assert.equal(commaValues.length, 1);
  assert.equal(commaValues[0].groupFareUsd, 560.25);

  const europeanGrouping = `<div>10 September 2026 TAS JED Uzbekistan Airways HY335 05:10 09:20 Direct Grand total USD 1.120,50</div>`;
  const groupedValues = await normalizeOfficialCarrierText(europeanGrouping, hyBot, botArgs(), {});
  assert.equal(groupedValues.length, 1);
  assert.equal(groupedValues[0].groupFareUsd, 1120.5);
});

test('official carrier parser rejects an unlabeled multi-passenger fare', async () => {
  const html = `<div>10 September 2026 TAS JED Uzbekistan Airways HY335 05:10 09:20 Direct USD 560.25</div>`;
  assert.equal((await normalizeOfficialCarrierText(html, hyBot, botArgs(), {})).length, 0);
});

test('official carrier parser preserves an explicit party total without multiplying it', async () => {
  const html = `<div>10 September 2026 TAS JED Uzbekistan Airways HY335 05:10 09:20 Direct Grand total USD 560.25</div>`;
  const values = await normalizeOfficialCarrierText(html, hyBot, botArgs(), {});
  assert.equal(values.length, 1);
  assert.equal(values[0].groupFareUsd, 560.25);
});

test('official carrier parser multiplies an explicit per-passenger adult fare only for adults', async () => {
  const html = `<div>10 September 2026 TAS JED Uzbekistan Airways HY335 05:10 09:20 Direct USD 280.25 per passenger</div>`;
  const values = await normalizeOfficialCarrierText(html, hyBot, botArgs(), {});
  assert.equal(values.length, 1);
  assert.equal(values[0].groupFareUsd, 560.5);
});

test('official carrier parser rejects per-passenger fare when children or infants are present', async () => {
  const html = `<div>10 September 2026 TAS JED Uzbekistan Airways HY335 05:10 09:20 Direct USD 280.25 per passenger</div>`;
  const mixed = botArgs();
  mixed.travelers = { adults: 1, children: 1, infants: 0, rooms: 1 };
  assert.equal((await normalizeOfficialCarrierText(html, hyBot, mixed, {})).length, 0);
});

test('official carrier parser rejects promotional from fares', async () => {
  const html = `<div>10 September 2026 TAS JED Uzbekistan Airways HY335 05:10 09:20 Direct price from USD 199</div>`;
  assert.equal((await normalizeOfficialCarrierText(html, hyBot, botArgs(), {})).length, 0);
});

test('official carrier parser accepts compact HH573 but never another carrier code', async () => {
  const valid = `<div>10 September 2026 TAS JED Qanot Sharq HH573 06:00 10:15 Direct Grand total USD 415</div>`;
  const values = await normalizeOfficialCarrierText(valid, hhBot, botArgs(), {});
  assert.equal(values.length, 1);
  assert.equal(values[0].flightNumber, 'HH573');

  const wrongCarrier = `<div>10 September 2026 TAS JED Qanot Sharq HY335 06:00 10:15 Direct USD 415</div>`;
  assert.equal((await normalizeOfficialCarrierText(wrongCarrier, hhBot, botArgs(), {})).length, 0);
});

test('official carrier parser rejects numeric fragments as flight numbers', async () => {
  const html = `<div>10 September 2026 TAS JED Uzbekistan Airways 23 2 05:10 09:20 Direct 4 h 10 min USD 560.25</div>`;
  assert.equal((await normalizeOfficialCarrierText(html, hyBot, botArgs(), {})).length, 0);
});
