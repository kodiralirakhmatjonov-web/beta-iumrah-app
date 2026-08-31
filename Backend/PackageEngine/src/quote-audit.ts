import type { D1Like } from "./primary-hotels";
import type { InternalPricingResult, FlightFareObservation, HotelCost, Travelers, IntercityTransport } from "./types";

type HotelAuditInput = HotelCost & {
  hotelId?: string | null;
  roomId?: string | null;
  pricingMode?: string | null;
  hotelName?: string | null;
};

export type QuoteAuditAuthority = "legacy_client" | "server_search";

export type QuoteAuditMetadata = {
  authority?: QuoteAuditAuthority;
  searchId?: string | null;
  packageKey?: string | null;
  expiresAt?: string | null;
  tier: string;
  includeMadinah: boolean;
  totalDays: number;
  travelers: Travelers;
  intercityTransport?: IntercityTransport;
  itinerary?: Record<string, unknown> | null;
  outbound: FlightFareObservation & { normalizedGroupUsd: number; snapshot?: Record<string, unknown> };
  inbound: FlightFareObservation & { normalizedGroupUsd: number; snapshot?: Record<string, unknown> };
  makkahHotel: HotelAuditInput;
  madinahHotel?: HotelAuditInput | null;
};

export type StoredQuoteAudit = {
  quoteId: string;
  pricingVersion: string;
  authority: QuoteAuditAuthority;
  searchId: string | null;
  packageKey: string | null;
  expiresAt: string | null;
  audit: {
    quoteId: string;
    pricingVersion: string;
    currency: string;
    authority: QuoteAuditAuthority;
    searchId: string | null;
    packageKey: string | null;
    expiresAt: string | null;
    context: Record<string, unknown>;
    itinerary: Record<string, unknown> | null;
    selectedPricingInputs: {
      outbound: Record<string, unknown>;
      inbound: Record<string, unknown>;
      makkahHotel: Record<string, unknown>;
      madinahHotel: Record<string, unknown> | null;
    };
    totals: Record<string, number>;
    components: Array<Record<string, unknown>>;
  };
};

function hotelTotal(cost: HotelAuditInput | null | undefined, rooms: number) {
  if (!cost) return 0;
  if (cost.unit === "totalStay") return Number(cost.amountUsd);
  return Number(cost.amountUsd) * Math.max(1, rooms) * (cost.unit === "perRoomNight" ? Math.max(1, cost.nights) : 1);
}

export async function persistQuoteAudit(db: D1Like | undefined, quote: InternalPricingResult, meta: QuoteAuditMetadata) {
  if (!db) return;
  const authority = meta.authority ?? "legacy_client";
  const expiresAt = meta.expiresAt ?? new Date(Date.now() + 15 * 60_000).toISOString();
  const components = [
    { code: "flight_outbound", label: "Перелёт туда", supplierCostUsd: meta.outbound.normalizedGroupUsd },
    { code: "flight_return", label: "Перелёт обратно", supplierCostUsd: meta.inbound.normalizedGroupUsd },
    { code: "makkah_hotel", label: "Отель Мекки", supplierCostUsd: hotelTotal(meta.makkahHotel, quote.roomCount) },
    ...(meta.includeMadinah && meta.madinahHotel ? [{ code: "madinah_hotel", label: "Отель Медины", supplierCostUsd: hotelTotal(meta.madinahHotel, quote.roomCount) }] : []),
    { code: "visa", label: "Виза", supplierCostUsd: quote.internal.costVisa },
    { code: "meals", label: "Питание", supplierCostUsd: quote.internal.costMeals },
    { code: "transfer", label: "Локальный трансфер", supplierCostUsd: quote.internal.costTransfer },
    ...(quote.internal.costIntercity > 0 ? [{ code: "haramain_train", label: "Haramain train", supplierCostUsd: quote.internal.costIntercity }] : []),
    { code: "guide", label: "Гид", supplierCostUsd: quote.internal.costGuide },
    { code: "ziyarat", label: "Зияраты", supplierCostUsd: quote.internal.costZiyarat },
    { code: "esim", label: "eSIM", supplierCostUsd: quote.internal.costEsim },
  ];

  const audit = {
    quoteId: quote.quoteId,
    pricingVersion: quote.pricingVersion,
    currency: quote.currency,
    authority,
    searchId: meta.searchId ?? null,
    packageKey: meta.packageKey ?? null,
    expiresAt,
    context: {
      tier: meta.tier,
      includeMadinah: meta.includeMadinah,
      totalDays: meta.totalDays,
      travelers: meta.travelers,
      roomCount: quote.roomCount,
      vehicleCount: quote.vehicleCount,
      intercityTransport: meta.intercityTransport ?? "road",
    },
    itinerary: meta.itinerary ?? null,
    selectedPricingInputs: {
      outbound: meta.outbound,
      inbound: meta.inbound,
      makkahHotel: meta.makkahHotel,
      madinahHotel: meta.madinahHotel ?? null,
    },
    components,
    totals: {
      supplierCostUsd: quote.internal.totalCost,
      markupRate: 0.50,
      markupAmountUsd: quote.internal.markupAmount,
      subtotalAfterMarkupUsd: quote.internal.baseSellingPrice,
      paymentFeeRate: 0.02,
      paymentFeeAmountUsd: quote.internal.paymentFeeAmount,
      calculatedSellingPriceUsd: quote.internal.sellingPrice,
      publicPricePerPilgrimUsd: quote.pricePerPerson,
      publicTotalUsd: quote.totalPackagePrice,
      roundingDifferenceUsd: quote.totalPackagePrice - quote.internal.sellingPrice,
      estimatedProfitUsd: quote.internal.estimatedProfit,
    },
  };

  await db.prepare(`INSERT INTO package_quote_audits_v2(
      quote_id,pricing_version,authority,search_id,package_key,expires_at,audit_json,created_at
    ) VALUES(?,?,?,?,?,?,?,?)
    ON CONFLICT(quote_id) DO UPDATE SET
      pricing_version=excluded.pricing_version,
      authority=excluded.authority,
      search_id=excluded.search_id,
      package_key=excluded.package_key,
      expires_at=excluded.expires_at,
      audit_json=excluded.audit_json,
      created_at=excluded.created_at`)
    .bind(
      quote.quoteId,
      quote.pricingVersion,
      authority,
      meta.searchId ?? null,
      meta.packageKey ?? null,
      expiresAt,
      JSON.stringify(audit),
      new Date().toISOString(),
    ).run();
}

export async function loadAuthoritativeQuoteAudit(db: D1Like | undefined, quoteId: string): Promise<StoredQuoteAudit | null> {
  if (!db || !quoteId) return null;
  const row = await db.prepare(`SELECT quote_id,pricing_version,authority,search_id,package_key,expires_at,audit_json
      FROM package_quote_audits_v2 WHERE quote_id=?1 LIMIT 1`)
    .bind(quoteId)
    .first<{
      quote_id: string;
      pricing_version: string;
      authority: QuoteAuditAuthority;
      search_id: string | null;
      package_key: string | null;
      expires_at: string | null;
      audit_json: string;
    }>();
  if (!row) return null;
  let audit: StoredQuoteAudit["audit"];
  try {
    audit = JSON.parse(row.audit_json) as StoredQuoteAudit["audit"];
  } catch {
    return null;
  }
  return {
    quoteId: row.quote_id,
    pricingVersion: row.pricing_version,
    authority: row.authority,
    searchId: row.search_id,
    packageKey: row.package_key,
    expiresAt: row.expires_at,
    audit,
  };
}
