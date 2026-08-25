import type { HotelCost } from "./types";

export type HotelPricingMode = "configuredPrimary" | "legacyEstimate";

const BASE_NIGHTLY_USD: Record<number, number> = {
  1: 44,
  2: 62,
  3: 82,
  4: 112,
  5: 175,
};

function normalizedStars(value: number): number {
  const rounded = Math.round(Number(value));
  return Math.min(5, Math.max(1, Number.isFinite(rounded) ? rounded : 4));
}

function monthFactor(isoDate?: string | null): number {
  if (!isoDate || !/^\d{4}-\d{2}-\d{2}$/.test(isoDate)) return 1;
  const month = Number(isoDate.slice(5, 7));
  if ([12, 1, 2, 3].includes(month)) return 1.12;
  if ([6, 7, 8].includes(month)) return 0.94;
  return 1;
}

export function legacyEstimatedHotelCost(
  stars: number,
  city: "Makkah" | "Madinah",
  nights: number,
  travelStartDate?: string | null,
): HotelCost {
  const star = normalizedStars(stars);
  const cityFactor = city === "Makkah" ? 1 : 0.86;
  const nightly = BASE_NIGHTLY_USD[star] * cityFactor * monthFactor(travelStartDate);
  return {
    amountUsd: Math.round(nightly * 100) / 100,
    unit: "perRoomNight",
    nights: Math.max(1, nights),
  };
}
