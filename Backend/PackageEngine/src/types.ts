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
  unit: "totalStay" | "perRoomStay" | "perRoomNight";
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


export type HotelFareObservation = {
  id?: string;
  hotelId: string;
  hotelName?: string;
  city: "Makkah" | "Madinah" | string;
  amount: number;
  currency: string;
  unit: "totalStay" | "perRoomStay" | "perRoomNight";
  providerId: "booking" | "expedia" | string;
  providerName?: string;
  observedAt: string;
  checkInDate: string;
  checkOutDate: string;
  sourceURL?: string;
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
  travelStartDate?: string;
  primaryHotelIds?: {
    makkah?: string | null;
    madinah?: string | null;
  };
  hotelPriceObservations?: {
    makkah?: HotelFareObservation[];
    madinah?: HotelFareObservation[];
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

export type FlightFareObservation = {
  candidateId: string;
  amount: number;
  currency: string;
  fareScope: "perPassenger" | "totalParty";
  providerId: string;
  observedAt: string;
  travelDate: string;
};

export type FlightQuoteContext = Omit<ConsumerPackageQuoteRequest, "flights">;

export type OutboundFlightOptionsQuoteRequest = {
  phase: "outbound";
  context: FlightQuoteContext;
  outboundCandidates: FlightFareObservation[];
  returnCandidates: FlightFareObservation[];
};

export type ReturnFlightOptionsQuoteRequest = {
  phase: "return";
  context: FlightQuoteContext;
  selectedOutbound: FlightFareObservation;
  returnCandidates: FlightFareObservation[];
};

export type FlightOptionsQuoteRequest = OutboundFlightOptionsQuoteRequest | ReturnFlightOptionsQuoteRequest;

export type PublicFlightOptionQuote = PublicPackageQuote & {
  candidateId: string;
};

export type PublicFlightOptionsQuoteResponse = {
  ok: true;
  phase: "outbound" | "return";
  options: PublicFlightOptionQuote[];
  referenceReturnCandidateId?: string;
  fxAsOf?: string | null;
  hotelPricingMode?: "liveProvider" | "configuredPrimary" | "legacyEstimate" | "mixed";
};
