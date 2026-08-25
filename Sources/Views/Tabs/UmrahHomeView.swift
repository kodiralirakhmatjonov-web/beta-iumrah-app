import SwiftUI

struct UmrahHomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Umrah")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text("Раздел инструкций и сопровождения Умры будет добавлен позже.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.iumrahPageBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
