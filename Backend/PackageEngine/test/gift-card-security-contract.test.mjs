import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const bookingControl = fs.readFileSync(new URL('../src/booking-control.ts', import.meta.url), 'utf8');
const accountSecurity = fs.readFileSync(new URL('../src/client-account-security.ts', import.meta.url), 'utf8');
const indexSource = fs.readFileSync(new URL('../src/index.ts', import.meta.url), 'utf8');
const migration = fs.readFileSync(new URL('../migrations/0006_package_primary_hotels.sql', import.meta.url), 'utf8');

const betaDesign = fs.readFileSync(new URL('../../../Sources/Core/DesignSystem.swift', import.meta.url), 'utf8');
const kycView = fs.readFileSync(new URL('../../../Sources/Views/Booking/IumrahSecurityConfirmationView.swift', import.meta.url), 'utf8');

test('Gift Card redemption requires a Business-confirmed identity', () => {
  assert.match(bookingControl, /identity\.status !== "confirmed"/);
  assert.match(bookingControl, /IDENTITY_CONFIRMATION_REQUIRED/);
  assert.match(migration, /business_manual_passport_review/);
});

test('PackageEngine cannot self-confirm KYC', () => {
  assert.doesNotMatch(indexSource, /identity-confirmation/);
  assert.doesNotMatch(bookingControl, /passport_self_confirmation/);
});

test('Gift Card anti-fraud blocks prior paid identity but not repeat KYC itself', () => {
  assert.match(bookingControl, /priorPaidIdentityBooking/);
  assert.match(bookingControl, /FRIENDS_NEW_CUSTOMER_ONLY/);
  assert.match(bookingControl, /BOOKING_CONFIRMED/);
  assert.match(bookingControl, /COMPLETED/);
});

test('Gift Card benefit is $100 through $2,000 and $200 only above $2,000', () => {
  assert.match(bookingControl, /return totalUsd > 2000 \? 200 : 100/);
});

test('new Gift Cards use IUMG codes while legacy IUMF codes remain redeemable', () => {
  assert.match(accountSecurity, /return `IUMG-\$\{value\}`/);
  assert.match(bookingControl, /\^IUM\[FG\]-\[A-Z2-9\]\{9\}\$/);
});

test('referrer credit is earned only after a paid booking and reversed on cancellation', () => {
  assert.match(accountSecurity, /reward_status='pending'/);
  assert.match(accountSecurity, /friend_paid/);
  assert.match(accountSecurity, /friend_cancelled_reversal/);
  assert.match(accountSecurity, /status !== "CANCELLED"/);
});


test('new iOS controls use native interactive Liquid Glass without Material emulation', () => {
  assert.match(betaDesign, /glassEffect\(\.regular\.interactive\(\), in: shape\)/);
  assert.doesNotMatch(betaDesign, /ultraThinMaterial/);
  assert.doesNotMatch(kycView, /ultraThinMaterial/);
});
