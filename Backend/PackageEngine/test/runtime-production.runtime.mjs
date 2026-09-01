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

function hotelDb({ curated = null, fallback = null, publishedHotel = null, sources = [] } = {}) {
  return {
    prepare(sql) {
      if (sql.includes('FROM primary_hotels p')) return statementFor(async () => curated);
      if (sql.includes('FROM hotels') && sql.includes('ORDER BY rating DESC')) return statementFor(async () => fallback);
      if (sql.includes("SELECT id FROM hotels WHERE id = ?")) return statementFor(async (_kind, values) => values[0] === publishedHotel?.id ? publishedHotel : null);
      if (sql.includes('FROM hotel_sources')) return statementFor(async () => ({ results: sources }));
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

function searchBody(overrides = {}) {
  return {
    legs: [
      { origin: 'TAS', destination: 'JED', departure_date: '2026-10-03', max_stops: 1, departure_time_range: { earliest_hour: 6, latest_hour: 17 } },
      { origin: 'MED', destination: 'TAS', departure_date: '2026-10-10', max_stops: 1, departure_time_range: { earliest_hour: 6, latest_hour: 23 } },
    ],
    adults: 2,
    children: 1,
    infants_on_lap: 1,
    cabin_class: 'economy',
    min_carry_on_bags: 1,
    min_checked_bags: 1,
    max_price: 1500,
    airlines_include: ['HY'],
    allow_self_transfer: false,
    ...overrides,
  };
}

function segment({ carrier, number, origin, destination, departureLocal, departureZone, departureUTC, arrivalLocal, arrivalZone, arrivalUTC, duration }) {
  return {
    marketing_carrier_code: carrier,
    flight_number: number,
    operating_carrier_name: carrier === 'HY' ? 'Uzbekistan Airways' : 'flydubai',
    departure_airport: origin,
    departure_time_local: departureLocal,
    departure_timezone: departureZone,
    departure_time_utc: departureUTC,
    arrival_airport: destination,
    arrival_time_local: arrivalLocal,
    arrival_timezone: arrivalZone,
    arrival_time_utc: arrivalUTC,
    duration_minutes: duration,
    aircraft: 'Airbus A321neo',
  };
}

function validIgnavItinerary({ id = '5e4fcd2f1dc340649eb19f6ee2afb57a', amount = 612, status = 'verified', firstDepartureUTC = '2026-10-03T03:10:00Z' } = {}) {
  return {
    price: { amount, currency: 'USD', status },
    legs: [
      {
        carrier: 'Uzbekistan Airways',
        duration_minutes: 410,
        segments: [segment({ carrier: 'HY', number: '337', origin: 'TAS', destination: 'JED', departureLocal: '2026-10-03T08:10:00', departureZone: 'Asia/Tashkent', departureUTC: firstDepartureUTC, arrivalLocal: '2026-10-03T11:00:00', arrivalZone: 'Asia/Riyadh', arrivalUTC: '2026-10-03T08:00:00Z', duration: 410 })],
      },
      {
        carrier: 'flydubai',
        duration_minutes: 555,
        segments: [segment({ carrier: 'FZ', number: '1942', origin: 'MED', destination: 'TAS', departureLocal: '2026-10-10T10:20:00', departureZone: 'Asia/Riyadh', departureUTC: '2026-10-10T07:20:00Z', arrivalLocal: '2026-10-10T18:35:00', arrivalZone: 'Asia/Tashkent', arrivalUTC: '2026-10-10T13:35:00Z', duration: 555 })],
      },
    ],
    cabin_class: 'economy',
    bags: { carry_on: 1, checked: 1 },
    requires_self_transfer: false,
    ignav_id: id,
  };
}

function validIgnavResponse(itineraries = [validIgnavItinerary()]) {
  return {
    legs: [
      { origin: 'TAS', destination: 'JED', departure_date: '2026-10-03' },
      { origin: 'MED', destination: 'TAS', departure_date: '2026-10-10' },
    ],
    itineraries,
  };
}

test('hotel pricing-source endpoint exposes Business-maintained provider identity for a published hotel', async () => {
  const env = {
    HOTELS_DB: hotelDb({
      publishedHotel: { id: 'hotel-1' },
      sources: [
        { provider: 'booking.com', source_url: 'https://www.booking.com/hotel/sa/example.html', provider_hotel_id: '12345', canonical_url: 'https://www.booking.com/hotel/sa/example.html' },
        { provider: 'expedia', source_url: 'https://www.expedia.com/Hotel-Information-Example.h123.Hotel-Information', provider_hotel_id: '123', canonical_url: null },
      ],
    }),
  };
  const response = await worker.fetch(new Request('https://iumrah.app/api/package/hotel/hotel-1/pricing-sources'), env);
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.ok, true);
  assert.equal(body.sources.length, 2);
  assert.deepEqual(body.sources.map((x) => x.provider), ['booking', 'expedia']);
  assert.equal(body.sources[0].providerHotelID, '12345');
});

test('Ignav flight route fails closed when Worker secret is missing', async () => {
  const response = await worker.fetch(new Request('https://iumrah.app/api/package/flights/search', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(searchBody()),
  }), {});
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error, 'FLIGHT_PROVIDER_NOT_CONFIGURED');
});

