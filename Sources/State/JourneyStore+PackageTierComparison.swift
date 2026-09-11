import Foundation

/// A fully-resolved comparison card for one iumrah package tier.
///
/// Flight choice, travel dates and passenger count stay fixed while the hotel
/// category (and its default meal policy) changes. A card is selectable only when
/// the Business hotel catalogue and local pricing engine can produce a complete
/// verified quote for that tier.
struct PackageTierComparisonOption: Identifiable, Hashable {
    let tier: PackageTier
    let quote: PackageQuote?
    let makkahHotel: HotelSummary?
    let madinahHotel: HotelSummary?
    let unavailableReason: String?

    var id: PackageTier { tier }

    var isAvailable: Bool {
        quote != nil && makkahHotel != nil && unavailableReason == nil
    }
}

@MainActor
extension JourneyStore {
    /// Builds Economy / Standard / Comfort / Luxury comparison cards without
    /// mutating the pilgrim's current configuration.
    ///
    /// The currently selected flight pair is deliberately reused. For every other
    /// tier a temporary JourneyStore resolves that tier's Primary Hotel(s), loads
    /// the server-maintained hotel price snapshot and asks the same local pricing
    /// engine used by the real booking flow for the total.
    func buildPackageTierComparisons() async -> [PackageTierComparisonOption] {
        var options: [PackageTierComparisonOption] = []
        options.reserveCapacity(PackageTier.allCases.count)

        for tier in PackageTier.allCases {
            if tier == trip.packageTier,
               let currentHotel = selectedHotel,
               let currentQuote = quote,
               hasFinalGeneratorQuote {
                options.append(
                    PackageTierComparisonOption(
                        tier: tier,
                        quote: currentQuote,
                        makkahHotel: currentHotel,
                        madinahHotel: selectedMadinahHotel,
                        unavailableReason: nil
                    )
                )
                continue
            }

            options.append(await packageTierComparisonOption(for: tier))
        }

        return options
    }

    /// Applies an already priced comparison card to the live journey while keeping
    /// the selected flights, dates, passengers and transfer choices unchanged.
    func applyPackageTierComparison(_ option: PackageTierComparisonOption) {
        guard option.isAvailable,
              let makkahHotel = option.makkahHotel,
              let quote = option.quote else { return }

        var updatedTrip = trip
        updatedTrip.packageTier = option.tier
        updatedTrip.hotelStars = option.tier.primaryHotelStars
        // Comfort/Luxury begin with breakfast only. Paid lunch/dinner remain
        // explicit opt-ins after switching tiers.
        updatedTrip.mealSelection = nil
        trip = updatedTrip

        selectedHotel = makkahHotel
        selectedRoom = nil
        selectedRoomCategory = nil

        if updatedTrip.scope == .makkahAndMadinah {
            selectedMadinahHotel = option.madinahHotel
        } else {
            selectedMadinahHotel = nil
        }
        selectedMadinahRoom = nil
        selectedMadinahRoomCategory = nil

        self.quote = quote
        errorMessage = nil

        // Warm the corresponding hotel snapshot for any subsequent meal/room
        // edit. The already-resolved comparison quote remains immediately visible.
        scheduleHotelPricePrefetch(forceRefresh: false)
    }

    private func packageTierComparisonOption(for tier: PackageTier) async -> PackageTierComparisonOption {
        guard let outbound = selectedOutbound, outbound.isVerifiedForBooking else {
            return unavailableTierOption(tier, reason: "Verified outbound flight is required.")
        }
        if trip.isRoundTripFlight {
            guard let inbound = selectedInbound, inbound.isVerifiedForBooking else {
                return unavailableTierOption(tier, reason: "Verified return flight is required.")
            }
        }

        var comparisonTrip = trip
        comparisonTrip.packageTier = tier
        comparisonTrip.hotelStars = tier.primaryHotelStars
        comparisonTrip.mealSelection = nil

        // Use an isolated flight/pricing coordinator so comparing cards cannot
        // invalidate the live JourneyStore's verified flight or hotel cache.
        let comparisonStore = JourneyStore(
            hotelService: hotelService,
            flightService: AutomaticFlightSearchService(),
            quoteService: quoteService
        )
        comparisonStore.trip = comparisonTrip
        comparisonStore.packageFlightPath = packageFlightPath
        comparisonStore.selectedPublishedCompleteID = selectedPublishedCompleteID
        comparisonStore.selectedPublishedOutboundID = selectedPublishedOutboundID
        comparisonStore.selectedPublishedReturnID = selectedPublishedReturnID
        comparisonStore.selectedOutbound = outbound
        comparisonStore.selectedInbound = selectedInbound

        comparisonStore.selectedTransferVehicle = selectedTransferVehicle
        comparisonStore.haramainTrainSelected = haramainTrainSelected
        comparisonStore.haramainFareClass = haramainFareClass
        comparisonStore.haramainAdultTickets = haramainAdultTickets
        comparisonStore.haramainChildTickets = haramainChildTickets
        comparisonStore.transferSelectionConfirmed = transferSelectionConfirmed

        await comparisonStore.loadMakkahHotels()
        guard let makkahHotel = comparisonStore.selectedHotel else {
            return unavailableTierOption(
                tier,
                reason: comparisonStore.errorMessage ?? "Primary Hotel is unavailable for this tier."
            )
        }

        if comparisonTrip.scope == .makkahAndMadinah {
            await comparisonStore.loadMadinahHotels()
            guard comparisonStore.selectedMadinahHotel != nil else {
                return PackageTierComparisonOption(
                    tier: tier,
                    quote: nil,
                    makkahHotel: makkahHotel,
                    madinahHotel: nil,
                    unavailableReason: comparisonStore.errorMessage ?? "Madinah Primary Hotel is unavailable for this tier."
                )
            }
        }

        comparisonStore.scheduleHotelPricePrefetch(forceRefresh: false)
        await comparisonStore.buildQuote(forceHotelRefresh: false)

        guard let resolvedQuote = comparisonStore.quote,
              comparisonStore.hasFinalGeneratorQuote else {
            return PackageTierComparisonOption(
                tier: tier,
                quote: nil,
                makkahHotel: makkahHotel,
                madinahHotel: comparisonStore.selectedMadinahHotel,
                unavailableReason: comparisonStore.errorMessage ?? "A verified price is temporarily unavailable for this tier."
            )
        }

        return PackageTierComparisonOption(
            tier: tier,
            quote: resolvedQuote,
            makkahHotel: makkahHotel,
            madinahHotel: comparisonStore.selectedMadinahHotel,
            unavailableReason: nil
        )
    }

    private func unavailableTierOption(_ tier: PackageTier, reason: String) -> PackageTierComparisonOption {
        PackageTierComparisonOption(
            tier: tier,
            quote: nil,
            makkahHotel: nil,
            madinahHotel: nil,
            unavailableReason: reason
        )
    }
}
