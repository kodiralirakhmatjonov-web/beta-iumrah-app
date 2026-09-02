import Foundation

struct LocalHotelPriceComponent: Hashable {
    enum Unit: String, Hashable {
        case totalStay
        case perRoomStay
        case perRoomNight
    }
    let amountUsd: Decimal
    let unit: Unit
    let nights: Int
    let rooms: Int
    let hotelId: String
    let roomId: String?
    let source: String
}

/// Launch pricing policy for the indicative Umrah package price.
/// Keep the existing business model: 50% markup on the complete trip cost,
/// then gross up by the 2% payment fee.
enum LocalPackagePricingEngine {
    static let packageMarkupRate = Decimal(string: "0.50")!
    static let paymentFeeRate = Decimal(string: "0.02")!
    static let publicRoundingStep = Decimal(5)

    static let visaPerTravellerUsd = Decimal(120)
    static let makkahZiyaratPerGroupUsd = Decimal(100)
    static let madinahZiyaratPerGroupUsd = Decimal(100)
    static let accompanimentWithMadinahPerGroupUsd = Decimal(300)
    static let accompanimentMakkahOnlyPerGroupUsd = Decimal(100)
    static let roadWithMadinahPerSedanUsd = Decimal(300)
    static let localWithTrainPerSedanUsd = Decimal(200)
    static let makkahOnlyPerSedanUsd = Decimal(200)
    static let haramainSarPerTraveller = Decimal(300)
    static let sarPerUsd = Decimal(string: "3.75")!
    static let sedanCapacity = 3

