import SwiftUI

struct GameScreenView: View {
    @StateObject private var viewModel: GameViewModel
    @State private var joinCode = ""
    @State private var borderBreathIntensity: CGFloat = 0
    @State private var borderBreathTask: Task<Void, Never>?
    private let soloMusic = SoloBackgroundMusicService.shared

    init(mode: GameMode) {
        _viewModel = StateObject(wrappedValue: GameViewModel(mode: mode))
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 16) {
                if viewModel.phase == .difficultySelection {
                    DifficultySelectionView { difficulty in
                        viewModel.selectDifficulty(difficulty)
                    }
                    Spacer()
                } else {
                    header

                    SudokuBoardView(
                        board: viewModel.board,
                        selected: viewModel.selectedPosition,
                        highlightedRows: viewModel.highlightedRows,
                        highlightedColumns: viewModel.highlightedColumns,
                        highlightedBoxes: viewModel.highlightedBoxes,
                        hiddenRow: nil,
                        hiddenColumn: nil,
                        fadedDigit: nil,
                        blackedBox: nil,
                        powerTile: nil,
                        onSelect: viewModel.selectCell
                    )
                    .frame(maxWidth: .infinity)
                    .layoutPriority(1)
                    .padding(10)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 22))

                    NumberPadView(
                        board: viewModel.board,
                        onNumberTap: viewModel.placeNumber
                    )
                    .disabled(viewModel.phase != .playing)
                    .padding(.top, 6)

                    Spacer(minLength: 0)
                }
            }
            .padding()
            .blur(radius: viewModel.phase == .ready || viewModel.phase == .gameOver || viewModel.phase == .complete ? 4 : 0)

            if viewModel.phase == .ready {
                if viewModel.mode == .solo {
                    if let countdown = viewModel.soloCountdownValue {
                        SoloCountdownOverlayView(countdown: countdown)
                    } else {
                        ProgressView()
                            .scaleEffect(1.3)
                    }
                } else {
                    ReadyOverlayView(
                        mode: viewModel.mode,
                        matchCode: viewModel.matchCode,
                        joinCode: $joinCode,
                        onCreateMatch: viewModel.createMatch,
                        onJoinMatch: { viewModel.joinMatch(code: joinCode) },
                        onGo: viewModel.goTapped
                    )
                }
            }

            if viewModel.phase == .gameOver {
                GameOverView(
                    title: "Game Over!",
                    subtitle: "You lost all 5 lives.",
                    onReset: viewModel.resetToDifficultySelection
                )
            }

            if viewModel.phase == .complete {
                GameOverView(
                    title: "Puzzle Solved",
                    subtitle: "Time: \(viewModel.timerText)",
                    onReset: viewModel.resetToDifficultySelection
                )
            }

            if viewModel.sabotageFlash {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            SiriAngelGlowOverlay(intensity: borderBreathIntensity, theme: viewModel.glowTheme)
                .ignoresSafeArea()
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.phase)
        .onChange(of: viewModel.completionPulseTrigger) { _ in
            runCompletionBreath()
        }
        .onChange(of: viewModel.phase) { newPhase in
            if newPhase == .ready {
                viewModel.startSoloCountdownIfNeeded()
            }
            if viewModel.mode == .solo {
                soloMusic.updateVolume()
            }
        }
        .onAppear {
            if viewModel.mode == .solo {
                soloMusic.startIfNeeded()
            }
        }
        .onDisappear {
            borderBreathTask?.cancel()
            if viewModel.mode == .solo {
                soloMusic.stop()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(viewModel.mode == .solo ? "SOLO" : "BATTLE")
                    .font(.vonique(30, fallbackWeight: .medium))
                    .foregroundStyle(.black)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") {
                    viewModel.resetToDifficultySelection()
                }
            }
        }
    }

    private struct SiriAngelGlowOverlay: View {
        let intensity: CGFloat
        let theme: GlowTheme

        var body: some View {
            GeometryReader { proxy in
                let cornerRadius = min(proxy.size.width, proxy.size.height) * 0.07
                let palette = paletteForTheme(theme)

                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    palette.mid,
                                    palette.mid,
                                    palette.hot,
                                    palette.hot
                                ]),
                                center: .center
                            ),
                            lineWidth: 52
                        )
                        .blur(radius: 54)
                        .opacity(1.0 * intensity)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    palette.mid,
                                    palette.hot,
                                    palette.hot
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 30
                        )
                        .blur(radius: 28)
                        .opacity(1.0 * intensity)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(palette.hot.opacity(0.96), lineWidth: 10)
                        .blur(radius: 10)
                        .opacity(1.0 * intensity)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(palette.coreWhite.opacity(0.82), lineWidth: 2.2)
                        .opacity(0.9 * intensity)
                }
                .frame(width: proxy.size.width - 2, height: proxy.size.height - 2)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            .allowsHitTesting(false)
            .opacity(intensity > 0 ? 1 : 0)
        }

        private func paletteForTheme(_ theme: GlowTheme) -> (coreWhite: Color, mid: Color, hot: Color) {
            switch theme {
            case .angel:
                return (
                    coreWhite: Color(red: 1.0, green: 0.97, blue: 0.86),
                    mid: Color(red: 0.98, green: 0.80, blue: 0.24),
                    hot: Color(red: 0.93, green: 0.62, blue: 0.02)
                )
            case .attackGreen:
                return (
                    coreWhite: Color(red: 0.88, green: 1.0, blue: 0.90),
                    mid: Color(red: 0.18, green: 0.78, blue: 0.34),
                    hot: Color(red: 0.01, green: 0.56, blue: 0.19)
                )
            case .damageRed:
                return (
                    coreWhite: Color(red: 1.0, green: 0.88, blue: 0.88),
                    mid: Color(red: 0.92, green: 0.18, blue: 0.18),
                    hot: Color(red: 0.64, green: 0.00, blue: 0.00)
                )
            }
        }
    }

    private func runCompletionBreath() {
        borderBreathTask?.cancel()
        borderBreathTask = Task { @MainActor in
            borderBreathIntensity = 0

            for _ in 0..<3 {
                if Task.isCancelled { return }
                withAnimation(.easeInOut(duration: 0.42)) {
                    borderBreathIntensity = 1.25
                }
                try? await Task.sleep(nanoseconds: 420_000_000)

                if Task.isCancelled { return }
                withAnimation(.easeInOut(duration: 0.42)) {
                    borderBreathIntensity = 0
                }
                try? await Task.sleep(nanoseconds: 420_000_000)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                if let difficulty = viewModel.difficulty {
                    Text(difficulty.title)
                        .font(.vonique(34, fallbackWeight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(viewModel.timerText)
                        .font(.vonique(56, fallbackWeight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    if viewModel.mode == .solo {
                        Text("BEST \(viewModel.soloBestTimeText)")
                            .font(.titilliumBoard(16, fallbackWeight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18))

            HStack {
                LifeIndicatorView(lives: viewModel.lives)
                Spacer()
                if viewModel.mode == .battle {
                    OpponentProgressView(
                        progress: viewModel.opponentProgress,
                        completion: viewModel.opponentCompletion
                    )
                    .frame(maxWidth: 210)
                }
            }

            if let banner = viewModel.bannerText {
                Text(banner)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
