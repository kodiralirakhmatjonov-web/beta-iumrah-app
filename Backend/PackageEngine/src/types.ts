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

export type IntercityTransport = "road" | "haramainTrain";

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
  intercityTransport?: IntercityTransport;
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
    costIntercity: number;
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


export type PackageSearchProductKey = "essential" | "comfort" | "luxury";
export type PackageSearchMode = "standard" | "sundayClub";
export type PackageSearchStatus = "queued" | "searching" | "ready" | "partial" | "failed";

export type PackageSearchRequest = {
  clientRequestId: string;
  originCode: string;
  arrivalAirportCode: "JED" | "MED";
  startDate: string;
  endDate: string;
  flexibility: "exact" | "plusMinusOne" | "plusMinusTwo" | "weekend";
  includeMadinah: boolean;
  travelers: Travelers;
};

export type ServerItinerary = {
  mode: PackageSearchMode;
  originCode: string;
  outboundDestination: "JED" | "MED";
  returnOrigin: "JED" | "MED";
  startDate: string;
  endDate: string;
  totalDays: number;
  totalNights: number;
  includeMadinah: boolean;
  makkahCheckIn: string;
  makkahCheckOut: string;
  makkahNights: number;
  madinahCheckIn: string | null;
  madinahCheckOut: string | null;
  madinahNights: number;
};

export type ServerHotelSnapshot = {
  hotelId: string;
  hotelName: string;
  city: "Makkah" | "Madinah";
  stars: number | null;
  rating: number | null;
  reviewCount: number | null;
  coverImageURL: string | null;
  imageCount: number;
  roomCount: number;
  updatedAt: string;
  roomId: string | null;
  pricingMode: "configuredPrimary";
};

export type ServerFlightSegment = {
  id: string;
  airline: string;
  airlineCode: string;
  flightNumber: string;
  origin: string;
  destination: string;
  departureAt: string;
  arrivalAt: string;
  durationMinutes: number;
  originTerminal: string | null;
  destinationTerminal: string | null;
  aircraft: string | null;
  operatingCarrier: string | null;
  cabin: string | null;
};

export type ServerFlightCandidate = {
  id: string;
  providerId: string;
  sourceLabel: string;
  direction: "outbound" | "inbound";
  dateOffset: number;
  travelDate: string;
  origin: string;
  destination: string;
  airline: string;
  airlineCode: string;
  flightNumber: string;
  departureAt: string;
  arrivalAt: string;
  durationMinutes: number;
  stops: number;
  currency: "USD";
  segments: ServerFlightSegment[];
};

export type ServerPackageTransport = {
  type: IntercityTransport;
  label: string;
  haramainSarPerTraveler: number | null;
};

export type ServerGeneratedPackage = {
  key: PackageSearchProductKey;
  pricingTier: PackageTier;
  stars: 1 | 3 | 5;
  recommended: boolean;
  status: "searching" | "ready" | "blocked";
  blockReason: string | null;
  hotelMakkah: ServerHotelSnapshot | null;
  hotelMadinah: ServerHotelSnapshot | null;
  transport: ServerPackageTransport;
  selectedOutboundCandidateId: string | null;
  selectedInboundCandidateId: string | null;
  selectedDateOffset: number;
  quote: PublicPackageQuote | null;
  quoteExpiresAt: string | null;
  hotelPricingMode: "configuredPrimary" | "unavailable";
};

export type PackageSearchSnapshot = {
  ok: true;
  searchId: string;
  clientRequestId: string;
  sequence: number;
  status: PackageSearchStatus;
  mode: PackageSearchMode;
  itinerary: ServerItinerary;
  packages: ServerGeneratedPackage[];
  outboundFlights: ServerFlightCandidate[];
  inboundFlights: ServerFlightCandidate[];
  searchedDateOffsets: number[];
  pendingDateOffsets: number[];
  providerReady: boolean;
  message: string | null;
  updatedAt: string;
};

export type ServerRequoteRequest = {
  packageKey: PackageSearchProductKey;
  outboundCandidateId: string;
  inboundCandidateId: string;
  makkahHotelId?: string | null;
  madinahHotelId?: string | null;
  makkahRoomId?: string | null;
  madinahRoomId?: string | null;
};
