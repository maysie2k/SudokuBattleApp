import SwiftUI

struct ArenaLeaderboardView: View {
    private let leaderboardService: ArenaLeaderboardServiceProtocol
    private let monthKey: String
    private let playerID: String
    private let minMatches: Int

    @State private var topPlayers: [ArenaPlayerMonthlyStats] = []
    @State private var standing = ArenaPlayerStanding(
        monthKey: ArenaLeaderboardMonth.currentKey(),
        averageScore: 0,
        gamesPlayed: 0,
        rank: nil,
        pointsToTop50: nil
    )
    @State private var isLoading = false

    init(
        monthKey: String = ArenaLeaderboardMonth.currentKey(),
        playerID: String = ArenaIdentity.stablePlayerID(),
        minMatches: Int = 2,
        leaderboardService: ArenaLeaderboardServiceProtocol = ArenaLeaderboardService()
    ) {
        self.monthKey = monthKey
        self.playerID = playerID
        self.minMatches = minMatches
        self.leaderboardService = leaderboardService
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("GLOBAL ARENA LEADERBOARD")
                    .font(.vonique(30, fallbackWeight: .medium))
                    .foregroundStyle(.black)
                Text(ArenaLeaderboardMonth.displayName(for: monthKey))
                    .font(.titilliumBoard(18, fallbackWeight: .semibold))
                    .foregroundStyle(.black.opacity(0.7))

                yourStandingCard

                HStack {
                    Text("RANK")
                    Spacer()
                    Text("PLAYER")
                    Spacer()
                    Text("AVG SCORE")
                }
                .font(.titilliumBoard(15, fallbackWeight: .semibold))
                .foregroundStyle(.black)
                .underline()

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                } else if topPlayers.isEmpty {
                    Text("No ranked players yet this month.")
                        .font(.titilliumBoard(16, fallbackWeight: .regular))
                        .foregroundStyle(.black.opacity(0.7))
                        .padding(.vertical, 12)
                } else {
                    ForEach(Array(topPlayers.enumerated()), id: \.element.id) { index, player in
                        HStack {
                            Text("\(index + 1)")
                                .frame(width: 44, alignment: .leading)
                            Spacer()
                            Text(player.displayName.uppercased())
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Spacer()
                            Text(Self.formatScore(player.averageScore))
                                .frame(minWidth: 94, alignment: .trailing)
                        }
                        .font(.titilliumBoard(17, fallbackWeight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
    }

    private var yourStandingCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("YOUR POSITION")
                .font(.titilliumBoard(16, fallbackWeight: .semibold))
                .foregroundStyle(.black)
            Text("Avg Score: \(Self.formatScore(standing.averageScore))")
                .font(.titilliumBoard(16, fallbackWeight: .regular))
                .foregroundStyle(.black)
            Text("Matches: \(standing.gamesPlayed)")
                .font(.titilliumBoard(16, fallbackWeight: .regular))
                .foregroundStyle(.black)

            if standing.gamesPlayed < minMatches {
                Text("Play \(minMatches) Arena matches this month to be ranked.")
                    .font(.titilliumBoard(15, fallbackWeight: .regular))
                    .foregroundStyle(.black.opacity(0.7))
            } else if let rank = standing.rank {
                Text("Rank: #\(rank)")
                    .font(.titilliumBoard(16, fallbackWeight: .semibold))
                    .foregroundStyle(.black)
                if rank > 50, let delta = standing.pointsToTop50, delta > 0 {
                    Text("You are \(Self.formatScore(delta)) points from Top 50.")
                        .font(.titilliumBoard(15, fallbackWeight: .regular))
                        .foregroundStyle(.black.opacity(0.8))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let top = leaderboardService.fetchTopPlayers(monthKey: monthKey, limit: 50, minMatches: minMatches)
            async let me = leaderboardService.fetchPlayerStanding(monthKey: monthKey, playerID: playerID, minMatches: minMatches)
            topPlayers = try await top
            standing = try await me
        } catch {
            topPlayers = []
        }
    }

    private static func formatScore(_ value: Double) -> String {
        "\(Int(value.rounded()))"
    }
}
