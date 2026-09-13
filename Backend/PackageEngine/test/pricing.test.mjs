import assert from 'node:assert/strict';
import fs from 'node:fs';

const index = fs.readFileSync(new URL('../src/index.ts', import.meta.url), 'utf8');
const packageSearch = fs.readFileSync(new URL('../src/package-search.ts', import.meta.url), 'utf8');
const pricing = fs.readFileSync(new URL('../src/pricing.ts', import.meta.url), 'utf8');
const remote = fs.readFileSync(new URL('../../../Sources/Services/RemotePackageEngineClient.swift', import.meta.url), 'utf8');
const localPricing = fs.readFileSync(new URL('../../../Sources/Services/LocalPackagePricingEngine.swift', import.meta.url), 'utf8');

assert.match(index, /generatePackageQuote/);
assert.match(index, /\/api\/package\/quote/);
assert.match(packageSearch, /calculatePackageQuote/);
assert.match(packageSearch, /sealPricingSnapshot/);
assert.match(pricing, /server-expedia-package-v9/);
assert.match(remote, /"\/api\/package\/quote"/);
assert.match(remote, /quoteProof/);
assert.doesNotMatch(localPricing, /enum LocalPackagePricingEngine/);
assert.doesNotMatch(localPricing, /static func calculate\(/);
console.log('server pricing ownership contract OK');
