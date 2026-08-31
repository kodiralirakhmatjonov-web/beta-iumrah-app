import type { Env } from "./env";
import { normalizeToUsd } from "./fx";
import type { ServerFlightCandidate, ServerFlightSegment, Travelers } from "./types";

export type InternalFlightCandidate = ServerFlightCandidate & { groupFareUsd: number };

export type FlightBotSearchArgs = {
  searchId: string;
  direction: "outbound" | "inbound";
  dateOffset: number;
  origin: string;
  destination: string;
  travelDate: string;
  travelers: Travelers;
};

type FareScope = "perPassenger" | "group";

type OfficialCarrierBot = {
  id: string;
  label: string;
  priority: number;
  airlineCodes: string[];
  startURL: string;
  fareScope: FareScope;
  directSearchURL?: (args: FlightBotSearchArgs) => string;
};

type BotFetchResult = {
  provider: OfficialCarrierBot;
  url: string;
  body: string;
  contentType: string;
};

const UZBEK_AIRPORTS = new Set(["TAS", "SKD", "BHK", "UGC", "NMA", "FEG", "NCU", "TMJ", "KSQ", "AZN", "NAV"]);
const SAUDI_AIRPORTS = new Set(["JED", "MED", "RUH", "DMM", "TIF"]);

const AIRLINES: Record<string, string> = {
  HY: "Uzbekistan Airways",
  HH: "Qanot Sharq",
  C6: "Centrum Air",
  "9S": "Air Samarkand",
  FK: "Fly Khiva",
  US: "Silk Avia",
  G9: "Air Arabia",
  FZ: "flydubai",
  TK: "Turkish Airlines",
  J9: "Jazeera Airways",
  SV: "Saudia",
  XY: "flynas",
  KC: "Air Astana",
  FS: "FlyArystan",
};

const BOTS: OfficialCarrierBot[] = [
  {
    id: "uzbekistanAirways",
    label: "Uzbekistan Airways",
    priority: 10,
    airlineCodes: ["HY"],
    startURL: "https://booking.uzairways.com/",
    fareScope: "perPassenger",
  },
  {
    id: "qanotSharq",
    label: "Qanot Sharq",
    priority: 20,
    airlineCodes: ["HH"],
    startURL: "https://booking.qanotsharq.com/websky_grs/",
    fareScope: "perPassenger",
    directSearchURL: (args) => {
      const p = new URLSearchParams({
        "origin-city-code[0]": args.origin,
        "destination-city-code[0]": args.destination,
        "date[0]": toDDMMYYYY(args.travelDate),
        segmentsCount: "1",
        adultsAmount: String(Math.max(1, args.travelers.adults)),
        childrenAmount: String(Math.max(0, args.travelers.children)),
        infantsWithoutSeatAmount: String(Math.max(0, args.travelers.infants)),
        infantsWithSeatAmount: "0",
        searchGroupId: "standard",
        lang: "en",
      });
      return `https://booking.qanotsharq.com/websky_grs/?${p.toString()}`;
    },
  },
  { id: "centrumAir", label: "Centrum Air", priority: 30, airlineCodes: ["C6"], startURL: "https://booking.centrum-air.com/ibe/C6/home/?language=en", fareScope: "perPassenger" },
  { id: "airSamarkand", label: "Air Samarkand", priority: 40, airlineCodes: ["9S"], startURL: "https://booking.airsamarkand.com/en/", fareScope: "perPassenger" },
  { id: "flyKhiva", label: "Fly Khiva", priority: 50, airlineCodes: ["FK"], startURL: "https://booking.flykhiva.uz/new/", fareScope: "perPassenger" },
  { id: "silkAvia", label: "Silk Avia", priority: 60, airlineCodes: ["US"], startURL: "https://pss.silk-avia.com/ibe/search?lang=en", fareScope: "perPassenger" },
  { id: "airArabia", label: "Air Arabia", priority: 70, airlineCodes: ["G9"], startURL: "https://www.airarabia.com/en", fareScope: "perPassenger" },
  { id: "flydubai", label: "flydubai", priority: 75, airlineCodes: ["FZ"], startURL: "https://www.flydubai.com/en/", fareScope: "perPassenger" },
  { id: "turkishAirlines", label: "Turkish Airlines", priority: 80, airlineCodes: ["TK"], startURL: "https://www.turkishairlines.com/", fareScope: "perPassenger" },
  { id: "jazeeraAirways", label: "Jazeera Airways", priority: 85, airlineCodes: ["J9"], startURL: "https://www.jazeeraairways.com/", fareScope: "perPassenger" },
  { id: "saudia", label: "Saudia", priority: 90, airlineCodes: ["SV"], startURL: "https://www.saudia.com/", fareScope: "perPassenger" },
  { id: "flynas", label: "flynas", priority: 95, airlineCodes: ["XY"], startURL: "https://www.flynas.com/en", fareScope: "perPassenger" },
  { id: "airAstana", label: "Air Astana", priority: 100, airlineCodes: ["KC"], startURL: "https://airastana.com/", fareScope: "perPassenger" },
  { id: "flyArystan", label: "FlyArystan", priority: 105, airlineCodes: ["FS"], startURL: "https://flyarystan.com/", fareScope: "perPassenger" },
];

