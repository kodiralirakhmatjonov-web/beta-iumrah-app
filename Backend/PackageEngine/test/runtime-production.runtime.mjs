import test from 'node:test';
import assert from 'node:assert/strict';
import worker from '../.runtime-dist/index.js';
import { curatedPrimaryHotel } from '../.runtime-dist/generator-components.js';

function statementFor(handler) {
  return {
    values: [],
    bind(...values) { this.values = values; return this; },
    async first() { return handler('first', this.values); },
    async all() { return handler('all', this.values); },
    async run() { return handler('run', this.values) ?? { success: true }; },
  };
}

function hotelDb({ curated = null, fallback = null } = {}) {
  return {
    prepare(sql) {
      if (sql.includes('FROM primary_hotels p')) return statementFor(async () => curated);
      if (sql.includes('FROM hotels') && sql.includes('ORDER BY rating DESC')) return statementFor(async () => fallback);
      throw new Error(`Unexpected SQL in runtime test: ${sql}`);
    },
  };
}

test('curated Primary Hotel resolves from primary_hotels without a price', async () => {
  const env = { HOTELS_DB: hotelDb({ curated: { position: 1, hotel_id: 'makkah-5', stars: 5, city: 'Makkah' } }) };
  const response = await curatedPrimaryHotel(new URL('https://iumrah.app/api/package/primary-hotel?stars=5&city=Makkah&tier=comfort'), env);
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.hotelId, 'makkah-5');
  assert.equal(body.matchType, 'curatedPrimary');
  assert.equal(body.pricingMode, 'liveVerificationRequired');
  assert.equal('amount' in body, false);
  assert.equal('basePriceUsd' in body, false);
});

test('catalog fallback can select a hotel but still cannot fabricate a price', async () => {
  const env = { HOTELS_DB: hotelDb({ fallback: { id: 'catalog-3', stars: 3, city: 'Makkah' } }) };
  const response = await curatedPrimaryHotel(new URL('https://iumrah.app/api/package/primary-hotel?stars=3&city=Makkah&tier=standard'), env);
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.hotelId, 'catalog-3');
  assert.equal(body.isFallback, true);
  assert.equal(body.pricingMode, 'liveVerificationRequired');
  assert.equal('amount' in body, false);
});

test('invalid Primary Hotel query fails closed', async () => {
  const response = await curatedPrimaryHotel(new URL('https://iumrah.app/api/package/primary-hotel?stars=9&city=Makkah'), { HOTELS_DB: hotelDb() });
  assert.equal(response.status, 400);
});

test('all removed flight/search/quote routes are 404 on the active worker', async () => {
  const removed = [
    '/api/package/flights/provider-search',
    '/api/package/search-sessions',
    '/api/package/search-sessions/abc',
    '/api/package/flight-options/quote',
    '/api/package/quote',
    '/api/package/bookings',
    '/api/package/hotel-component-price',
  ];
  for (const path of removed) {
    const response = await worker.fetch(new Request(`https://iumrah.app${path}`, { method: path.includes('primary-hotels') ? 'GET' : 'POST' }), {});
    assert.equal(response.status, 404, `${path} must stay removed`);
  }
});

function validIgnavResponse(overrides = {}) {
  return {
    origin: 'TAS',
    destination: 'JED',
    departure_date: '2026-10-03',
    itineraries: [{
      price: { amount: 612, currency: 'USD', status: 'verified' },
      outbound: {
        carrier: 'Uzbekistan Airways',
        duration_minutes: 410,
        segments: [{
          marketing_carrier_code: 'HY',
          flight_number: '337',
          operating_carrier_name: 'Uzbekistan Airways',
          departure_airport: 'TAS',
          departure_time_local: '2026-10-03T08:10:00',
          departure_timezone: 'Asia/Tashkent',
          departure_time_utc: '2026-10-03T03:10:00Z',
          arrival_airport: 'JED',
          arrival_time_local: '2026-10-03T11:00:00',
          arrival_timezone: 'Asia/Riyadh',
          arrival_time_utc: '2026-10-03T08:00:00Z',
          duration_minutes: 410,
          aircraft: 'Airbus A321neo',
        }],
      },
      cabin_class: 'economy',
      bags: { carry_on: 1, checked: 1 },
      requires_self_transfer: false,
      ignav_id: '5e4fcd2f1dc340649eb19f6ee2afb57a',
      ...overrides,
    }],
  };
}

test('Ignav flight route fails closed when Worker secret is missing', async () => {
  const response = await worker.fetch(new Request('https://iumrah.app/api/package/flights/search', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ origin: 'TAS', destination: 'JED', departure_date: '2026-10-03' }),
  }), {});
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error, 'FLIGHT_PROVIDER_NOT_CONFIGURED');
});

