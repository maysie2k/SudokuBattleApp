import SwiftUI

struct GameOverView: View {
    let title: String
    let subtitle: String
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text(title)
                .font(.title.bold())
            Text(subtitle)
                .foregroundStyle(.secondary)
            Button("Reset", action: onReset)
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
