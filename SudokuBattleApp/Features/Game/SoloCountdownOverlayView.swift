import SwiftUI

struct SoloCountdownOverlayView: View {
    let countdown: Int
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 10) {
            Text("Get Ready")
                .font(.vonique(30, fallbackWeight: .medium))
                .foregroundStyle(AppTheme.textSecondary)

            Text("\(countdown)")
                .font(.vonique(160, fallbackWeight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .scaleEffect(pulse ? 1.16 : 0.78)
                .opacity(pulse ? 1.0 : 0.34)
                .animation(.easeInOut(duration: 0.46), value: pulse)
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 36)
        .background(AppTheme.card.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onAppear {
            animateCountPulse()
        }
        .onChange(of: countdown) { _ in
            animateCountPulse()
        }
    }

    private func animateCountPulse() {
        pulse = false
        withAnimation(.easeInOut(duration: 0.46)) {
            pulse = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            withAnimation(.easeOut(duration: 0.36)) {
                pulse = false
            }
        }
    }
}