test('Ignav proxy forwards supported filters and returns only normalized verified itinerary data', async () => {
  const originalFetch = globalThis.fetch;
  let captured;
  globalThis.fetch = async (url, init) => {
    captured = { url: String(url), headers: init.headers, body: JSON.parse(init.body) };
    return new Response(JSON.stringify(validIgnavResponse()), { status: 200, headers: { 'content-type': 'application/json' } });
  };
  try {
    const response = await worker.fetch(new Request('https://iumrah.app/api/package/flights/search', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        direction: 'outbound', origin: 'TAS', destination: 'JED', departure_date: '2026-10-03',
        adults: 2, children: 1, infants_on_lap: 1, cabin_class: 'economy', max_stops: 1,
        min_carry_on_bags: 1, min_checked_bags: 1, max_price: 1500,
        departure_time_range: { earliest_hour: 6, latest_hour: 17, arrival_earliest_hour: 6, arrival_latest_hour: 23 },
        airlines_include: ['HY'], allow_self_transfer: false,
      }),
    }), { IGNAV_API_KEY: 'test-secret' });

    assert.equal(response.status, 200);
    const body = await response.json();
    assert.equal(body.ok, true);
    assert.equal(body.source, 'ignav');
    assert.equal(body.itineraries.length, 1);
    assert.equal(body.itineraries[0].flight_number, 'HY 337');
    assert.equal(body.itineraries[0].fare_scope, 'total_party');
    assert.equal(body.itineraries[0].price.amount, 612);
    assert.equal(body.itineraries[0].segments[0].departure_time_utc, '2026-10-03T03:10:00Z');
    assert.equal(captured.url, 'https://ignav.com/api/fares/one-way');
    assert.equal(captured.headers['x-api-key'], 'test-secret');
    assert.equal(captured.body.market, 'US');
    assert.equal(captured.body.adults, 2);
    assert.equal(captured.body.children, 1);
    assert.equal(captured.body.infants_on_lap, 1);
    assert.equal(captured.body.max_stops, 1);
    assert.deepEqual(captured.body.airlines_include, ['HY']);
    assert.equal(captured.body.allow_self_transfer, false);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('Ignav proxy rejects unverified fares and itineraries without authoritative UTC segment timestamps', async () => {
  const originalFetch = globalThis.fetch;
  let call = 0;
  globalThis.fetch = async () => {
    call += 1;
    const payload = call === 1
      ? validIgnavResponse({ price: { amount: 612, currency: 'USD', status: 'unverified' } })
      : validIgnavResponse({ outbound: {
          carrier: 'Uzbekistan Airways', duration_minutes: 410,
          segments: [{
            marketing_carrier_code: 'HY', flight_number: '337', operating_carrier_name: 'Uzbekistan Airways',
            departure_airport: 'TAS', departure_time_local: '2026-10-03T08:10:00', departure_timezone: 'Asia/Tashkent', departure_time_utc: null,
            arrival_airport: 'JED', arrival_time_local: '2026-10-03T11:00:00', arrival_timezone: 'Asia/Riyadh', arrival_time_utc: '2026-10-03T08:00:00Z',
            duration_minutes: 410, aircraft: null,
          }],
        } });
    return new Response(JSON.stringify(payload), { status: 200, headers: { 'content-type': 'application/json' } });
  };
  try {
    for (let index = 0; index < 2; index += 1) {
      const response = await worker.fetch(new Request('https://iumrah.app/api/package/flights/search', {
        method: 'POST', headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ origin: 'TAS', destination: 'JED', departure_date: '2026-10-03' }),
      }), { IGNAV_API_KEY: 'test-secret' });
      assert.equal(response.status, 200);
      assert.deepEqual((await response.json()).itineraries, []);
    }
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('Ignav proxy does not retry non-retryable authentication failures', async () => {
  const originalFetch = globalThis.fetch;
  let calls = 0;
  globalThis.fetch = async () => {
    calls += 1;
    return new Response(JSON.stringify({ error: { code: 'invalid_api_key' } }), { status: 401, headers: { 'content-type': 'application/json' } });
  };
  try {
    const response = await worker.fetch(new Request('https://iumrah.app/api/package/flights/search', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ origin: 'TAS', destination: 'JED', departure_date: '2026-10-03' }),
    }), { IGNAV_API_KEY: 'bad-secret' });
    assert.equal(response.status, 502);
    assert.equal(calls, 1);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('Ignav proxy rejects malformed dates, direction and self-transfer flags before upstream call', async () => {
  const originalFetch = globalThis.fetch;
  let calls = 0;
  globalThis.fetch = async () => { calls += 1; throw new Error('must not call upstream'); };
  try {
    const invalidBodies = [
      { direction: 'sideways', origin: 'TAS', destination: 'JED', departure_date: '2026-10-03' },
      { direction: 'outbound', origin: 'TAS', destination: 'JED', departure_date: '2026-02-31' },
      { direction: 'outbound', origin: 'TAS', destination: 'JED', departure_date: '2026-10-03', allow_self_transfer: 'false' },
    ];
    for (const body of invalidBodies) {
      const response = await worker.fetch(new Request('https://iumrah.app/api/package/flights/search', {
        method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body),
      }), { IGNAV_API_KEY: 'test-secret' });
      assert.equal(response.status, 400);
    }
    assert.equal(calls, 0);
  } finally {
    globalThis.fetch = originalFetch;
  }
});
