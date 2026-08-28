import type { D1Like } from "./primary-hotels";
import type { InternalPricingResult, FlightFareObservation, HotelCost, Travelers } from "./types";

type HotelAuditInput = HotelCost & { hotelId?: string | null; roomId?: string | null; pricingMode?: string | null };

type QuoteAuditMetadata = {
  tier: string;
  includeMadinah: boolean;
  totalDays: number;
  travelers: Travelers;
  outbound: FlightFareObservation & { normalizedGroupUsd: number };
  inbound: FlightFareObservation & { normalizedGroupUsd: number };
  makkahHotel: HotelAuditInput;
  madinahHotel?: HotelAuditInput | null;
};

function hotelTotal(cost: HotelAuditInput | null | undefined, rooms: number) {
  if (!cost) return 0;
  return Number(cost.amountUsd) * Math.max(1, rooms) * (cost.unit === "perRoomNight" ? Math.max(1, cost.nights) : 1);
}

export async function persistQuoteAudit(db: D1Like | undefined, quote: InternalPricingResult, meta: QuoteAuditMetadata) {
  if (!db) return;
  await db.prepare(`CREATE TABLE IF NOT EXISTS package_quote_audits (
    quote_id TEXT PRIMARY KEY,
    pricing_version TEXT NOT NULL DEFAULT '',
    audit_json TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
  )`).run();

  const components = [
    { code: "flight_outbound", label: "Перелёт туда", supplierCostUsd: meta.outbound.normalizedGroupUsd },
    { code: "flight_return", label: "Перелёт обратно", supplierCostUsd: meta.inbound.normalizedGroupUsd },
    { code: "makkah_hotel", label: "Отель Мекки", supplierCostUsd: hotelTotal(meta.makkahHotel, quote.roomCount) },
    ...(meta.includeMadinah && meta.madinahHotel ? [{ code: "madinah_hotel", label: "Отель Медины", supplierCostUsd: hotelTotal(meta.madinahHotel, quote.roomCount) }] : []),
    { code: "visa", label: "Виза", supplierCostUsd: quote.internal.costVisa },
    { code: "meals", label: "Питание", supplierCostUsd: quote.internal.costMeals },
    { code: "transfer", label: "Полный трансфер", supplierCostUsd: quote.internal.costTransfer },
    { code: "guide", label: "Гид", supplierCostUsd: quote.internal.costGuide },
    { code: "ziyarat", label: "Зияраты", supplierCostUsd: quote.internal.costZiyarat },
    { code: "esim", label: "eSIM", supplierCostUsd: quote.internal.costEsim },
  ];

  const audit = {
    quoteId: quote.quoteId,
    pricingVersion: quote.pricingVersion,
    currency: quote.currency,
    context: {
      tier: meta.tier,
      includeMadinah: meta.includeMadinah,
      totalDays: meta.totalDays,
      travelers: meta.travelers,
      roomCount: quote.roomCount,
      vehicleCount: quote.vehicleCount,
    },
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

  await db.prepare(`INSERT INTO package_quote_audits(quote_id,pricing_version,audit_json,created_at)
    VALUES(?,?,?,?)
    ON CONFLICT(quote_id) DO UPDATE SET pricing_version=excluded.pricing_version,audit_json=excluded.audit_json,created_at=excluded.created_at`)
    .bind(quote.quoteId, quote.pricingVersion, JSON.stringify(audit), new Date().toISOString()).run();
}
