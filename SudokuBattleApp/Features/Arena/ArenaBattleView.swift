import SwiftUI
import UIKit

struct ArenaBattleView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ArenaBattleViewModel()
    @State private var showEmojiTray = false
    @State private var showQuitConfirmation = false
    @State private var waitingPulse = false
    @State private var punishmentGlowPulse: CGFloat = 0
    @State private var completionGlowPulse: CGFloat = 0
    @State private var completionGlowTask: Task<Void, Never>?
    @State private var flyingEmoteToken: String?
    @State private var flyingEmoteProgress: CGFloat = 0
    @State private var flyingEmoteWobble: Double = 0
    @State private var flyingEmoteSequence = UUID()
    private let arenaMusic = ArenaBackgroundMusicService.shared

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 4) {
                if viewModel.isWaitingForOpponent {
                    waitingState
                } else if viewModel.isPreparingGame {
                    preparingState
                } else {
                    playerStats

                    SudokuBoardView(
                        board: viewModel.board,
                        selected: viewModel.selectedPosition,
                        highlightedRows: viewModel.highlightedRows,
                        highlightedColumns: viewModel.highlightedColumns,
                        highlightedBoxes: viewModel.highlightedBoxes,
                        hiddenRow: viewModel.hiddenRow,
                        hiddenColumn: viewModel.hiddenColumn,
                        fadedDigit: viewModel.fadedDigit,
                        blackedBox: viewModel.blackedBox,
                        powerTile: nil,
                        onSelect: viewModel.selectCell
                    )
                    .padding(1)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    NumberPadView(board: viewModel.board, onNumberTap: viewModel.place)
                        .disabled(viewModel.isMoveBlocked || viewModel.winnerText != nil)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
            .padding(.bottom, 8)

            if showEmojiTray {
                emojiTray
            }

            if let token = flyingEmoteToken {
                GeometryReader { proxy in
                    emoteBubble(token: token)
                        .frame(width: 70, height: 70)
                        .scaleEffect(0.55 + (0.45 * flyingEmoteProgress))
                        .rotationEffect(.degrees(flyingEmoteProgress > 0.94 ? flyingEmoteWobble : 0))
                        .position(throwPoint(in: proxy.size, progress: flyingEmoteProgress))
                }
                .allowsHitTesting(false)
            }

            if let winner = viewModel.winnerText {
                winnerOverlay(winner)
            }

            if let glowStyle = currentPunishmentGlowStyle {
                PunishmentGlowOverlay(style: glowStyle, intensity: punishmentGlowPulse)
                    .ignoresSafeArea()
            }

            if currentPunishmentGlowStyle == nil, completionGlowPulse > 0 {
                PunishmentGlowOverlay(style: .yellow, intensity: completionGlowPulse)
                    .ignoresSafeArea()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if viewModel.shouldConfirmQuitOnBack {
                        showQuitConfirmation = true
                    } else {
                        Task {
                            await viewModel.leaveFromBack()
                            dismiss()
                        }
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.92))
                        .clipShape(Circle())
                }
            }
            ToolbarItem(placement: .principal) {
                Text("ARENA BATTLE")
                    .font(.vonique(30, fallbackWeight: .medium))
                    .foregroundStyle(.black)
            }
        }
        .alert("Quit Arena Match?", isPresented: $showQuitConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Quit", role: .destructive) {
                Task {
                    await viewModel.quitCurrentMatch()
                    dismiss()
                }
            }
        } message: {
            Text("If you quit now, this match ends and your opponent will be notified.")
        }
        .onAppear {
            viewModel.onAppear()
            arenaMusic.startIfNeeded()
            arenaMusic.updateVolume()
        }
        .onDisappear {
            viewModel.onDisappear()
            arenaMusic.stop()
        }
        .onChange(of: viewModel.activePunishment?.remainingSeconds) { _ in
            updatePunishmentGlowAnimation()
        }
        .onChange(of: viewModel.completionPulseTrigger) { _ in
            runCompletionBreath()
        }
        .onChange(of: viewModel.sentEmoji) { token in
            guard let token else { return }
            runThrownEmoteAnimation(token: token)
        }
        .onChange(of: viewModel.opponentEmoji) { token in
            guard let token else { return }
            runThrownEmoteAnimation(token: token)
        }
        .onDisappear {
            completionGlowTask?.cancel()
        }
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            profileChip(title: viewModel.playerName, subtitle: "P1", image: viewModel.playerImage)
            Spacer()
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    showEmojiTray.toggle()
                }
            } label: {
                Group {
                    if let chatIconName = chatButtonAssetName {
                        Image(chatIconName)
                            .resizable()
                            .scaledToFit()
                            .padding(2)
                    } else {
                        Image(systemName: "ellipsis.bubble")
                            .font(.system(size: 28, weight: .medium))
                            .padding(2)
                    }
                }
                .frame(width: 56, height: 56)
            }
            Spacer()
            if viewModel.isWaitingForOpponent {
                Color.clear
                    .frame(width: 104, height: 128)
            } else {
                profileChip(title: viewModel.opponentName, subtitle: "P2", image: viewModel.opponentImage)
            }
        }
    }

    private var waitingState: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Waiting for another Arena player...")
                .font(.titilliumBoard(28, fallbackWeight: .medium))
                .foregroundStyle(.black)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .opacity(waitingPulse ? 1.0 : 0.7)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                waitingPulse = true
            }
        }
    }

    private var preparingState: some View {
        VStack(spacing: 14) {
            Text("Preparing Game")
                .font(.titilliumBoard(38, fallbackWeight: .medium))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)

            Text("\(viewModel.preparingCountdownValue ?? 0)")
                .font(.titilliumBoard(92, fallbackWeight: .bold))
                .foregroundStyle(.black)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var playerStats: some View {
        VStack(spacing: 3) {
            Text("SCORE")
                .font(.titilliumBoard(14, fallbackWeight: .semibold))
                .foregroundStyle(.black)
            Text("\(viewModel.liveScore)")
                .font(.vonique(54, fallbackWeight: .medium))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(alignment: .top, spacing: 22) {
                profileChip(title: viewModel.playerName, subtitle: "P1", image: viewModel.playerImage)
                powerPushDisc(progress: viewModel.powerPushSegmentsFilled, total: 10)
                profileChip(title: viewModel.opponentName, subtitle: "P2", image: viewModel.opponentImage)
            }
            .frame(maxWidth: .infinity)

            HStack(alignment: .top, spacing: 8) {
                VStack(spacing: 2) {
                    Text("SQUARES LEFT")
                        .font(.titilliumBoard(16, fallbackWeight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("\(viewModel.yourSquaresLeft)")
                        .font(.vonique(50, fallbackWeight: .medium))
                }
                .frame(maxWidth: .infinity)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        showEmojiTray.toggle()
                    }
                } label: {
                    Group {
                        if let chatIconName = chatButtonAssetName {
                            Image(chatIconName)
                                .resizable()
                                .scaledToFit()
                                .padding(1)
                        } else {
                            Image(systemName: "ellipsis.bubble")
                                .font(.system(size: 16, weight: .medium))
                                .padding(1)
                        }
                    }
                    .frame(width: 30, height: 30)
                }
                .padding(.top, 20)

                VStack(spacing: 2) {
                    Text("SQUARES LEFT")
                        .font(.titilliumBoard(16, fallbackWeight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("\(viewModel.opponentSquaresLeft)")
                        .font(.vonique(50, fallbackWeight: .medium))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var emojiTray: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                ForEach(viewModel.emojis, id: \.self) { emoji in
                    Button {
                        viewModel.sendEmoji(emoji)
                        withAnimation(.easeOut(duration: 0.2)) { showEmojiTray = false }
                    } label: {
                        if let asset = emoteAssetName(for: emoji) {
                            Image(asset)
                                .resizable()
                                .scaledToFit()
                                .padding(6)
                        } else {
                            Image(systemName: "face.smiling")
                                .font(.system(size: 28, weight: .regular))
                                .foregroundStyle(.black)
                        }
                    }
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(12)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.bottom, 140)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func emoteBubble(token: String) -> some View {
        Group {
            if let asset = emoteAssetName(for: token) {
                Image(asset)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            } else {
                Image(systemName: "face.smiling")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.black)
            }
        }
        .frame(width: 70, height: 70)
        .background(Color.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
        )
    }

    private func powerPushDisc(progress: Int, total: Int) -> some View {
        let ringSegments = max(1, total)
        let segmentFraction = 1.0 / CGFloat(ringSegments)
        let visibleSegmentFraction = segmentFraction * 0.72
        return ZStack {
            ForEach(0..<ringSegments, id: \.self) { idx in
                let start = CGFloat(idx) * segmentFraction
                let end = start + visibleSegmentFraction
                Circle()
                    .trim(from: start, to: end)
                    .stroke(
                        idx < progress ? Color(red: 0.20, green: 0.78, blue: 0.84) : Color.black.opacity(0.16),
                        style: StrokeStyle(lineWidth: 18, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(-90))
            }
            Circle()
                .fill(AppTheme.card)
                .frame(width: 86, height: 86)
                .overlay(
                    Text("POWER\nPUSH")
                        .font(.titilliumBoard(15, fallbackWeight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.black)
                )
            Circle()
                .stroke(Color.black.opacity(0.22), lineWidth: 1)
                .frame(width: 86, height: 86)
        }
        .frame(width: 122, height: 122)
    }

    private func profileChip(title: String, subtitle: String, image: UIImage?) -> some View {
        VStack(spacing: 4) {
            Circle()
                .stroke(Color.black.opacity(0.8), lineWidth: 1.6)
                .frame(width: 104, height: 104)
                .overlay {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96, height: 96)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.68, green: 0.46, blue: 0.92),
                                        Color(red: 0.86, green: 0.74, blue: 0.95)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 72, height: 72)
                    }
                }
            Text(title.uppercased())
                .font(.vonique(18, fallbackWeight: .regular))
                .lineLimit(1)
        }
    }

    private func punishmentBanner(text: String) -> some View {
        VStack {
            Text(text)
                .font(.titilliumBoard(26, fallbackWeight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.85))
                .clipShape(Capsule())
                .padding(.top, 8)
            Spacer()
        }
        .transition(.opacity)
    }

    private func winnerOverlay(_ result: String) -> some View {
        let overlayFontSize: CGFloat = result == "OPPONENT QUIT" ? 62 : 80
        return ZStack {
            Color.black.opacity(0.28).ignoresSafeArea()
            Text(result)
                .font(.vonique(overlayFontSize, fallbackWeight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(30)
                .background(Color.black.opacity(0.82))
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    private var chatButtonAssetName: String? {
        let candidates = [
            "BubbleChat",
            "BubbleChatImage",
            "Bubble Chat",
            "Bubble Chat Image",
            "Bubble",
            "ChatBubble",
            "bubble",
            "bubbleChat",
            "Bubble Icon"
        ]
        return candidates.first(where: { UIImage(named: $0) != nil })
    }

    private func emoteAssetName(for token: String) -> String? {
        let noSpace = token.replacingOccurrences(of: " ", with: "")
        let spaced = noSpace.replacingOccurrences(of: "Emoji", with: "Emoji ")
        let candidates = [token, noSpace, spaced]
        return candidates.first(where: { UIImage(named: $0) != nil })
    }

    private enum PunishmentGlowStyle {
        case red
        case yellow
    }

    private var currentPunishmentGlowStyle: PunishmentGlowStyle? {
        if let incoming = viewModel.activePunishment, incoming.remainingSeconds > 0 {
            return .red
        }
        if viewModel.outgoingPunishmentSecondsLeft > 0 {
            return .yellow
        }
        return nil
    }

    private func updatePunishmentGlowAnimation() {
        guard currentPunishmentGlowStyle != nil else {
            punishmentGlowPulse = 0
            return
        }
        punishmentGlowPulse = 0.45
        withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
            punishmentGlowPulse = 1.25
        }
    }

    private func runThrownEmoteAnimation(token: String) {
        flyingEmoteSequence = UUID()
        let sequence = flyingEmoteSequence
        flyingEmoteToken = token
        flyingEmoteProgress = 0
        flyingEmoteWobble = 0

        withAnimation(.timingCurve(0.18, 0.8, 0.24, 1.0, duration: 0.65)) {
            flyingEmoteProgress = 1
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard sequence == flyingEmoteSequence else { return }
            withAnimation(.easeOut(duration: 0.09)) { flyingEmoteWobble = 12 }
            try? await Task.sleep(nanoseconds: 90_000_000)
            withAnimation(.easeInOut(duration: 0.09)) { flyingEmoteWobble = -10 }
            try? await Task.sleep(nanoseconds: 90_000_000)
            withAnimation(.easeInOut(duration: 0.08)) { flyingEmoteWobble = 7 }
            try? await Task.sleep(nanoseconds: 80_000_000)
            withAnimation(.easeOut(duration: 0.08)) { flyingEmoteWobble = 0 }
            try? await Task.sleep(nanoseconds: 240_000_000)
            if sequence == flyingEmoteSequence {
                flyingEmoteToken = nil
            }
        }
    }

    private var incomingPunishmentText: String? {
        if let active = viewModel.activePunishment {
            return "\(active.type.rawValue) \(active.remainingSeconds)s"
        }
        if let label = viewModel.punishmentLabel {
            return label
        }
        return nil
    }

    private var outgoingPunishmentText: String? {
        guard let label = viewModel.outgoingPunishmentLabel else { return nil }
        if viewModel.outgoingPunishmentSecondsLeft > 0 {
            return "\(label) \(viewModel.outgoingPunishmentSecondsLeft)s"
        }
        return label
    }

    private func punishmentCallout(title: String, text: String?, background: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.titilliumBoard(12, fallbackWeight: .semibold))
                .foregroundStyle(.black.opacity(0.78))

            Text(text ?? " ")
                .font(.titilliumBoard(16, fallbackWeight: .semibold))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(background.opacity(text == nil ? 0.15 : 0.95))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity)
    }

    private func throwPoint(in size: CGSize, progress t: CGFloat) -> CGPoint {
        let start = CGPoint(x: size.width * 0.5, y: 122)
        let end = CGPoint(x: size.width - 54, y: 146)
        let control = CGPoint(x: size.width * 0.70, y: 42)
        let oneMinusT = 1 - t
        let baseX = oneMinusT * oneMinusT * start.x + 2 * oneMinusT * t * control.x + t * t * end.x
        let baseY = oneMinusT * oneMinusT * start.y + 2 * oneMinusT * t * control.y + t * t * end.y

        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(1, sqrt((dx * dx) + (dy * dy)))
        let normalX = -dy / length
        let normalY = dx / length

        // Looping side-to-side throw wiggle that fades out near landing.
        let loopWave = sin(Double(t) * .pi * 4.0)
        let decay = (1.0 - Double(t))
        let amplitude = CGFloat(loopWave * decay * 26.0)

        return CGPoint(
            x: baseX + normalX * amplitude,
            y: baseY + normalY * amplitude
        )
    }

    private func runCompletionBreath() {
        completionGlowTask?.cancel()
        completionGlowTask = Task { @MainActor in
            completionGlowPulse = 0

            for _ in 0..<3 {
                if Task.isCancelled { return }
                withAnimation(.easeInOut(duration: 0.42)) {
                    completionGlowPulse = 1.25
                }
                try? await Task.sleep(nanoseconds: 420_000_000)

                if Task.isCancelled { return }
                withAnimation(.easeInOut(duration: 0.42)) {
                    completionGlowPulse = 0
                }
                try? await Task.sleep(nanoseconds: 420_000_000)
            }
        }
    }

    private struct PunishmentGlowOverlay: View {
        let style: PunishmentGlowStyle
        let intensity: CGFloat

        var body: some View {
            GeometryReader { proxy in
                let cornerRadius = min(proxy.size.width, proxy.size.height) * 0.07
                let palette = paletteForStyle(style)

                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [palette.mid, palette.mid, palette.hot, palette.hot]),
                                center: .center
                            ),
                            lineWidth: 52
                        )
                        .blur(radius: 54)
                        .opacity(1.0 * intensity)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [palette.mid, palette.hot, palette.hot],
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
        }

        private func paletteForStyle(_ style: PunishmentGlowStyle) -> (coreWhite: Color, mid: Color, hot: Color) {
            switch style {
            case .red:
                return (
                    coreWhite: Color(red: 1.0, green: 0.88, blue: 0.88),
                    mid: Color(red: 0.92, green: 0.18, blue: 0.18),
                    hot: Color(red: 0.64, green: 0.00, blue: 0.00)
                )
            case .yellow:
                return (
                    coreWhite: Color(red: 1.0, green: 0.97, blue: 0.86),
                    mid: Color(red: 0.98, green: 0.80, blue: 0.24),
                    hot: Color(red: 0.93, green: 0.62, blue: 0.02)
                )
            }
        }
    }
}
