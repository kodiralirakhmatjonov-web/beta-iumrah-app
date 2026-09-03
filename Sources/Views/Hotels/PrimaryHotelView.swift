import SwiftUI

struct PrimaryHotelView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var settings: AppSettingsStore

    private var requiresMadinah: Bool { journey.trip.scope == .makkahAndMadinah }
    private var canContinue: Bool {
        journey.selectedHotel != nil && (!requiresMadinah || journey.selectedMadinahHotel != nil)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                IumrahFlowProgress(stage: .hotel)
                heading
                hotelContent

                NavigationLink {
                    OutboundFlightView()
                } label: {
                    HStack(spacing: 9) {
                        Text(FlowCopy.text(.continueToFlights, settings.language))
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
                .disabled(!canContinue)
                .opacity(canContinue ? 1 : 0.42)
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 44)
        }
        .background(Color.iumrahPageBackground)
        .iumrahInternalNavigation(progress: .hotel)
        .task {
            if journey.hotels.isEmpty { await journey.loadMakkahHotels() }
            if requiresMadinah, journey.madinahHotels.isEmpty { await journey.loadMadinahHotels() }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(FlowCopy.text(.hotelStageEyebrow, settings.language))
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            Text(FlowCopy.text(.hotelStageTitle, settings.language))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .tracking(-0.8)
            Text(FlowCopy.text(.hotelStageBody, settings.language))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var hotelContent: some View {
        if journey.isLoadingHotels && journey.selectedHotel == nil {
            loadingCard
        } else if let hotel = journey.selectedHotel {
            stayCard(
                hotel: hotel,
                role: .makkah,
                title: recommendedTitle(role: .makkah),
                roomName: journey.selectedRoom?.name ?? journey.selectedRoomCategory?.displayName
            )
        } else {
            missingHotelCard(role: .makkah)
        }

        if requiresMadinah {
            if journey.isLoadingMadinahHotels && journey.selectedMadinahHotel == nil {
                loadingCard
            } else if let hotel = journey.selectedMadinahHotel {
                stayCard(
                    hotel: hotel,
                    role: .madinah,
                    title: recommendedTitle(role: .madinah),
                    roomName: journey.selectedMadinahRoom?.name ?? journey.selectedMadinahRoomCategory?.displayName
                )
            } else {
                missingHotelCard(role: .madinah)
            }
        }
    }

    private func recommendedTitle(role: HotelSelectionRole) -> String {
        switch settings.language {
        case .english:
            return "iumrah Recommended"
        case .russian:
            return "Рекомендуем iumrah"
        case .uzbek:
            return "iumrah tavsiyasi"
        case .uzbekCyrillic:
            return "iumrah тавсияси"
        }
    }

    private var loadingCard: some View {
        HStack(spacing: 13) {
            ProgressView()
            Text(L10n.text("primary_hotel_loading", settings.language))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(20)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func stayCard(hotel: HotelSummary, role: HotelSelectionRole, title: String, roomName: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            hotelImage(hotel)
                .frame(height: 190)
                .background(Color.iumrahRaisedBackground)

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Label(title, systemImage: "sparkles")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(Color.iumrahCareLight.opacity(0.16), in: Capsule())

                    Spacer(minLength: 8)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.iumrahCareLight)
                }

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 7) {
                        Text(FlowCopy.text(.primaryHotel, settings.language))
                        if let stars = hotel.stars { Text("· \(stars)★") }
                        Text("·")
                        Text(role == .makkah ? localizedMakkah : localizedMadinah)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                    Text(hotel.name)
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .tracking(-0.4)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    Label(L10n.city(hotel.city, settings.language), systemImage: "mappin.and.ellipse")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 11)
                        .frame(height: 32)
                        .background(Color.iumrahRaisedBackground, in: Capsule())

                    if let roomName, !roomName.isEmpty {
                        Label(roomName, systemImage: "bed.double.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .padding(.horizontal, 11)
                            .frame(height: 32)
                            .background(Color.iumrahRaisedBackground, in: Capsule())
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 10) {
                    NavigationLink {
                        HotelDetailView(hotel: hotel, selectionFlow: true, selectionRole: role)
                    } label: {
                        Label(FlowCopy.text(.viewHotel, settings.language), systemImage: "info.circle")
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SoftHotelActionButtonStyle())

                    NavigationLink {
                        HotelSelectionView(role: role)
                    } label: {
                        Label(FlowCopy.text(.changeHotel, settings.language), systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SoftHotelActionButtonStyle())
                }
            }
            .padding(18)
        }
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.05), radius: 18, y: 8)
    }

    private var localizedMakkah: String {
        switch settings.language {
        case .russian: return "Мекка"
        case .english: return "Makkah"
        case .uzbek: return "Makka"
        case .uzbekCyrillic: return "Макка"
        }
    }

    private var localizedMadinah: String {
        switch settings.language {
        case .russian: return "Медина"
        case .english: return "Madinah"
        case .uzbek: return "Madina"
        case .uzbekCyrillic: return "Мадина"
        }
    }

    private func missingHotelCard(role: HotelSelectionRole) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 36, weight: .light))
            Text(role == .makkah ? FlowCopy.text(.makkahStay, settings.language) : FlowCopy.text(.madinahStay, settings.language))
                .font(.headline)
            NavigationLink {
                HotelSelectionView(role: role)
            } label: {
                Text(FlowCopy.text(.chooseHotel, settings.language))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(IumrahSecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private func hotelImage(_ hotel: HotelSummary) -> some View {
        AsyncImage(url: AppConfig.absoluteURL(hotel.coverImageURL)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .empty:
                ZStack { Color.iumrahRaisedBackground; ProgressView() }
            default:
                ZStack {
                    Color.iumrahRaisedBackground
                    Image(systemName: "building.2")
                        .font(.system(size: 42, weight: .light))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

private struct SoftHotelActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Color.iumrahRaisedBackground.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
