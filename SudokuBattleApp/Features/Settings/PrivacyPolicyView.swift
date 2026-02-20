import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("PRIVACY POLICY")
                    .font(.vonique(40, fallbackWeight: .medium))
                    .foregroundStyle(.black)

                Text("Sudoku Arena")
                    .font(.titilliumBoard(24, fallbackWeight: .semibold))
                Text("Operated by Bricks in a Bag Ltd\nUnited Kingdom\nContact: support@bricksinabag.com\nLast updated: 12/02/2026")
                    .font(.titilliumBoard(18, fallbackWeight: .regular))
                    .foregroundStyle(.black)

                section(
                    "1. Overview",
                    body: "Sudoku Arena is a free puzzle game. We respect your privacy. The app is designed to collect as little personal data as possible.\n\nMost game data is stored locally on your device."
                )

                section(
                    "2. Information We Collect",
                    body: "A. Information You Provide\n• Profile name (optional)\n• Profile picture (optional)\n\nThis information:\n• Is stored locally on your device.\n• Is only shared temporarily during live multiplayer matches via Firebase.\n• Is not stored permanently on our servers.\n\nB. Multiplayer Data\nWhen playing online multiplayer:\n• A temporary session ID (random UUID) is generated.\n• Profile name and picture are transmitted to the other player.\n• Firebase transmits game progress data (e.g. squares remaining, power-ups).\n\nThis data:\n• Is used only to enable live gameplay.\n• Is not retained after the session ends.\n• Is not linked to your real identity.\n\nC. Automatically Collected Information\nThe app itself does not collect:\n• Device identifiers (IDFA / IDFV)\n• IP addresses\n• Location data\n• Contacts\n• Crash logs\n• Advertising identifiers\n• App analytics data\n\nHowever, Firebase (a Google service used for multiplayer connectivity) may process basic network metadata (such as IP address) on a server level for security and routing purposes. This is handled by Google under their own privacy terms."
                )

                section(
                    "3. Analytics & Tracking",
                    body: "• App analytics are disabled.\n• No advertising SDK is currently active.\n• No cross-app tracking is used.\n• No profiling or behavioural tracking occurs.\n\nIf advertising is introduced in future updates, this policy will be updated accordingly."
                )

                section(
                    "4. Data Storage",
                    body: "• All solo game data is stored locally on your device.\n• If you delete the app, all local data is permanently deleted.\n• We do not maintain user accounts.\n• We do not maintain user databases."
                )

                section(
                    "5. Children",
                    body: "Sudoku Arena is intended for a general audience and is not specifically directed at children under 13.\n\nThe app does not collect personal data from children. If a parent believes personal data has been shared, they may contact us at support@bricksinabag.com."
                )

                section(
                    "6. Your Rights (UK GDPR)",
                    body: "Under UK data protection law, you have the right to:\n• Request access to personal data\n• Request deletion of personal data\n• Request correction of personal data\n\nAs we do not maintain user accounts or centralised databases, most data is stored locally and can be deleted by removing the app.\n\nFor any privacy enquiries, contact:\nsupport@bricksinabag.com"
                )

                section(
                    "7. Data Security",
                    body: "We use industry-standard services (Firebase by Google) to enable secure multiplayer connections.\n\nNo system can be guaranteed 100% secure, but we minimise risk by collecting minimal data."
                )

                section(
                    "8. Changes to This Policy",
                    body: "We may update this policy if features change (e.g. ads or analytics are added). The updated version will always include a revised \"Last Updated\" date."
                )

                section(
                    "9. Governing Law",
                    body: "This Privacy Policy is governed by the laws of England and Wales."
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
