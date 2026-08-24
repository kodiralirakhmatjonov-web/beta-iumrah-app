export type PackageTier = "economy" | "standard" | "comfort" | "luxury";

export type Travelers = {
  adults: number;
  children: number;
  infants: number;
  rooms: number;
};

export type FlightLegCost = {
  totalGroupUsd?: number;
  adultUsd?: number;
  childUsd?: number;
  infantUsd?: number;
};

export type HotelCost = {
  amountUsd: number;
  unit: "perRoomStay" | "perRoomNight";
  nights: number;
};

export type PackageCustomization = {
  accompaniment: boolean;
  meals: boolean;
  ziyaratMakkah: boolean;
  ziyaratMadinah: boolean;
  esim: boolean;
};

export type PackageQuoteRequest = {
  tier: PackageTier;
  includeMadinah: boolean;
  totalDays: number;
  travelers: Travelers;
  flights: {
    outbound: FlightLegCost;
    inbound: FlightLegCost;
  };
  hotels: {
    makkah: HotelCost;
    madinah?: HotelCost | null;
  };
  customization?: Partial<PackageCustomization>;
};

export type PublicPackageQuote = {
  quoteId: string;
  pricingVersion: string;
  currency: "USD";
  pricePerPerson: number;
  totalPackagePrice: number;
  roomCount: number;
  vehicleCount: number;
};

export type InternalPricingResult = PublicPackageQuote & {
  internal: {
    totalCost: number;
    costFlights: number;
    costHotel: number;
    costVisa: number;
    costMeals: number;
    costTransfer: number;
    costGuide: number;
    costZiyarat: number;
    costEsim: number;
    markupAmount: number;
    baseSellingPrice: number;
    paymentFeeAmount: number;
    sellingPrice: number;
    estimatedProfit: number;
  };
};

export type ConsumerPackageQuoteRequest = {
  tier: PackageTier;
  hotelStars: number;
  includeMadinah: boolean;
  totalDays: number;
  nights: {
    makkah: number;
    madinah: number;
  };
  travelers: Travelers;
  flights: {
    outbound: FlightLegCost;
    inbound: FlightLegCost;
  };
  primaryHotelIds?: {
    makkah?: string | null;
    madinah?: string | null;
  };
  customization?: Partial<PackageCustomization>;
};

export type PrimaryHotelRecord = {
  id: string;
  package_tier: PackageTier;
  stars: number;
  city: "Makkah" | "Madinah";
  hotel_id: string;
  room_id: string | null;
  base_price_usd: number;
  price_unit: "perRoomStay" | "perRoomNight";
  active: number;
  updated_at: string;
};
