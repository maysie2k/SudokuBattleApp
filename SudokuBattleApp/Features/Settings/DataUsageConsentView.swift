import SwiftUI

struct DataUsageConsentView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("DATA USAGE CONSENT")
                    .font(.vonique(40, fallbackWeight: .medium))
                    .foregroundStyle(.black)

                Text("Sudoku Arena\nBricks in a Bag Ltd\nUK")
                    .font(.titilliumBoard(22, fallbackWeight: .semibold))
                    .foregroundStyle(.black)

                section(
                    "1. Data Minimisation",
                    body: "Sudoku Arena is designed around minimal data collection.\n\nWe do not:\n• Create user accounts\n• Store personal identity data\n• Sell data\n• Share data for marketing"
                )

                section(
                    "2. What Data Exists and Where",
                    body: "Data Type | Stored Where | Retention\nSolo game progress | User device only | Until app deleted\nProfile name | User device only | Until changed or deleted\nProfile picture | User device only | Until changed or deleted\nMultiplayer session data | Transient via Firebase | Deleted at session end\nLeaderboard (solo mode) | Firebase | Stored without real identity\n\nLeaderboard entries:\n• Use profile name only\n• Are not linked to real-world identity\n• Can be cleared upon request (contact support)"
                )

                section(
                    "3. Data Retention",
                    body: "Because we do not operate user accounts:\n• No long-term personal data is retained.\n• Deleting the app deletes all local data.\n• Multiplayer session data is temporary.\n• Leaderboard data is retained unless removal is requested."
                )

                section(
                    "4. Third-Party Services",
                    body: "We use:\n• Firebase (Google) - for multiplayer connectivity and leaderboard hosting.\n\nFirebase processes data under Google’s privacy framework.\n\nWe do not use:\n• Advertising networks (currently)\n• Behavioural analytics\n• Marketing platforms"
                )

                section(
                    "5. Future Advertising",
                    body: "If ads are introduced in a future version:\n• This policy will be updated.\n• Users will be informed via App Store update notes.\n• Any required consent mechanisms (e.g. App Tracking Transparency) will be implemented."
                )

                section(
                    "6. Liability Limitation",
                    body: "Sudoku Arena is provided \"as is\" without warranties of uninterrupted service.\n\nBricks in a Bag Ltd is not liable for:\n• Loss of local game data\n• Service interruptions\n• Multiplayer connectivity issues"
                )

                section(
                    "7. Contact",
                    body: "For privacy or data enquiries:\nsupport@bricksinabag.com"
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.titilliumBoard(21, fallbackWeight: .semibold))
                .foregroundStyle(.black)
            Text(body)
                .font(.titilliumBoard(17, fallbackWeight: .regular))
                .foregroundStyle(.black)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
