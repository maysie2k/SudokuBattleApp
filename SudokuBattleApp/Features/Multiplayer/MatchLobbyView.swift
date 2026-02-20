import SwiftUI

struct MatchLobbyView: View {
    @Binding var joinCode: String
    let matchCode: String
    let onCreate: () -> Void
    let onJoin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Battle Lobby")
                .font(.headline)

            if !matchCode.isEmpty {
                Text("Your code: \\(matchCode)")
                    .font(.subheadline.weight(.semibold))
            }

            HStack(spacing: 8) {
                TextField("Enter match code", text: $joinCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
                    .textFieldStyle(.roundedBorder)

                Button("Join", action: onJoin)
                    .buttonStyle(.bordered)
            }

            Button("Create Private Match", action: onCreate)
                .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
