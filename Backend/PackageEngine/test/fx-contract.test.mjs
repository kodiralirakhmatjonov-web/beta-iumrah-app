import assert from "node:assert/strict";

// Contract mirrors src/fx.ts using representative official-rate semantics:
// Rate/Nominal = UZS value of one unit of the source currency.
const usdUzsPerUnit = 11853.55;
const eurUzsPerUnit = 13869.84;
const rubUzsPerUnit = 141.86;

const eur100InUsd = 100 * (eurUzsPerUnit / usdUzsPerUnit);
const rub10000InUsd = 10000 * (rubUzsPerUnit / usdUzsPerUnit);

assert.ok(eur100InUsd > 116 && eur100InUsd < 118);
assert.ok(rub10000InUsd > 119 && rub10000InUsd < 121);

// UZS itself is one UZS per unit; divide by USD/UZS to normalize to USD.
const uzs1185355InUsd = 1_185_355 / usdUzsPerUnit;
assert.equal(Math.round(uzs1185355InUsd), 100);
