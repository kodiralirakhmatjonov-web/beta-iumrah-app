import assert from 'node:assert/strict';
import fs from 'node:fs';

const index = fs.readFileSync(new URL('../src/index.ts', import.meta.url), 'utf8');
const generator = fs.readFileSync(new URL('../src/generator-components.ts', import.meta.url), 'utf8');
assert.ok(!index.includes('/api/package/hotel-component-price'));
assert.ok(!generator.includes('configuredHotelComponent'));
assert.ok(!generator.includes('base_price_usd'));
console.log('legacy configured hotel-rate fallback removed');
