import fs from 'node:fs';

const [hotelDatabaseID, zoneID] = process.argv.slice(2);
const accountID = process.env.CLOUDFLARE_ACCOUNT_ID;
const apiToken = process.env.CLOUDFLARE_API_TOKEN;

if (!hotelDatabaseID || !zoneID || !accountID || !apiToken) {
  console.error('Usage: node scripts/render-config.mjs <HOTEL_D1_DATABASE_ID> <ZONE_ID> with CLOUDFLARE_ACCOUNT_ID and CLOUDFLARE_API_TOKEN');
  process.exit(1);
}

const headers = {
  Authorization: `Bearer ${apiToken}`,
  'Content-Type': 'application/json',
};

async function findBookingDatabase() {
  const listResponse = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${accountID}/d1/database?per_page=100`,
    { headers },
  );
  if (!listResponse.ok) throw new Error(`Unable to list D1 databases (${listResponse.status})`);
  const listPayload = await listResponse.json();
  const databases = Array.isArray(listPayload.result) ? listPayload.result : [];

  // Prefer likely iumrah databases, but verify by inspecting sqlite_master. We never
  // create a new DB or guess an ID: the binding is only generated after finding the
  // existing database that actually contains the bookings table.
  databases.sort((a, b) => {
    const score = (value) => /iumrah/i.test(String(value?.name ?? '')) ? 0 : 1;
    return score(a) - score(b);
  });

  for (const database of databases) {
    const id = database.uuid ?? database.id;
    if (!id) continue;
    try {
      const queryResponse = await fetch(
        `https://api.cloudflare.com/client/v4/accounts/${accountID}/d1/database/${id}/query`,
        {
          method: 'POST',
          headers,
          body: JSON.stringify({
            sql: "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'bookings' LIMIT 1",
          }),
        },
      );
      if (!queryResponse.ok) continue;
      const payload = await queryResponse.json();
      const batches = Array.isArray(payload.result) ? payload.result : [];
      const found = batches.some((batch) => Array.isArray(batch?.results) && batch.results.some((row) => row?.name === 'bookings'));
      if (found) {
        return { id: String(id), name: String(database.name ?? 'iumrah-bookings') };
      }
    } catch {
      // Keep scanning other existing D1 databases.
    }
  }
  throw new Error('No existing D1 database containing the bookings table was found. Refusing to create or guess a booking database.');
}

const bookingDatabase = await findBookingDatabase();
console.log(`Using existing bookings D1: ${bookingDatabase.name} (${bookingDatabase.id})`);

const input = fs.readFileSync('wrangler.template.jsonc', 'utf8');
const output = input
  .replaceAll('__D1_DATABASE_ID__', hotelDatabaseID)
  .replaceAll('__BOOKING_D1_DATABASE_ID__', bookingDatabase.id)
  .replaceAll('__BOOKING_D1_DATABASE_NAME__', bookingDatabase.name.replaceAll('"', '\\"'))
  .replaceAll('__ZONE_ID__', zoneID);

JSON.parse(output);
fs.writeFileSync('wrangler.generated.jsonc', output);
console.log('Generated wrangler.generated.jsonc with HOTELS_DB + BOOKINGS_DB bindings');
