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

type ServerMode = "uzbekistanForm" | "deviceOnly";

type OfficialCarrierBot = {
  id: string;
  label: string;
  priority: number;
  airlineCodes: string[];
  officialHosts: string[];
  startURL: string;
  fareScope: FareScope;
  serverMode: ServerMode;
};

type BotFetchResult = {
  provider: OfficialCarrierBot;
  url: string;
  body: string;
  contentType: string;
};

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
    officialHosts: ["booking.uzairways.com"],
    startURL: "https://booking.uzairways.com/",
    fareScope: "perPassenger",
    serverMode: "uzbekistanForm",
  },
  {
    id: "qanotSharq",
    label: "Qanot Sharq",
    priority: 20,
    airlineCodes: ["HH"],
    officialHosts: ["booking.qanotsharq.com"],
    startURL: "https://booking.qanotsharq.com/websky_grs/",
    fareScope: "perPassenger",
    serverMode: "deviceOnly",
  },
  {
    id: "centrumAir",
    label: "Centrum Air",
    priority: 30,
    airlineCodes: ["C6"],
    officialHosts: ["booking.centrum-air.com"],
    startURL: "https://booking.centrum-air.com/ibe/C6/home/?language=en",
    fareScope: "perPassenger",
    serverMode: "deviceOnly",
  },
  {
    id: "airSamarkand",
    label: "Air Samarkand",
    priority: 40,
    airlineCodes: ["9S"],
    officialHosts: ["booking.airsamarkand.com"],
    startURL: "https://booking.airsamarkand.com/en/",
    fareScope: "perPassenger",
    serverMode: "deviceOnly",
  },
];

function validAirport(value: string) { return /^[A-Z]{3}$/.test(value); }
function validDate(value: string) { return /^\d{4}-\d{2}-\d{2}$/.test(value) && Number.isFinite(Date.parse(`${value}T00:00:00Z`)); }
function travelerCount(t: Travelers) { return Math.max(1, t.adults + t.children + t.infants); }

function orderedBots(_origin: string, _destination: string) {
  return [...BOTS].filter((bot) => bot.serverMode !== "deviceOnly").sort((a, b) => a.priority - b.priority);
}

