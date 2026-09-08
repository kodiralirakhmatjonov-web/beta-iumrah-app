import Foundation

/// One authoritative hotel catalog rate from iumrah Business.
///
/// The server stores exactly one normalized value: USD for one room / one night.
/// Beta never accepts legacy `totalStay` or `perRoomStay` values in production
/// pricing. Package hotel cost is therefore one explicit multiplication:
/// nightly USD × selected room count × actual stay nights.
struct LocalHotelPriceComponent: Hashable {
    let nightlyUsd: Decimal
    let nights: Int
    let rooms: Int
    let hotelId: String
    let roomId: String?
    let source: String

    var totalStayUsd: Decimal {
        nightlyUsd * Decimal(max(1, rooms)) * Decimal(max(1, nights))
    }
}

/// Launch pricing policy for the indicative Umrah package price.
/// Economy, Standard and Comfort use a 25% package markup. Luxury uses 35%.
/// All tiers are then grossed up by the existing 2% payment fee.
enum LocalPackagePricingEngine {
    static let standardPackageMarkupRate = Decimal(string: "0.25")!
    static let luxuryPackageMarkupRate = Decimal(string: "0.35")!
    static let paymentFeeRate = Decimal(string: "0.02")!
    static let publicRoundingStep = Decimal(5)

    static let visaPerTravellerUsd = Decimal(120)
    static let makkahZiyaratPerGroupUsd = Decimal(100)
    static let madinahZiyaratPerGroupUsd = Decimal(100)
    static let accompanimentWithMadinahPerGroupUsd = Decimal(300)
    static let accompanimentMakkahOnlyPerGroupUsd = Decimal(100)
    /// One base transfer allocation for every package. Vehicle class is a service
    /// choice in the transfer flow and does not change the base package allocation.
    static let transferPerPackageUsd = Decimal(300)

    /// Haramain is no longer bundled by package tier. It is an explicit optional
    /// hybrid-route add-on selected by the pilgrim on the transfer screen.
    static let haramainSarPerTraveller = Decimal(300)
    static let sarPerUsd = Decimal(string: "3.75")!
    static let sedanCapacity = 3

