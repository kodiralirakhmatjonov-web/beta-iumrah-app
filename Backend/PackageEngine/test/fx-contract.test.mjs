import assert from 'node:assert/strict';
import fs from 'node:fs';

const index = fs.readFileSync(new URL('../src/index.ts', import.meta.url), 'utf8');
const pricing = fs.readFileSync(new URL('../src/pricing.ts', import.meta.url), 'utf8');
const hotelCosts = fs.readFileSync(new URL('../src/hotel-costs.ts', import.meta.url), 'utf8');
const quoteAudit = fs.readFileSync(new URL('../src/quote-audit.ts', import.meta.url), 'utf8');
const localPricing = fs.readFileSync(new URL('../../../Sources/Services/LocalPackagePricingEngine.swift', import.meta.url), 'utf8');

assert.match(index, /\/api\/package\/quote/);
assert.match(pricing, /export function calculatePackageQuote/);
assert.match(hotelCosts, /export async function resolveServerHotelPricing/);
assert.match(quoteAudit, /AES-GCM/);
assert.doesNotMatch(localPricing, /static func calculate\(/);
assert.doesNotMatch(localPricing, /0\.25|0\.35|paymentFeeRate|supplierCostUsd/);
console.log('server-owned pricing modules active; client pricing formula removed');