    static func calculate(
        trip: TripDraft,
        outboundFareUsd: Decimal,
        outboundScope: FlightFareScope,
        outboundOffer: FlightOffer,
        inboundFareUsd: Decimal?,
        inboundScope: FlightFareScope?,
        inboundOffer: FlightOffer?,
        makkahHotel: LocalHotelPriceComponent,
        madinahHotel: LocalHotelPriceComponent?
    ) throws -> PackageQuote {
        let travelers = max(1, trip.travelerCount)
        let vehicles = max(1, Int(ceil(Double(travelers) / Double(sedanCapacity))))
        let stay = TripStayPlanner.breakdown(for: trip)

        // Independent-flight architecture: each selected one-way ticket has its own
        // supplier fare. A round trip is the sum of the two selected one-way fares.
        let outboundFlights = try groupFare(outboundFareUsd, scope: outboundScope, travelers: travelers)
        let inboundFlights: Decimal
        if trip.isRoundTripFlight {
            guard let inboundFareUsd, let inboundScope, inboundOffer != nil else {
                throw LocalPricingError.invalidFlightFare
            }
            inboundFlights = try groupFare(inboundFareUsd, scope: inboundScope, travelers: travelers)
        } else {
            inboundFlights = 0
        }
        let flights = outboundFlights + inboundFlights

        let makkahHotelCost = hotelCost(makkahHotel)
        let madinahHotelCost = trip.scope == .makkahAndMadinah ? hotelCost(madinahHotel) : 0
        let hotels = makkahHotelCost + madinahHotelCost
        let visa = visaPerTravellerUsd * Decimal(travelers)
        let mealTravellers = max(0, trip.adults + trip.children)
        let meals = mealRate(trip.packageTier) * Decimal(max(1, stay.totalDays)) * Decimal(mealTravellers)

        let includeMadinah = trip.scope == .makkahAndMadinah
        let usesTrain = includeMadinah && (trip.packageTier == .comfort || trip.packageTier == .luxury)
        let transfer = includeMadinah
            ? (usesTrain ? localWithTrainPerSedanUsd : roadWithMadinahPerSedanUsd) * Decimal(vehicles)
            : makkahOnlyPerSedanUsd * Decimal(vehicles)
        let intercity = usesTrain ? (haramainSarPerTraveller / sarPerUsd) * Decimal(travelers) : 0
        let guide = includeMadinah ? accompanimentWithMadinahPerGroupUsd : accompanimentMakkahOnlyPerGroupUsd
        let ziyarat = makkahZiyaratPerGroupUsd + (includeMadinah ? madinahZiyaratPerGroupUsd : 0)

        let totalCost = flights + hotels + visa + meals + transfer + intercity + guide + ziyarat
        guard totalCost > 0 else { throw LocalPricingError.invalidComponents }

        let baseSelling = totalCost + totalCost * packageMarkupRate
        let calculatedSelling = baseSelling / (1 - paymentFeeRate)
        let perPerson = roundPublic(calculatedSelling / Decimal(travelers))
        let total = perPerson * Decimal(travelers)
        let quoteId = "local-\(UUID().uuidString.lowercased())"
        let markupAmount = totalCost * packageMarkupRate
        let paymentFeeAmount = calculatedSelling - baseSelling
        let roundingDifference = total - calculatedSelling
        let estimatedProfit = total - totalCost - paymentFeeAmount

        var components: [GeneratorPricingComponent] = [
            .init(code: "flight_outbound", label: "Авиабилет туда", supplierCostUsd: outboundFlights)
        ]
        if trip.isRoundTripFlight {
            components.append(.init(code: "flight_inbound", label: "Авиабилет обратно", supplierCostUsd: inboundFlights))
        }
        components.append(.init(code: "makkah_hotel", label: "Отель в Мекке", supplierCostUsd: makkahHotelCost))
        if includeMadinah {
            components.append(.init(code: "madinah_hotel", label: "Отель в Медине", supplierCostUsd: madinahHotelCost))
        }
        components.append(contentsOf: [
            .init(code: "visa", label: "Визы", supplierCostUsd: visa),
            .init(code: "meals", label: "Питание", supplierCostUsd: meals),
            .init(code: "transfers", label: "Трансферы", supplierCostUsd: transfer),
        ])
        if intercity > 0 {
            components.append(.init(code: "haramain_train", label: "Поезд Haramain", supplierCostUsd: intercity))
        }
        components.append(.init(code: "accompaniment", label: "Сопровождение", supplierCostUsd: guide))
        components.append(.init(code: "ziyarat_makkah", label: "Зиярат в Мекке", supplierCostUsd: makkahZiyaratPerGroupUsd))
        if includeMadinah {
            components.append(.init(code: "ziyarat_madinah", label: "Зиярат в Медине", supplierCostUsd: madinahZiyaratPerGroupUsd))
        }
        // iumrah Care is included operationally. Its launch supplier allocation is
        // zero until Business assigns an internal cost in the editable report.
        components.append(.init(code: "care", label: "iumrah Care", supplierCostUsd: 0))

        let pricingSnapshot = GeneratorPricingSnapshot(
            quoteId: quoteId,
            pricingVersion: "local-independent-flights-v4",
            currency: "USD",
            context: .init(
                tier: trip.packageTier.rawValue,
                tripType: trip.resolvedFlightTripType.rawValue,
                includeMadinah: includeMadinah,
                totalDays: stay.totalDays,
                travelers: .init(adults: trip.adults, children: trip.children, infants: trip.infants, rooms: trip.rooms),
                roomCount: max(makkahHotel.rooms, madinahHotel?.rooms ?? 0),
                vehicleCount: vehicles
            ),
            selectedPricingInputs: .init(
                journeyFare: nil,
                outbound: fareInput(
                    offer: outboundOffer,
                    originalAmount: outboundOffer.fareAmount ?? outboundFareUsd,
                    scope: outboundScope,
                    normalizedGroupUsd: outboundFlights
                ),
                inbound: trip.isRoundTripFlight ? inboundOffer.map { offer in
                    fareInput(
                        offer: offer,
                        originalAmount: offer.fareAmount ?? inboundFareUsd ?? 0,
                        scope: inboundScope ?? .unknown,
                        normalizedGroupUsd: inboundFlights
                    )
                } : nil,
                makkahHotel: hotelInput(makkahHotel),
                madinahHotel: includeMadinah ? madinahHotel.map(hotelInput) : nil
            ),
            components: components,
            totals: .init(
                supplierCostUsd: totalCost,
                markupRate: packageMarkupRate,
                markupAmountUsd: markupAmount,
                subtotalAfterMarkupUsd: baseSelling,
                paymentFeeRate: paymentFeeRate,
                paymentFeeAmountUsd: paymentFeeAmount,
                calculatedSellingPriceUsd: calculatedSelling,
                publicPricePerPilgrimUsd: perPerson,
                publicTotalUsd: total,
                roundingDifferenceUsd: roundingDifference,
                estimatedProfitUsd: estimatedProfit
            )
        )
        return PackageQuote(
            totalPackagePrice: total,
            pricePerPerson: perPerson,
            currency: "USD",
            isEstimated: true,
            quoteId: quoteId,
            pricingSnapshot: pricingSnapshot
        )
    }

