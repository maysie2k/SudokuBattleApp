import SwiftUI

struct ReadyOverlayView: View {
    let mode: GameMode
    let matchCode: String
    @Binding var joinCode: String
    let onCreateMatch: () -> Void
    let onJoinMatch: () -> Void
    let onGo: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Are you ready to start?")
                .font(.vonique(38, fallbackWeight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            if mode == .battle {
                MatchLobbyView(
                    joinCode: $joinCode,
                    matchCode: matchCode,
                    onCreate: onCreateMatch,
                    onJoin: onJoinMatch
                )
            }

            Button {
                onGo()
            } label: {
                Text("Go")
                    .font(.vonique(34, fallbackWeight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
            }
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(AppTheme.card.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(24)
    }
}
