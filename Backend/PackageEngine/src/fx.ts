export type FxEnvironment = {
  CBU_FX_URL?: string;
};

type CbuRate = {
  Ccy: string;
  Nominal: string | number;
  Rate: string | number;
  Date?: string;
};

type CachedTable = {
  loadedAt: number;
  asOf: string | null;
  uzsPerUnit: Map<string, number>;
};

let memoryCache: CachedTable | null = null;
const CACHE_TTL_MS = 15 * 60 * 1000;

export type NormalizedMoney = {
  amountUsd: number;
  sourceCurrency: string;
  fxAsOf: string | null;
};

function positiveNumber(value: unknown, label: string): number {
  const number = Number(value);
  if (!Number.isFinite(number) || number <= 0) throw new Error(`${label} must be a positive number`);
  return number;
}

async function loadTable(env: FxEnvironment): Promise<CachedTable> {
  const now = Date.now();
  if (memoryCache && now - memoryCache.loadedAt < CACHE_TTL_MS) return memoryCache;

  const url = env.CBU_FX_URL ?? "https://cbu.uz/en/arkhiv-kursov-valyut/json/";
  const response = await fetch(url, {
    headers: { accept: "application/json", "user-agent": "iumrah-package-engine/0.6" },
  });
  if (!response.ok) throw new Error(`FX provider unavailable (${response.status})`);

  const payload = (await response.json()) as CbuRate[];
  if (!Array.isArray(payload) || payload.length === 0) throw new Error("FX provider returned no rates");

  const uzsPerUnit = new Map<string, number>();
  uzsPerUnit.set("UZS", 1);
  let asOf: string | null = null;

  for (const row of payload) {
    const ccy = String(row.Ccy ?? "").toUpperCase();
    if (!/^[A-Z]{3}$/.test(ccy)) continue;
    const nominal = positiveNumber(row.Nominal, `${ccy} nominal`);
    const rate = positiveNumber(row.Rate, `${ccy} rate`);
    uzsPerUnit.set(ccy, rate / nominal);
    if (!asOf && row.Date) asOf = String(row.Date);
  }

  if (!uzsPerUnit.has("USD")) throw new Error("FX table does not contain USD");
  memoryCache = { loadedAt: now, asOf, uzsPerUnit };
  return memoryCache;
}

export async function normalizeToUsd(amount: number, currency: string, env: FxEnvironment): Promise<NormalizedMoney> {
  const sourceAmount = positiveNumber(amount, "Fare amount");
  const sourceCurrency = currency.trim().toUpperCase();
  if (sourceCurrency === "USD") {
    return { amountUsd: sourceAmount, sourceCurrency, fxAsOf: null };
  }

  const table = await loadTable(env);
  const sourceUzs = table.uzsPerUnit.get(sourceCurrency);
  const usdUzs = table.uzsPerUnit.get("USD");
  if (!sourceUzs || !usdUzs) throw new Error(`Unsupported fare currency: ${sourceCurrency}`);

  return {
    amountUsd: sourceAmount * (sourceUzs / usdUzs),
    sourceCurrency,
    fxAsOf: table.asOf,
  };
}