function validAirport(value: string) { return /^[A-Z]{3}$/.test(value); }
function validDate(value: string) { return /^\d{4}-\d{2}-\d{2}$/.test(value) && Number.isFinite(Date.parse(`${value}T00:00:00Z`)); }
function toDDMMYYYY(day: string) { const [y, m, d] = day.split("-"); return `${d}.${m}.${y}`; }
function travelerCount(t: Travelers) { return Math.max(1, t.adults + t.children + t.infants); }

function orderedBots(origin: string, destination: string) {
  const fromUz = UZBEK_AIRPORTS.has(origin);
  const toUz = UZBEK_AIRPORTS.has(destination);
  const saudi = SAUDI_AIRPORTS.has(origin) || SAUDI_AIRPORTS.has(destination);
  const score = (bot: OfficialCarrierBot) => {
    if (fromUz || toUz) return bot.priority;
    if (saudi) {
      const regionalBoost = ["saudia", "flynas", "airArabia", "flydubai", "jazeeraAirways", "turkishAirlines"].indexOf(bot.id);
      return regionalBoost >= 0 ? regionalBoost : 100 + bot.priority;
    }
    return bot.priority;
  };
  return [...BOTS].sort((a, b) => score(a) - score(b));
}

function cacheKey(args: Omit<FlightBotSearchArgs, "searchId" | "direction" | "dateOffset">) {
  const t = args.travelers;
  return ["official-bots-v1", args.origin, args.destination, args.travelDate, `a${t.adults}`, `c${t.children}`, `i${t.infants}`].join("|");
}

async function getCached(env: Env, key: string): Promise<InternalFlightCandidate[] | null> {
  if (!env.HOTELS_DB) return null;
  try {
    const row = await env.HOTELS_DB.prepare(`SELECT result_json, expires_at FROM package_flight_cache_v1 WHERE cache_key=?1 LIMIT 1`)
      .bind(key).first<{ result_json: string; expires_at: string }>();
    if (!row || Date.parse(row.expires_at) <= Date.now()) return null;
    const parsed = JSON.parse(row.result_json);
    return Array.isArray(parsed) ? parsed as InternalFlightCandidate[] : null;
  } catch { return null; }
}

async function putCached(env: Env, key: string, candidates: InternalFlightCandidate[]) {
  if (!env.HOTELS_DB || candidates.length === 0) return;
  const now = new Date();
  const expires = new Date(now.getTime() + 10 * 60_000).toISOString();
  try {
    await env.HOTELS_DB.prepare(`INSERT INTO package_flight_cache_v1(cache_key,provider_id,result_json,expires_at,created_at,updated_at)
      VALUES(?1,'officialBots',?2,?3,?4,?4)
      ON CONFLICT(cache_key) DO UPDATE SET provider_id='officialBots',result_json=excluded.result_json,expires_at=excluded.expires_at,updated_at=excluded.updated_at`)
      .bind(key, JSON.stringify(candidates), expires, now.toISOString()).run();
  } catch {}
}

