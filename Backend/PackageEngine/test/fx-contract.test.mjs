import assert from 'node:assert/strict';
import fs from 'node:fs';

for (const file of ['fx.ts', 'hotel-costs.ts', 'hotel-fallback.ts', 'pricing.ts', 'quote-audit.ts']) {
  const source = fs.readFileSync(new URL(`../src/${file}`, import.meta.url), 'utf8');
  assert.equal(source, '', `${file} must remain empty after cleanup`);
}
console.log('legacy server pricing modules removed');
