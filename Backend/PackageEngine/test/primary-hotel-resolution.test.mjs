import assert from 'node:assert/strict';
import fs from 'node:fs';

const source = fs.readFileSync(new URL('../src/generator-components.ts', import.meta.url), 'utf8');
assert.match(source, /FROM primary_hotels p/);
assert.match(source, /p\.star_category = \?2/);
assert.match(source, /ORDER BY p\.position ASC/);
assert.match(source, /pricingMode: "liveVerificationRequired"/);
assert.ok(!source.includes('package_primary_hotels'), 'Primary Hotel resolver must not depend on package_primary_hotels');
assert.ok(!source.includes('base_price_usd'), 'Primary Hotel selection must not return a synthetic/configured price');
console.log('primary_hotels recommendation contract OK');
