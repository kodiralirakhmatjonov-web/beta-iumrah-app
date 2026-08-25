import assert from "node:assert/strict";

// Contract copied from the legacy iumrah-web estimate catalog. This is only
// the technical beta fallback until a manually maintained Primary Hotel rate exists.
const base = { 1: 44, 2: 62, 3: 82, 4: 112, 5: 175 };
const monthFactor = (month) => [12,1,2,3].includes(month) ? 1.12 : [6,7,8].includes(month) ? 0.94 : 1;

assert.equal(base[4], 112);
assert.equal(Math.round(base[5] * 0.86 * 100) / 100, 150.5);
assert.equal(Math.round(base[3] * monthFactor(1) * 100) / 100, 91.84);
assert.equal(Math.round(base[3] * monthFactor(7) * 100) / 100, 77.08);