    /// Expedia-style flight pricing contract:
    /// - one-way trip: `journeyFareUsd` is the complete one-way fare returned by Ignav;
    /// - round trip/open jaw: `journeyFareUsd` is the complete two-leg itinerary fare
    ///   returned by Ignav for the exact selected outbound + inbound combination.
    ///
    /// We never add two independent one-way prices for a round trip. International
    /// airlines commonly price a return itinerary differently from two one-way tickets.
    static func calculate(
        trip: TripDraft,
        journeyFareUsd: Decimal,
        journeyFareScope: FlightFareScope,
        pricingOffer: FlightOffer,
        outboundOffer: FlightOffer,
        inboundOffer: FlightOffer?,
        makkahHotel: LocalHotelPriceComponent,
        madinahHotel: LocalHotelPriceComponent?,
        includeHaramainTrain: Bool = false,
        transferVehicle: TransferVehicleKind? = nil
    ) throws -> PackageQuote {
        let travelers = max(1, trip.travelerCount)
        let transferCapacity = transferVehicle?.passengerCapacity ?? sedanCapacity
        let vehicles = max(1, Int(ceil(Double(travelers) / Double(transferCapacity))))
        let stay = TripStayPlanner.breakdown(for: trip)

        let flights = try groupFare(journeyFareUsd, scope: journeyFareScope, travelers: travelers)

        let makkahHotelCost = hotelCost(makkahHotel)
        let madinahHotelCost = trip.scope == .makkahAndMadinah ? hotelCost(madinahHotel) : 0
        let hotels = makkahHotelCost + madinahHotelCost
        let visa = visaPerTravellerUsd * Decimal(travelers)
        let mealTravellers = max(0, trip.adults + trip.children)
        let meals = mealRate(trip.packageTier) * Decimal(max(1, stay.totalDays)) * Decimal(mealTravellers)

        let includeMadinah = trip.scope == .makkahAndMadinah
        let transfer = transferPerPackageUsd
        let usesTrain = includeMadinah && includeHaramainTrain
        let intercity = usesTrain ? haramainAddOnUsd(travelers: travelers) : 0
        let guide = includeMadinah ? accompanimentWithMadinahPerGroupUsd : accompanimentMakkahOnlyPerGroupUsd
        let ziyarat = makkahZiyaratPerGroupUsd + (includeMadinah ? madinahZiyaratPerGroupUsd : 0)

        let totalCost = flights + hotels + visa + meals + transfer + intercity + guide + ziyarat
        guard totalCost > 0 else { throw LocalPricingError.invalidComponents }

        let markupRate = packageMarkupRate(for: trip.packageTier)
        let baseSelling = totalCost + totalCost * markupRate
        let calculatedSelling = baseSelling / (1 - paymentFeeRate)
        let perPerson = roundPublic(calculatedSelling / Decimal(travelers))
        let total = perPerson * Decimal(travelers)
        let quoteId = "local-\(UUID().uuidString.lowercased())"
        let markupAmount = totalCost * markupRate
        let paymentFeeAmount = calculatedSelling - baseSelling
        let roundingDifference = total - calculatedSelling
        let estimatedProfit = total - totalCost - paymentFeeAmount

        var components: [GeneratorPricingComponent] = [
            .init(
                code: trip.isRoundTripFlight ? "flight_roundtrip" : "flight_outbound",
                label: trip.isRoundTripFlight ? "Авиаперелёт туда-обратно" : "Авиабилет туда",
                supplierCostUsd: flights
            ),
            .init(code: "makkah_hotel", label: "Отель в Мекке", supplierCostUsd: makkahHotelCost)
        ]
        if includeMadinah {
            components.append(.init(code: "madinah_hotel", label: "Отель в Медине", supplierCostUsd: madinahHotelCost))
        }
        components.append(contentsOf: [
            .init(code: "visa", label: "Визы", supplierCostUsd: visa),
            .init(code: "meals", label: "Питание", supplierCostUsd: meals),
            .init(code: "transfers", label: transferVehicle.map { "Трансфер · \($0.modelName)" } ?? "Трансферы", supplierCostUsd: transfer),
        ])
        if intercity > 0 {
            components.append(.init(code: "haramain_train_addon", label: "Поезд Haramain · доп. опция", supplierCostUsd: intercity))
        }
        components.append(.init(code: "accompaniment", label: "Сопровождение", supplierCostUsd: guide))
        components.append(.init(code: "ziyarat_makkah", label: "Зиярат в Мекке", supplierCostUsd: makkahZiyaratPerGroupUsd))
        if includeMadinah {
            components.append(.init(code: "ziyarat_madinah", label: "Зиярат в Медине", supplierCostUsd: madinahZiyaratPerGroupUsd))
        }
        // iumrah Care is included operationally. Its launch supplier allocation is
        // zero until Business assigns an internal cost in the editable report.
        components.append(.init(code: "care", label: "iumrah Care", supplierCostUsd: 0))

        let journeyInput = fareInput(
            offer: pricingOffer,
            originalAmount: pricingOffer.fareAmount ?? journeyFareUsd,
            scope: journeyFareScope,
            normalizedGroupUsd: flights,
            travelDate: outboundOffer.departureAt
        )

        let pricingSnapshot = GeneratorPricingSnapshot(
            quoteId: quoteId,
            pricingVersion: "local-expedia-package-v7",
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
                journeyFare: journeyInput,
                outbound: nil,
                inbound: nil,
                makkahHotel: hotelInput(makkahHotel),
                madinahHotel: includeMadinah ? madinahHotel.map(hotelInput) : nil
            ),
            components: components,
            totals: .init(
                supplierCostUsd: totalCost,
                markupRate: markupRate,
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

    /// Storefront preview used by the Hotels tab before a pilgrim starts the dated trip builder.
    /// It intentionally reuses the same package constants, markup, payment fee and public rounding
    /// as the main pricing engine. The storefront adds one current staff-published TAS→MED +
    /// JED→TAS airfare baseline, the concrete hotel being viewed, and the standard Umrah services.
    /// Luxury is an explicit user upgrade; a five-star property does not silently change the tier.
    static func calculateStorefrontPreview(
        tier: PackageTier,
        flightFarePerTravelerUsd: Decimal,
        hotelNightlyUsd: Decimal,
        hotelNights: Int,
        rooms: Int = 1,
        travelers: Int = 2
    ) throws -> PackageQuote {
        let travelers = max(1, travelers)
        let rooms = max(1, rooms)
        let nights = max(1, hotelNights)
        guard flightFarePerTravelerUsd > 0, hotelNightlyUsd > 0 else {
            throw LocalPricingError.invalidComponents
        }

        let vehicles = max(1, Int(ceil(Double(travelers) / Double(sedanCapacity))))
        let flights = flightFarePerTravelerUsd * Decimal(travelers)
        let hotel = hotelNightlyUsd * Decimal(rooms) * Decimal(nights)
        let visa = visaPerTravellerUsd * Decimal(travelers)
        let meals = mealRate(tier) * Decimal(nights + 1) * Decimal(travelers)
        let transfer = transferPerPackageUsd
        let intercity: Decimal = 0
        let guide = accompanimentWithMadinahPerGroupUsd
        let ziyarat = makkahZiyaratPerGroupUsd + madinahZiyaratPerGroupUsd

        let totalCost = flights + hotel + visa + meals + transfer + intercity + guide + ziyarat
        guard totalCost > 0 else { throw LocalPricingError.invalidComponents }

        let markupRate = packageMarkupRate(for: tier)
        let baseSelling = totalCost + totalCost * markupRate
        let calculatedSelling = baseSelling / (1 - paymentFeeRate)
        let perPerson = roundPublic(calculatedSelling / Decimal(travelers))
        let total = perPerson * Decimal(travelers)
        let quoteID = "storefront-\(UUID().uuidString.lowercased())"
        let markupAmount = totalCost * markupRate
        let paymentFeeAmount = calculatedSelling - baseSelling
        let roundingDifference = total - calculatedSelling
        let estimatedProfit = total - totalCost - paymentFeeAmount

        var components: [GeneratorPricingComponent] = [
            .init(code: "flight_open_jaw", label: "Авиаперелёт Ташкент — Медина / Джидда — Ташкент", supplierCostUsd: flights),
            .init(code: "hotel", label: "Отель", supplierCostUsd: hotel),
            .init(code: "visa", label: "Визы", supplierCostUsd: visa),
            .init(code: "meals", label: "Питание", supplierCostUsd: meals),
            .init(code: "transfers", label: "Трансферы", supplierCostUsd: transfer),
        ]
        components.append(.init(code: "accompaniment", label: "Сопровождение", supplierCostUsd: guide))
        components.append(.init(code: "ziyarat_makkah", label: "Зиярат в Мекке", supplierCostUsd: makkahZiyaratPerGroupUsd))
        components.append(.init(code: "ziyarat_madinah", label: "Зиярат в Медине", supplierCostUsd: madinahZiyaratPerGroupUsd))
        components.append(.init(code: "care", label: "iumrah Care", supplierCostUsd: 0))

        let hotelInput = GeneratorPricingHotelInput(
            amountUsd: hotelNightlyUsd,
            unit: "perRoomNight",
            nights: nights,
            hotelId: nil,
            roomId: nil,
            pricingMode: "storefront-catalog"
        )
        let snapshot = GeneratorPricingSnapshot(
            quoteId: quoteID,
            pricingVersion: "local-storefront-package-v1",
            currency: "USD",
            context: .init(
                tier: tier.rawValue,
                tripType: "openJaw",
                includeMadinah: true,
                totalDays: nights + 1,
                travelers: .init(adults: travelers, children: 0, infants: 0, rooms: rooms),
                roomCount: rooms,
                vehicleCount: vehicles
            ),
            selectedPricingInputs: .init(journeyFare: nil, outbound: nil, inbound: nil, makkahHotel: hotelInput, madinahHotel: nil),
            components: components,
            totals: .init(
                supplierCostUsd: totalCost,
                markupRate: markupRate,
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
            quoteId: quoteID,
            pricingSnapshot: snapshot
        )
    }

    static func packageMarkupRate(for tier: PackageTier) -> Decimal {
        tier == .luxury ? luxuryPackageMarkupRate : standardPackageMarkupRate
    }

    static func haramainAddOnUsd(travelers: Int) -> Decimal {
        (haramainSarPerTraveller / sarPerUsd) * Decimal(max(1, travelers))
    }

    /// Customer-facing estimated package delta for the optional train. Raw supplier
    /// component pricing stays internal; this uses the same tier markup, payment fee
    /// and public per-pilgrim rounding as the package itself.
    static func haramainPublicAddOnEstimateUsd(travelers: Int, tier: PackageTier) -> Decimal {
        let travelers = max(1, travelers)
        let supplier = haramainAddOnUsd(travelers: travelers)
        let selling = (supplier + supplier * packageMarkupRate(for: tier)) / (1 - paymentFeeRate)
        return roundPublic(selling / Decimal(travelers)) * Decimal(travelers)
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
        guard let value, value.nightlyUsd > 0 else { return 0 }
        return value.totalStayUsd
    }

    private static func fareInput(
        offer: FlightOffer,
        originalAmount: Decimal,
        scope: FlightFareScope,
        normalizedGroupUsd: Decimal,
        travelDate: Date
    ) -> GeneratorPricingFare {
        GeneratorPricingFare(
            candidateId: offer.providerItineraryID ?? offer.sourceCandidateID ?? offer.id,
            amount: originalAmount,
            currency: offer.currency.uppercased(),
            fareScope: scope.rawValue,
            providerId: offer.sourceLabel,
            observedAt: isoDateTime(offer.fareObservedAt ?? Date()),
            travelDate: day(travelDate),
            normalizedGroupUsd: normalizedGroupUsd
        )
    }

    private static func hotelInput(_ value: LocalHotelPriceComponent) -> GeneratorPricingHotelInput {
        GeneratorPricingHotelInput(
            amountUsd: value.nightlyUsd,
            unit: "perRoomNight",
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
        case .missingHotelPrice(let city): return "Цена Primary Hotel в городе \(city) сейчас недоступна или устарела. Выберите другой доступный отель или повторите позже."
        case .invalidComponents: return "Компоненты пакета неполные. Повторите расчёт."
        }
    }
}
