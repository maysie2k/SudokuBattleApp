import SwiftUI

struct RootMenuView: View {
    @State private var topArenaPlayers: [ArenaPlayerMonthlyStats] = []
    @State private var isLoadingLeaderboard = false
    @State private var leaderboardMonthKey = ArenaLeaderboardMonth.currentKey()
    private let leaderboardService: ArenaLeaderboardServiceProtocol = ArenaLeaderboardService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Text("Sudoku Arena")
                    .font(.vonique(58, fallbackWeight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .tracking(0.8)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 6)

                NavigationLink {
                    GameScreenView(mode: .solo)
                } label: {
                    Text("Solo")
                        .font(.vonique(30, fallbackWeight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                }

                NavigationLink {
                    ArenaBattleView()
                } label: {
                    Text("Arena Battle")
                        .font(.vonique(30, fallbackWeight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                }
                .padding(.bottom, 2)

                NavigationLink {
                    ArenaLeaderboardView(
                        monthKey: leaderboardMonthKey,
                        playerID: ArenaIdentity.stablePlayerID(),
                        minMatches: 2,
                        leaderboardService: leaderboardService
                    )
                } label: {
                    VStack(spacing: 8) {
                        Text("GLOBAL ARENA LEADERBOARD")
                            .font(.vonique(22, fallbackWeight: .regular))
                            .foregroundStyle(.black)

                        Text(ArenaLeaderboardMonth.displayName(for: leaderboardMonthKey))
                            .font(.titilliumBoard(14, fallbackWeight: .semibold))
                            .foregroundStyle(.black.opacity(0.75))

                        HStack {
                            Text("PLACE")
                            Spacer()
                            Text("PLAYER")
                            Spacer()
                            Text("AVG SCORE")
                        }
                        .font(.vonique(14, fallbackWeight: .semibold))
                        .foregroundStyle(.black)
                        .underline()

                        if isLoadingLeaderboard {
                            ProgressView()
                                .padding(.vertical, 10)
                        } else {
                            ForEach(Array(topArenaPlayers.enumerated()), id: \.element.id) { index, player in
                                HStack {
                                    Text("\(index + 1)")
                                        .frame(width: 38, alignment: .leading)
                                    Spacer()
                                    Text(player.displayName.uppercased())
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Spacer()
                                    Text(Self.formatScore(player.averageScore))
                                        .frame(minWidth: 72, alignment: .trailing)
                                }
                                .font(.titilliumBoard(16, fallbackWeight: .semibold))
                                .foregroundStyle(.black)
                                .opacity(opacityForRow(index))
                            }
                        }

                        if topArenaPlayers.isEmpty, !isLoadingLeaderboard {
                            Text("No ranked Arena players yet")
                                .font(.titilliumBoard(14, fallbackWeight: .regular))
                                .foregroundStyle(.black.opacity(0.7))
                        }

                        Text("Tap to view Top 50")
                            .font(.titilliumBoard(13, fallbackWeight: .regular))
                            .foregroundStyle(.black.opacity(0.6))
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(24)
            .background(AppTheme.background.ignoresSafeArea())
            .task {
                leaderboardMonthKey = ArenaLeaderboardMonth.currentKey()
                await loadArenaLeaderboard()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        HelpView()
                    } label: {
                        Image(systemName: "questionmark")
                            .font(.system(size: 20, weight: .semibold))
                    }
                    .tint(.black)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20, weight: .medium))
                    }
                    .tint(.black)
                }
            }
        }
    }

    private func loadArenaLeaderboard() async {
        isLoadingLeaderboard = true
        defer { isLoadingLeaderboard = false }

        do {
            topArenaPlayers = try await leaderboardService.fetchTopPlayers(
                monthKey: leaderboardMonthKey,
                limit: 5,
                minMatches: 2
            )
        } catch {
            topArenaPlayers = []
        }
    }

    private func opacityForRow(_ index: Int) -> Double {
        switch index {
        case 3:
            return 0.65
        case 4:
            return 0.34
        default:
            return 1.0
        }
    }

    private static func formatScore(_ value: Double) -> String {
        "\(Int(value.rounded()))"
    }
}
