import fs from 'node:fs';

const [databaseID, zoneID] = process.argv.slice(2);
if (!databaseID || !zoneID) {
  console.error('Usage: node scripts/render-config.mjs <D1_DATABASE_ID> <ZONE_ID>');
  process.exit(1);
}

const input = fs.readFileSync('wrangler.template.jsonc', 'utf8');
const output = input
  .replaceAll('__D1_DATABASE_ID__', databaseID)
  .replaceAll('__ZONE_ID__', zoneID);

JSON.parse(output);
fs.writeFileSync('wrangler.generated.jsonc', output);
console.log('Generated wrangler.generated.jsonc');
