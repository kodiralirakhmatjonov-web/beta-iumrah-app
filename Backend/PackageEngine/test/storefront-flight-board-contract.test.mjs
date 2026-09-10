import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

const storefront = fs.readFileSync(new URL("../src/storefront.ts", import.meta.url), "utf8");
const index = fs.readFileSync(new URL("../src/index.ts", import.meta.url), "utf8");
const wrangler = fs.readFileSync(new URL("../wrangler.template.jsonc", import.meta.url), "utf8");

test("storefront package baseline uses only staff-published direct Umrah inventory", () => {
  assert.match(storefront, /published = 1/);
  assert.match(storefront, /outbound\.destination === "MED"/);
  assert.match(storefront, /option\.outbound\.origin === "JED"/);
  assert.match(storefront, /option\.outbound\.destination === origin/);
  assert.match(storefront, /combined_published_one_way/);
  assert.match(storefront, /published_open_jaw/);
});


test("storefront flight catalogue returns all future published Umrah routes while baseline stays origin-specific", () => {
  const boardBlock = storefront.slice(
    storefront.indexOf("export async function publicStorefrontFlightBoard"),
    storefront.indexOf("export function appleAppSiteAssociation"),
  );
  assert.match(boardBlock, /inbound_origin IS NULL/);
  assert.match(boardBlock, /outbound_destination IN \('MED','JED'\) OR outbound_origin IN \('MED','JED'\)/);
  assert.match(boardBlock, /inbound_origin IS NOT NULL/);
  assert.match(boardBlock, /LIMIT 300/);
  assert.match(boardBlock, /chooseBaseline\(options, origin\)/);
  assert.doesNotMatch(boardBlock, /outbound_origin = \? AND outbound_destination IN/);
});

test("public storefront and universal-link routes are wired", () => {
  assert.match(index, /\/api\/package\/storefront\/flights/);
  assert.match(index, /apple-app-site-association/);
  assert.match(index, /hotelWebFallback/);
  assert.match(wrangler, /apple-app-site-association/);
  assert.match(wrangler, /iumrah\.app\/hotel\/\*/);
  assert.match(wrangler, /iumrah\.app\/h\/\*/);
  assert.match(storefront, /supplier identifiers/);
  assert.match(storefront, /2DQ678JTNG\.com\.iumrah\.beta/);
  assert.match(storefront, /iumrahapp:\/\/hotel\//);
  assert.match(storefront, /max-age=300/);
  assert.doesNotMatch(storefront, /<div class="id">Hotel:/);
});
