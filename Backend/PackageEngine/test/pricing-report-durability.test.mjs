import assert from 'node:assert/strict';
import fs from 'node:fs';

const root = new URL('../../../', import.meta.url);
const gateway = fs.readFileSync(new URL('Backend/PackageEngine/src/booking-gateway.ts', root), 'utf8');
const migration = fs.readFileSync(new URL('Backend/PackageEngine/migrations/0007_pending_package_pricing_reports.sql', root), 'utf8');
const bookingStore = fs.readFileSync(new URL('Sources/State/BookingStore.swift', root), 'utf8');
const flightModels = fs.readFileSync(new URL('Sources/Models/FlightModels.swift', root), 'utf8');
const bookingModels = fs.readFileSync(new URL('Sources/Models/BookingModels.swift', root), 'utf8');

assert.match(gateway, /authorizedBooking/);
assert.match(gateway, /persistPendingPricingReport/);
assert.match(gateway, /pending_package_pricing_reports/);
assert.match(gateway, /pending \? 202 : 200/);
assert.match(gateway, /PRICING_REPORT_PENDING_CONFLICT/);
assert.match(gateway, /PRICING_REPORT_ALREADY_COMMITTED/);
assert.match(gateway, /DELETE FROM pending_package_pricing_reports/);
assert.match(migration, /booking_id TEXT PRIMARY KEY/);
assert.match(migration, /pricing_snapshot_json TEXT NOT NULL/);

// Once the canonical booking response exists, the opaque proof is saved before
// account/Business synchronization. Therefore an app termination cannot erase the
// reconciliation job while the server hand-off is still pending.
const proofAssignment = bookingStore.indexOf('session.pendingGeneratorQuoteProof = quote.quoteProof');
const firstPersist = bookingStore.indexOf('upsert(session)', proofAssignment);
const firstCommit = bookingStore.indexOf('commitPricingReportWithRetry', firstPersist);
const accountLink = bookingStore.indexOf('accountService.linkBooking', proofAssignment);
assert.ok(proofAssignment >= 0 && firstPersist > proofAssignment);
assert.ok(firstCommit > firstPersist && accountLink > firstCommit);

// The shipping client has no schema capable of decoding confidential generator economics.
assert.doesNotMatch(flightModels, /GeneratorPricingSnapshot|supplierCostUsd|markupRate|estimatedProfitUsd/);
assert.doesNotMatch(bookingModels, /GeneratorPricingSnapshot|pricingSnapshot/);

console.log('durable post-booking pricing hand-off contract OK');