test('Ignav proxy uses one flexible open-jaw request and returns multiple complete itinerary fares', async () => {
  const originalFetch = globalThis.fetch;
  let captured;
  globalThis.fetch = async (url, init) => {
    captured = { url: String(url), headers: init.headers, body: JSON.parse(init.body) };
    return new Response(JSON.stringify(validIgnavResponse([
      validIgnavItinerary(),
      validIgnavItinerary({ id: '6e4fcd2f1dc340649eb19f6ee2afb57b', amount: 655 }),
    ])), { status: 200, headers: { 'content-type': 'application/json' } });
  };
  try {
    const response = await worker.fetch(new Request('https://iumrah.app/api/package/flights/search', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(searchBody()),
    }), { IGNAV_API_KEY: 'test-secret' });

    assert.equal(response.status, 200);
    const body = await response.json();
    assert.equal(body.ok, true);
    assert.equal(body.source, 'ignav');
    assert.equal(body.itineraries.length, 2);
    assert.equal(body.itineraries[0].legs.length, 2);
    assert.equal(body.itineraries[0].legs[0].flight_number, 'HY 337');
    assert.equal(body.itineraries[0].legs[1].flight_number, 'FZ 1942');
    assert.equal(body.itineraries[0].fare_scope, 'total_party');
    assert.equal(body.itineraries[0].price.amount, 612);
    assert.equal(body.itineraries[0].legs[0].segments[0].departure_time_utc, '2026-10-03T03:10:00Z');
    assert.equal(captured.url, 'https://ignav.com/api/fares/search');
    assert.equal(captured.headers['x-api-key'], 'test-secret');
    assert.equal(captured.body.market, 'US');
    assert.equal(captured.body.adults, 2);
    assert.equal(captured.body.children, 1);
    assert.equal(captured.body.infants_on_lap, 1);
    assert.equal(captured.body.legs.length, 2);
    assert.equal(captured.body.legs[0].max_stops, 1);
    assert.equal(captured.body.legs[1].origin, 'MED');
    assert.deepEqual(captured.body.airlines_include, ['HY']);
    assert.equal(captured.body.allow_self_transfer, false);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('Ignav proxy keeps an unverified current fare as an indicative price but rejects malformed itinerary timestamps', async () => {
  const originalFetch = globalThis.fetch;
  let call = 0;
  globalThis.fetch = async () => {
    call += 1;
    const itinerary = call === 1
      ? validIgnavItinerary({ status: 'unverified' })
      : validIgnavItinerary({ firstDepartureUTC: null });
    return new Response(JSON.stringify(validIgnavResponse([itinerary])), { status: 200, headers: { 'content-type': 'application/json' } });
  };
  try {
    const indicative = await worker.fetch(new Request('https://iumrah.app/api/package/flights/search', {
      method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(searchBody()),
    }), { IGNAV_API_KEY: 'test-secret' });
    assert.equal(indicative.status, 200);
    const indicativeBody = await indicative.json();
    assert.equal(indicativeBody.itineraries.length, 1);
    assert.equal(indicativeBody.itineraries[0].price.status, 'unverified');

    const malformed = await worker.fetch(new Request('https://iumrah.app/api/package/flights/search', {
      method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(searchBody()),
    }), { IGNAV_API_KEY: 'test-secret' });
    assert.equal(malformed.status, 200);
    assert.deepEqual((await malformed.json()).itineraries, []);
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
      method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(searchBody()),
    }), { IGNAV_API_KEY: 'bad-secret' });
    assert.equal(response.status, 502);
    assert.equal(calls, 1);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('Ignav proxy rejects malformed two-leg requests before upstream call', async () => {
  const originalFetch = globalThis.fetch;
  let calls = 0;
  globalThis.fetch = async () => { calls += 1; throw new Error('must not call upstream'); };
  try {
    const invalidBodies = [
      { ...searchBody(), legs: [{ origin: 'TAS', destination: 'JED', departure_date: '2026-10-03' }] },
      { ...searchBody(), legs: [{ origin: 'TAS', destination: 'JED', departure_date: '2026-02-31' }, { origin: 'MED', destination: 'TAS', departure_date: '2026-10-10' }] },
      { ...searchBody(), allow_self_transfer: 'false' },
      { ...searchBody(), legs: [{ origin: 'TAS', destination: 'JED', departure_date: '2026-10-10' }, { origin: 'MED', destination: 'TAS', departure_date: '2026-10-03' }] },
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
