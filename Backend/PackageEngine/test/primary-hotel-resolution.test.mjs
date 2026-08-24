import assert from "node:assert/strict";

// Contract-level ranking cases mirrored from the SQL ORDER BY rules.
const tiers = { economy: 1, standard: 2, comfort: 3, luxury: 4 };
function rank(row, requestedTier, requestedStars) {
  const bucket = row.tier === requestedTier && row.stars === requestedStars
    ? 0
    : row.tier === requestedTier
      ? 1
      : row.stars === requestedStars
        ? 2
        : 3;
  return [bucket, Math.abs(row.stars - requestedStars), Math.abs(tiers[row.tier] - tiers[requestedTier])];
}
function compare(a, b) {
  for (let i = 0; i < a.length; i += 1) {
    if (a[i] !== b[i]) return a[i] - b[i];
  }
  return 0;
}
function resolve(rows, tier, stars) {
  return [...rows].sort((a, b) => compare(rank(a, tier, stars), rank(b, tier, stars)))[0];
}

const rows = [
  { tier: "economy", stars: 3, id: "E3" },
  { tier: "standard", stars: 5, id: "S5" },
  { tier: "comfort", stars: 4, id: "C4" },
];

assert.equal(resolve(rows, "standard", 4).id, "S5", "same tier should win before same stars from another tier");
assert.equal(resolve(rows, "luxury", 4).id, "C4", "same stars should be used when requested tier is absent");
assert.equal(resolve(rows, "economy", 3).id, "E3", "exact match must always win");
console.log("primary hotel fallback ranking contract OK");