    private static func groupFare(_ amount: Decimal, scope: FlightFareScope, travelers: Int) throws -> Decimal {
        guard amount > 0 else { throw LocalPricingError.invalidFlightFare }
        switch scope {
        case .totalParty: return amount
        case .perPassenger: return amount * Decimal(travelers)
        case .unknown: throw LocalPricingError.invalidFlightFare
        }
    }

    private static func hotelCost(_ value: LocalHotelPriceComponent?) -> Decimal {
        guard let value else { return 0 }
        switch value.unit {
        case .totalStay: return value.amountUsd
        case .perRoomStay: return value.amountUsd * Decimal(max(1, value.rooms))
        case .perRoomNight: return value.amountUsd * Decimal(max(1, value.rooms)) * Decimal(max(1, value.nights))
        }
    }

    private static func fareInput(
        offer: FlightOffer,
        originalAmount: Decimal,
        scope: FlightFareScope,
        normalizedGroupUsd: Decimal
    ) -> GeneratorPricingFare {
        GeneratorPricingFare(
            candidateId: offer.providerItineraryID ?? offer.sourceCandidateID ?? offer.id,
            amount: originalAmount,
            currency: offer.currency.uppercased(),
            fareScope: scope.rawValue,
            providerId: offer.sourceLabel,
            observedAt: isoDateTime(offer.fareObservedAt ?? Date()),
            travelDate: day(offer.departureAt),
            normalizedGroupUsd: normalizedGroupUsd
        )
    }

    private static func hotelInput(_ value: LocalHotelPriceComponent) -> GeneratorPricingHotelInput {
        GeneratorPricingHotelInput(
            amountUsd: value.amountUsd,
            unit: value.unit.rawValue,
            nights: value.nights,
            hotelId: value.hotelId,
            roomId: value.roomId,
            pricingMode: value.source
        )
    }

    private static func isoDateTime(_ value: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: value)
    }

    private static func day(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: value)
    }

    private static func mealRate(_ tier: PackageTier) -> Decimal {
        switch tier {
        case .economy, .standard: return 15
        case .comfort: return 50
        case .luxury: return 100
        }
    }

    private static func roundPublic(_ value: Decimal) -> Decimal {
        let number = NSDecimalNumber(decimal: value / publicRoundingStep).doubleValue
        return Decimal(max(1, Int(number.rounded()))) * publicRoundingStep
    }
}

enum LocalPricingError: LocalizedError {
    case invalidFlightFare
    case missingHotelPrice(String)
    case invalidComponents

    var errorDescription: String? {
        switch self {
        case .invalidFlightFare: return "Не удалось получить текущую стоимость выбранного перелёта."
        case .missingHotelPrice(let city): return "Не удалось получить текущую цену Primary Hotel в городе \(city). Повторите поиск или выберите другой отель."
        case .invalidComponents: return "Компоненты пакета неполные. Повторите расчёт."
        }
    }
}