function renamespaceCached(candidates: InternalFlightCandidate[], args: FlightBotSearchArgs) {
  return candidates.map((candidate, index) => ({
    ...candidate,
    id: `${args.searchId}:${args.direction}:${args.dateOffset}:cache${index}:${candidate.providerId}:${candidate.flightNumber}`,
    direction: args.direction,
    dateOffset: args.dateOffset,
    travelDate: args.travelDate,
  }));
}

function decodeEntities(value: string) {
  const named: Record<string, string> = { amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " " };
  return value.replace(/&(#x?[0-9a-f]+|[a-z]+);/gi, (_, raw: string) => {
    const key = raw.toLowerCase();
    if (key.startsWith("#x")) return String.fromCodePoint(parseInt(key.slice(2), 16));
    if (key.startsWith("#")) return String.fromCodePoint(parseInt(key.slice(1), 10));
    return named[key] ?? `&${raw};`;
  });
}

function searchableText(raw: string) {
  return decodeEntities(raw)
    .replace(/<script\b[^>]*>/gi, " ")
    .replace(/<\/script>/gi, " ")
    .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/\\u002F/gi, "/")
    .replace(/\\u003A/gi, ":")
    .replace(/\\"/g, '"')
    .replace(/\s+/g, " ")
    .trim();
}

