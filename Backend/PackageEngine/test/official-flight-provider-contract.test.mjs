import assert from "node:assert/strict";
import fs from "node:fs";

const source = fs.readFileSync(new URL("../src/flight-options.ts", import.meta.url), "utf8");
const match = source.match(/const ALLOWED_PROVIDER_IDS = new Set\(\[([\s\S]*?)\]\);/);
assert.ok(match, "ALLOWED_PROVIDER_IDS must remain explicit");
const providers = [...match[1].matchAll(/"([A-Za-z0-9]+)"/g)].map((item) => item[1]);

for (const required of [
  "uzbekistanAirways",
  "qanotSharq",
  "centrumAir",
  "airSamarkand",
]) {
  assert.ok(providers.includes(required), `missing official Uzbek carrier provider: ${required}`);
}

assert.ok(!providers.includes("googleFlights"), "Google Flights must never enter package pricing");
assert.ok(!providers.includes("skyscanner"), "Skyscanner must never enter package pricing");

console.log("official flight provider contract OK");

for (const future of ["flyKhiva", "silkAvia", "flynas", "saudia", "turkishAirlines", "airArabia", "jazeeraAirways", "flydubai", "airAstana", "flyArystan"]) {
  assert.ok(!providers.includes(future), `uncertified provider must not enter production pricing boundary: ${future}`);
}
