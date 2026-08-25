import SwiftUI

struct UmrahHomeView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 34, weight: .medium))
                .frame(width: 72, height: 72)
                .background(Color.iumrahRaisedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            Text("Умра")
                .font(.system(size: 31, weight: .bold, design: .rounded))
            Text("Раздел пошагового сопровождения Умры будет добавлен позже.")
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