function moneyMatches(text: string) {
  const out: { amount: number; currency: string; index: number }[] = [];
  const patterns: Array<[RegExp, string]> = [
    [/(?:USD|US\$|\$)\s*([0-9][0-9\s,.]*)/gi, "USD"],
    [/([0-9][0-9\s,.]*)\s*(?:USD|US\$)/gi, "USD"],
    [/(?:UZS)\s*([0-9][0-9\s,.]*)/gi, "UZS"],
    [/([0-9][0-9\s,.]*)\s*(?:UZS|so['’]?m|сум)/gi, "UZS"],
    [/(?:SAR)\s*([0-9][0-9\s,.]*)/gi, "SAR"],
    [/([0-9][0-9\s,.]*)\s*SAR/gi, "SAR"],
    [/(?:AED)\s*([0-9][0-9\s,.]*)/gi, "AED"],
    [/([0-9][0-9\s,.]*)\s*AED/gi, "AED"],
    [/(?:EUR|€)\s*([0-9][0-9\s,.]*)/gi, "EUR"],
    [/(?:RUB|₽)\s*([0-9][0-9\s,.]*)/gi, "RUB"],
    [/(?:KZT)\s*([0-9][0-9\s,.]*)/gi, "KZT"],
    [/(?:TRY)\s*([0-9][0-9\s,.]*)/gi, "TRY"],
  ];
  for (const [regex, currency] of patterns) {
    let m: RegExpExecArray | null;
    while ((m = regex.exec(text)) && out.length < 40) {
      const normalized = m[1].replace(/\s/g, "").replace(/,(?=\d{1,2}$)/, ".").replace(/,/g, "");
      const amount = Number(normalized);
      if (Number.isFinite(amount) && amount > 0) out.push({ amount, currency, index: m.index });
    }
  }
  return out.sort((a, b) => a.index - b.index);
}

function times(text: string) {
  return [...text.matchAll(/\b(?:[01]?\d|2[0-3]):[0-5]\d\b/g)].map((m) => ({ value: m[0], index: m.index ?? 0 }));
}

function durationMinutes(text: string) {
  const en = text.match(/\b(\d{1,2})\s*(?:h|hr|hrs|hour|hours)\s*(?:(\d{1,2})\s*(?:m|min|mins|minute|minutes))?/i);
  if (en) return Number(en[1]) * 60 + Number(en[2] ?? 0);
  const ru = text.match(/\b(\d{1,2})\s*(?:ч|час|часа|часов)\s*(?:(\d{1,2})\s*(?:м|мин|минут))?/i);
  if (ru) return Number(ru[1]) * 60 + Number(ru[2] ?? 0);
  return 0;
}

function localISO(day: string, hhmm: string) {
  const normalized = hhmm.length === 4 ? `0${hhmm}` : hhmm;
  return `${day}T${normalized}:00`;
}

function knownFlightNumbers(text: string, allowedCodes: string[]) {
  const allowed = new Set(allowedCodes);
  const values: { code: string; number: string; index: number }[] = [];
  const regex = /\b([A-Z0-9]{2,3})[\s-]?(\d{1,4}[A-Z]?)\b/gi;
  let match: RegExpExecArray | null;
  while ((match = regex.exec(text)) && values.length < 30) {
    const code = match[1].toUpperCase();
    if (!allowed.has(code) || !AIRLINES[code]) continue;
    const number = `${code}${match[2].toUpperCase()}`;
    if (!/^[A-Z0-9]{2,3}\d{1,4}[A-Z]?$/.test(number)) continue;
    values.push({ code, number, index: match.index });
  }
  return values;
}

function routeEvidence(text: string, origin: string, destination: string) {
  const upper = text.toUpperCase();
  return new RegExp(`\\b${origin}\\b`).test(upper) && new RegExp(`\\b${destination}\\b`).test(upper);
}

function candidateWindows(text: string, bot: OfficialCarrierBot, args: FlightBotSearchArgs) {
  const flights = knownFlightNumbers(text, bot.airlineCodes);
  const windows: string[] = [];
  const seen = new Set<string>();
  for (const flight of flights) {
    const from = Math.max(0, flight.index - 1800);
    const to = Math.min(text.length, flight.index + 2800);
    const block = text.slice(from, to);
    if (!routeEvidence(block, args.origin, args.destination)) continue;
    const key = block.slice(0, 500);
    if (seen.has(key)) continue;
    seen.add(key);
    windows.push(block);
  }
  return windows;
}

function looksLikeChallenge(text: string) {
  return /(captcha|cloudflare ray id|verify you are human|human verification|access denied|bot detection|robot check)/i.test(text);
}

function formSearchRequest(html: string, baseURL: string, args: FlightBotSearchArgs): { url: string; init: RequestInit } | null {
  const forms = [...html.matchAll(/<form\b([^>]*)>([\s\S]*?)<\/form>/gi)].slice(0, 20);
  const originKeys = /(origin|from|departure.*(?:airport|city|station)|dep.*code)/i;
  const destinationKeys = /(destination|to|arrival.*(?:airport|city|station)|arr.*code)/i;
  const dateKeys = /(departure.*date|depart.*date|date\[0\]|flight.*date|^date$)/i;
  for (const form of forms) {
    const attrs = form[1];
    const body = form[2];
    if (!/(search|flight|route|booking|ibe|availability)/i.test(`${attrs} ${body}`)) continue;
    const fields = new URLSearchParams();
    let hasOrigin = false, hasDestination = false, hasDate = false;
    for (const input of body.matchAll(/<(?:input|select)\b([^>]*)>/gi)) {
      const a = input[1];
      const name = a.match(/\bname=["']?([^\s"'>]+)/i)?.[1];
      if (!name) continue;
      const value = a.match(/\bvalue=["']([^"']*)["']/i)?.[1] ?? "";
      if (/^(csrf|_csrf|token|authenticity|javax\.faces\.ViewState)/i.test(name) || /type=["']hidden/i.test(a)) fields.set(name, value);
      if (originKeys.test(name)) { fields.set(name, args.origin); hasOrigin = true; }
      else if (destinationKeys.test(name)) { fields.set(name, args.destination); hasDestination = true; }
      else if (dateKeys.test(name)) { fields.set(name, args.travelDate); hasDate = true; }
      else if (/adult/i.test(name)) fields.set(name, String(Math.max(1, args.travelers.adults)));
      else if (/child/i.test(name)) fields.set(name, String(Math.max(0, args.travelers.children)));
      else if (/infant/i.test(name)) fields.set(name, String(Math.max(0, args.travelers.infants)));
    }
    if (!hasOrigin || !hasDestination || !hasDate) continue;
    const action = attrs.match(/\baction=["']([^"']*)["']/i)?.[1] || baseURL;
    const method = (attrs.match(/\bmethod=["']?([^\s"'>]+)/i)?.[1] || "GET").toUpperCase();
    const target = new URL(action, baseURL);
    if (method === "GET") {
      fields.forEach((v, k) => target.searchParams.set(k, v));
      return { url: target.toString(), init: { method: "GET" } };
    }
    return { url: target.toString(), init: { method: "POST", headers: { "content-type": "application/x-www-form-urlencoded" }, body: fields.toString() } };
  }
  return null;
}

async function fetchText(url: string, init: RequestInit = {}): Promise<{ body: string; contentType: string; finalURL: string }> {
  const response = await fetch(url, {
    ...init,
    redirect: "follow",
    headers: {
      accept: "text/html,application/json;q=0.9,*/*;q=0.8",
      "accept-language": "en-US,en;q=0.9",
      "user-agent": "Mozilla/5.0 (compatible; iumrah-flight-bot/1.0; +https://iumrah.app)",
      ...(init.headers || {}),
    },
    signal: AbortSignal.timeout(12_000),
  });
  if (!response.ok) throw new Error(`HTTP_${response.status}`);
  const body = (await response.text()).slice(0, 900_000);
  return { body, contentType: response.headers.get("content-type") || "", finalURL: response.url || url };
}

async function fetchProvider(bot: OfficialCarrierBot, args: FlightBotSearchArgs): Promise<BotFetchResult[]> {
  const results: BotFetchResult[] = [];
  const firstURL = bot.directSearchURL ? bot.directSearchURL(args) : bot.startURL;
  const first = await fetchText(firstURL);
  results.push({ provider: bot, url: first.finalURL, body: first.body, contentType: first.contentType });
  if (bot.directSearchURL) return results;
  const next = formSearchRequest(first.body, first.finalURL, args);
  if (!next || next.url === first.finalURL) return results;
  try {
    const second = await fetchText(next.url, next.init);
    results.push({ provider: bot, url: second.finalURL, body: second.body, contentType: second.contentType });
  } catch {}
  return results;
}

export async function normalizeOfficialCarrierText(
  raw: string,
  bot: Pick<OfficialCarrierBot, "id" | "label" | "airlineCodes" | "fareScope">,
  args: FlightBotSearchArgs,
  env: Env,
): Promise<InternalFlightCandidate[]> {
  const text = searchableText(raw);
  if (!text || looksLikeChallenge(text)) return [];
  const windows = candidateWindows(text, bot as OfficialCarrierBot, args);
  const candidates: InternalFlightCandidate[] = [];
  const pax = travelerCount(args.travelers);

  for (let index = 0; index < windows.length && candidates.length < 6; index++) {
    const block = windows[index];
    const flights = knownFlightNumbers(block, bot.airlineCodes);
    if (flights.length !== 1) continue; // Strict v1: only direct flights with unambiguous segment identity.
    const ts = times(block);
    if (ts.length < 2) continue;
    const money = moneyMatches(block);
    if (!money.length) continue;
    const duration = durationMinutes(block);
    if (duration <= 0) continue; // Never invent duration from local clocks across time zones.
    const fare = money.find((m) => Math.abs(m.index - flights[0].index) < 2200) ?? money[0];
    let usd: number;
    try { usd = (await normalizeToUsd(fare.amount, fare.currency, env)).amountUsd; }
    catch { continue; }
    const groupFareUsd = bot.fareScope === "group" ? usd : usd * pax;
    if (!Number.isFinite(groupFareUsd) || groupFareUsd <= 0) continue;
    const departureAt = localISO(args.travelDate, ts[0].value);
    let arrivalDay = args.travelDate;
    const [dh, dm] = ts[0].value.split(":").map(Number);
    const [ah, am] = ts[1].value.split(":").map(Number);
    if (ah * 60 + am < dh * 60 + dm && duration > 360) {
      const d = new Date(`${args.travelDate}T00:00:00Z`); d.setUTCDate(d.getUTCDate() + 1); arrivalDay = d.toISOString().slice(0, 10);
    }
    const arrivalAt = localISO(arrivalDay, ts[1].value);
    const flight = flights[0];
    const segment: ServerFlightSegment = {
      id: `${args.searchId}:${bot.id}:${args.direction}:${args.dateOffset}:${flight.number}:s0`,
      airline: AIRLINES[flight.code] || bot.label,
      airlineCode: flight.code,
      flightNumber: flight.number,
      origin: args.origin,
      destination: args.destination,
      departureAt,
      arrivalAt,
      durationMinutes: duration,
      originTerminal: null,
      destinationTerminal: null,
      aircraft: null,
      operatingCarrier: null,
      cabin: null,
    };
    candidates.push({
      id: `${args.searchId}:${args.direction}:${args.dateOffset}:${bot.id}:${flight.number}:${index}`,
      providerId: bot.id,
      sourceLabel: bot.label,
      direction: args.direction,
      dateOffset: args.dateOffset,
      travelDate: args.travelDate,
      origin: args.origin,
      destination: args.destination,
      airline: segment.airline,
      airlineCode: segment.airlineCode,
      flightNumber: segment.flightNumber,
      departureAt,
      arrivalAt,
      durationMinutes: duration,
      stops: 0,
      currency: "USD",
      segments: [segment],
      groupFareUsd,
    });
  }
  const seen = new Set<string>();
  return candidates.filter((c) => seen.add(`${c.providerId}|${c.flightNumber}|${c.departureAt}|${c.groupFareUsd.toFixed(2)}`));
}

async function searchOneProvider(env: Env, bot: OfficialCarrierBot, args: FlightBotSearchArgs) {
  try {
    const payloads = await fetchProvider(bot, args);
    const all: InternalFlightCandidate[] = [];
    for (const payload of payloads) all.push(...await normalizeOfficialCarrierText(payload.body, bot, args, env));
    return all;
  } catch { return []; }
}

export async function searchOfficialCarrierBots(env: Env, args: FlightBotSearchArgs): Promise<{ candidates: InternalFlightCandidate[]; fromCache: boolean; attemptedProviders: number; successfulProviders: number }> {
  if (!validAirport(args.origin) || !validAirport(args.destination) || !validDate(args.travelDate)) throw new Error("INVALID_FLIGHT_SEARCH_ROUTE");
  const key = cacheKey(args);
  const cached = await getCached(env, key);
  if (cached?.length) return { candidates: renamespaceCached(cached, args), fromCache: true, attemptedProviders: 0, successfulProviders: 0 };

  const bots = orderedBots(args.origin, args.destination);
  let successfulProviders = 0;
  const all: InternalFlightCandidate[] = [];
  // Keep each Worker invocation under Cloudflare's six simultaneous outbound-connection ceiling.
  for (let offset = 0; offset < bots.length && all.length < 10; offset += 4) {
    const batch = bots.slice(offset, offset + 4);
    const results = await Promise.all(batch.map((bot) => searchOneProvider(env, bot, args)));
    for (const values of results) {
      if (values.length) successfulProviders += 1;
      all.push(...values);
    }
    if (all.length >= 4) break; // Progressive session can move on once a useful first pool exists.
  }
  const seen = new Set<string>();
  const deduped = all.filter((c) => seen.add(`${c.flightNumber}|${c.departureAt}|${c.arrivalAt}|${Math.round(c.groupFareUsd)}`)).slice(0, 10);
  await putCached(env, key, deduped);
  return { candidates: deduped, fromCache: false, attemptedProviders: bots.length, successfulProviders };
}

export function officialCarrierBotCount() { return BOTS.length; }
