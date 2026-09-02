import assert from 'node:assert/strict';
import fs from 'node:fs';

const index = fs.readFileSync(new URL('../src/index.ts', import.meta.url), 'utf8');
const generator = fs.readFileSync(new URL('../src/generator-components.ts', import.meta.url), 'utf8');
const wrangler = fs.readFileSync(new URL('../wrangler.template.jsonc', import.meta.url), 'utf8');
const packageJson = fs.readFileSync(new URL('../package.json', import.meta.url), 'utf8');
const cleanupMigration = fs.readFileSync(new URL('../migrations/0006_package_primary_hotels.sql', import.meta.url), 'utf8');

for (const banned of [
  '/api/package/flights/provider-search',
  '/api/package/flight-options/quote',
  '/api/package/search-sessions',
  'SEARCH_SESSIONS',
  'server-flight-bots',
  'providerFlightSearch',
]) {
  assert.ok(!index.includes(banned), `active Package Engine must not contain ${banned}`);
  assert.ok(!generator.includes(banned), `generator component surface must not contain ${banned}`);
  assert.ok(!wrangler.includes(banned), `Wrangler config must not contain ${banned}`);
}

assert.ok(!packageJson.includes('0006_package_primary_hotels.sql'), 'deploy scripts must not recreate legacy package hotel-rate schema');
assert.ok(!index.includes('/api/admin/package/primary-hotels'), 'legacy package_primary_hotels admin route must stay removed');
assert.ok(!generator.includes('package_primary_hotels'), 'Primary Hotel resolution must not depend on legacy package rates');
assert.match(cleanupMigration, /DROP TABLE IF EXISTS package_flight_cache_v1/);
assert.match(cleanupMigration, /DROP TABLE IF EXISTS package_quote_audits_v2/);
assert.match(cleanupMigration, /CREATE TABLE IF NOT EXISTS package_primary_hotels/);
assert.match(cleanupMigration, /DELETE FROM package_primary_hotels/);
assert.ok(!cleanupMigration.includes('INSERT INTO package_primary_hotels'), 'compatibility shell must stay empty');
assert.ok(!wrangler.includes('\"name\": \"SEARCH_SESSIONS\"'), 'retired Durable Object binding must be absent');
assert.match(wrangler, /v2-remove-package-search-session/);
assert.ok(wrangler.includes('\"deleted_classes\": [\"PackageSearchSession\"]'));
assert.match(index, /\/api\/package\/flights\/search/);
assert.match(index, /searchIgnavFlights/);

const ignav = fs.readFileSync(new URL('../src/ignav-flights.ts', import.meta.url), 'utf8');
const clientProvider = fs.readFileSync(new URL('../../../Sources/Services/IgnavFlightInventoryProvider.swift', import.meta.url), 'utf8');
assert.match(ignav, /IGNAV_BASE_URL}\/fares\/search/);
assert.match(ignav, /raw\.legs\.length < 1 \|\| raw\.legs\.length > 2/);
assert.match(ignav, /itinerary\.legs\.length !== request\.legs\.length/);
assert.ok(!ignav.includes('/fares/one-way'), 'Umrah flight search must not price outbound and return as separate one-way products');
assert.match(ignav, /String\(price\.status \|\| "unverified"\)/, 'current search-price hints must remain usable without final-price confirmation');
assert.match(ignav, /recordSuccessfulIgnavRequest/);
assert.match(ignav, /successful_requests = successful_requests \+ 1/);
assert.match(clientProvider, /allowSelfTransfer = true/);
assert.match(clientProvider, /minCarryOnBags = nil/);
assert.match(clientProvider, /airlinesInclude = nil/);

console.log('flight/server cleanup + complete Ignav inventory boundary contract OK');
