import SwiftUI

/// Legacy compatibility route from the discontinued multi-package experiment.
/// Generator V2 follows Trip -> Primary Hotel -> Flights -> Local Pricing.
struct PackageGenerationView: View {
    var body: some View { PrimaryHotelView() }
}
