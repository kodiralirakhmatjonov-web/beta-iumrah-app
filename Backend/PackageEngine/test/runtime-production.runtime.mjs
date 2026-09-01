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
