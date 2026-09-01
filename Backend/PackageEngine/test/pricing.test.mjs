import assert from 'node:assert/strict';
import fs from 'node:fs';

const index = fs.readFileSync(new URL('../src/index.ts', import.meta.url), 'utf8');
const localPricing = fs.readFileSync(new URL('../../../Sources/Services/LocalPackagePricingEngine.swift', import.meta.url), 'utf8');

assert.ok(!index.includes('calculatePackageQuote'), 'Package Engine must not calculate consumer final package pricing');
assert.ok(!index.includes('/api/package/quote'), 'server package quote route must remain removed');
assert.match(localPricing, /enum LocalPackagePricingEngine/);
assert.match(localPricing, /static func calculate\(/);
console.log('local pricing ownership contract OK');