function cacheKey(args: Omit<FlightBotSearchArgs, "searchId" | "direction" | "dateOffset">) {
  const t = args.travelers;
  return ["official-bots-v2-specialized", args.origin, args.destination, args.travelDate, `a${t.adults}`, `c${t.children}`, `i${t.infants}`].join("|");
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

async function putCached(env: Env, key: string, candidates: InternalFlightCandidate[], providerId = "officialBots") {
  if (!env.HOTELS_DB || candidates.length === 0) return;
  const now = new Date();
  const expires = new Date(now.getTime() + 10 * 60_000).toISOString();
  try {
    await env.HOTELS_DB.prepare(`INSERT INTO package_flight_cache_v1(cache_key,provider_id,result_json,expires_at,created_at,updated_at)
      VALUES(?1,?2,?3,?4,?5,?5)
      ON CONFLICT(cache_key) DO UPDATE SET provider_id=excluded.provider_id,result_json=excluded.result_json,expires_at=excluded.expires_at,updated_at=excluded.updated_at`)
      .bind(key, providerId, JSON.stringify(candidates), expires, now.toISOString()).run();
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

function normalizeMoneyToken(raw: string) {
  const compact = raw.replace(/[\s\u00a0\u202f]/g, "");
  if (!/^\d[\d.,]*$/.test(compact)) return NaN;
  const lastDot = compact.lastIndexOf(".");
  const lastComma = compact.lastIndexOf(",");
  const separatorIndex = Math.max(lastDot, lastComma);
  if (separatorIndex < 0) return Number(compact);

  const trailingDigits = compact.length - separatorIndex - 1;
  // A final separator followed by one/two digits is a decimal mark. Everything
  // before it is grouping. Otherwise all separators are treated as grouping.
  if (trailingDigits >= 1 && trailingDigits <= 2) {
    const integerPart = compact.slice(0, separatorIndex).replace(/[.,]/g, "");
    const decimalPart = compact.slice(separatorIndex + 1).replace(/[.,]/g, "");
    return Number(`${integerPart}.${decimalPart}`);
  }
  return Number(compact.replace(/[.,]/g, ""));
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
      const amount = normalizeMoneyToken(m[1]);
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
  const allowed = [...new Set(allowedCodes.map((code) => code.toUpperCase()))]
    .filter((code) => /^[A-Z0-9]{2}$/.test(code) && AIRLINES[code]);
  if (!allowed.length) return [];
  const escaped = allowed.map((code) => code.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("|");
  const values: { code: string; number: string; index: number }[] = [];
  // The carrier code is supplied by the provider adapter, never inferred from a
  // generic 2–3 character token. This correctly parses both `HY335` and `HY 335`
  // and prevents dates/currencies/numeric fragments from becoming flight IDs.
  const regex = new RegExp(`\\b(${escaped})[\\s-]?(\\d{1,4}[A-Z]?)\\b`, "gi");
  let match: RegExpExecArray | null;
  while ((match = regex.exec(text)) && values.length < 30) {
    const code = match[1].toUpperCase();
    const number = `${code}${match[2].toUpperCase()}`;
    if (!/^[A-Z0-9]{2}\d{1,4}[A-Z]?$/.test(number)) continue;
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

function uzbekistanAirwaysSearchRequest(html: string, baseURL: string, args: FlightBotSearchArgs): { url: string; init: RequestInit } | null {
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

function trustedProviderURL(bot: Pick<OfficialCarrierBot, "officialHosts">, value: string) {
  try {
    const host = new URL(value).hostname.toLowerCase();
    return bot.officialHosts.some((trusted) => host === trusted || host.endsWith(`.${trusted}`));
  } catch { return false; }
}

function dateEvidence(text: string, travelDate: string) {
  const [year, month, day] = travelDate.split("-");
  const tokens = [travelDate, `${day}.${month}.${year}`, `${day}/${month}/${year}`];
  const date = new Date(`${travelDate}T00:00:00Z`);
  if (Number.isFinite(date.getTime())) {
    for (const locale of ["en-US", "ru-RU", "uz-UZ"]) {
      const shortMonth = new Intl.DateTimeFormat(locale, { month: "short", timeZone: "UTC" }).format(date);
      const longMonth = new Intl.DateTimeFormat(locale, { month: "long", timeZone: "UTC" }).format(date);
      tokens.push(`${Number(day)} ${shortMonth} ${year}`, `${Number(day)} ${longMonth} ${year}`);
      tokens.push(new Intl.DateTimeFormat(locale, { day: "numeric", month: "short", year: "numeric", timeZone: "UTC" }).format(date));
      tokens.push(new Intl.DateTimeFormat(locale, { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" }).format(date));
    }
  }
  const lower = text.toLowerCase();
  return tokens.some((token) => lower.includes(token.toLowerCase()));
}

type ObservedFareScope = "totalParty" | "perPassenger";

function inferObservedFareScope(text: string, travelers: Travelers): ObservedFareScope | null {
  const lower = text.toLowerCase();
  if (["starting at", "fare from", "prices from", "price from", "dan boshlab"].some((x) => lower.includes(x))) return null;
  if (/\bот\s+(?:USD|UZS|SAR|AED|RUB|EUR|GBP|[$€₽]|[0-9])/i.test(text)) return null;

  const explicitTotal = ["grand total", "total fare", "trip total", "booking total", "итого", "за всех", "jami"].some((x) => lower.includes(x))
    || /(?:for|для|за)\s+\d+\s+(?:passengers?|travel(?:l)?ers?|pax|пассажир(?:а|ов)?)/i.test(text);
  if (explicitTotal) return "totalParty";

  const perPassenger = ["per passenger", "per person", "/ person", "за пассажира", "на пассажира", "за человека"].some((x) => lower.includes(x));
  if (perPassenger) {
    if (travelers.children > 0 || travelers.infants > 0) return null;
    return "perPassenger";
  }

  return travelerCount(travelers) === 1 ? "totalParty" : null;
}

async function fetchProvider(bot: OfficialCarrierBot, args: FlightBotSearchArgs): Promise<BotFetchResult[]> {
  if (bot.serverMode === "deviceOnly") return [];

  // Uzbekistan Airways has its own first-party route form. We inspect only that
  // carrier's booking page and submit only a form that contains origin,
  // destination and departure-date fields. This is not a cross-airline crawler.
  const first = await fetchText(bot.startURL);
  if (!trustedProviderURL(bot, first.finalURL)) return [];
  const results: BotFetchResult[] = [{ provider: bot, url: first.finalURL, body: first.body, contentType: first.contentType }];
  const next = uzbekistanAirwaysSearchRequest(first.body, first.finalURL, args);
  if (!next || next.url === first.finalURL) return results;
  const second = await fetchText(next.url, next.init);
  if (!trustedProviderURL(bot, second.finalURL)) return results;
  results.push({ provider: bot, url: second.finalURL, body: second.body, contentType: second.contentType });
  return results;
}


export async function normalizeOfficialCarrierText(
  raw: string,
  bot: Pick<OfficialCarrierBot, "id" | "label" | "airlineCodes" | "fareScope" | "startURL" | "officialHosts">,
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
    if (!dateEvidence(block, args.travelDate)) continue;
    const flights = knownFlightNumbers(block, bot.airlineCodes);
    if (flights.length !== 1) continue; // Strict v1: only direct flights with unambiguous segment identity.
    const ts = times(block);
    if (ts.length < 2) continue;
    const money = moneyMatches(block);
    if (!money.length) continue;
    const duration = durationMinutes(block);
    const fare = money.find((m) => Math.abs(m.index - flights[0].index) < 2200) ?? money[0];
    let usd: number;
    try { usd = (await normalizeToUsd(fare.amount, fare.currency, env)).amountUsd; }
    catch { continue; }
    const observedScope = inferObservedFareScope(block, args.travelers);
    if (!observedScope) continue;
    const groupFareUsd = observedScope === "totalParty" ? usd : usd * pax;
    if (!Number.isFinite(groupFareUsd) || groupFareUsd <= 0) continue;
    const departureAt = localISO(args.travelDate, ts[0].value);
    let arrivalDay = args.travelDate;
    const [dh, dm] = ts[0].value.split(":").map(Number);
    const [ah, am] = ts[1].value.split(":").map(Number);
    if (ah * 60 + am < dh * 60 + dm) {
      // Without an explicit duration we cannot know whether the result is an
      // overnight arrival or a timezone effect. Reject instead of inventing a day.
      if (duration <= 0) continue;
      if (duration > 360) {
        const d = new Date(`${args.travelDate}T00:00:00Z`); d.setUTCDate(d.getUTCDate() + 1); arrivalDay = d.toISOString().slice(0, 10);
      }
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
      fareAmountUsd: groupFareUsd,
      fareScope: "totalParty",
      observedAt: new Date().toISOString(),
      sourceURL: bot.startURL,
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
    for (const payload of payloads) {
      const normalized = await normalizeOfficialCarrierText(payload.body, bot, args, env);
      all.push(...normalized.map((candidate) => ({ ...candidate, sourceURL: payload.url })));
    }
    return all;
  } catch { return []; }
}

export function officialCarrierBotIds() { return BOTS.map((bot) => bot.id); }

export function officialCarrierBotCapabilities() {
  return BOTS.map((bot) => ({
    id: bot.id,
    serverMode: bot.serverMode,
    airlineCodes: [...bot.airlineCodes],
    officialHosts: [...bot.officialHosts],
  }));
}

export async function searchOfficialCarrierProvider(
  env: Env,
  providerId: string,
  args: FlightBotSearchArgs,
): Promise<{ candidates: InternalFlightCandidate[]; fromCache: boolean }> {
  if (!validAirport(args.origin) || !validAirport(args.destination) || !validDate(args.travelDate)) {
    throw new Error("INVALID_FLIGHT_SEARCH_ROUTE");
  }
  const bot = BOTS.find((item) => item.id === providerId);
  if (!bot) throw new Error("UNKNOWN_FLIGHT_PROVIDER");
  if (bot.serverMode === "deviceOnly") return { candidates: [], fromCache: false };
  const baseKey = cacheKey(args);
  const key = `${baseKey}|provider:${providerId}`;
  const cached = await getCached(env, key);
  if (cached?.length) {
    return { candidates: renamespaceCached(cached, args), fromCache: true };
  }
  const candidates = await searchOneProvider(env, bot, args);
  const seen = new Set<string>();
  const deduped = candidates
    .filter((candidate) => seen.add(`${candidate.flightNumber}|${candidate.departureAt}|${candidate.arrivalAt}|${Math.round(candidate.groupFareUsd)}`))
    .slice(0, 6);
  await putCached(env, key, deduped, providerId);
  return { candidates: deduped, fromCache: false };
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
  await putCached(env, key, deduped, "officialBots");
  return { candidates: deduped, fromCache: false, attemptedProviders: bots.length, successfulProviders };
}

export function officialCarrierBotCount() { return BOTS.filter((bot) => bot.serverMode !== "deviceOnly").length; }
