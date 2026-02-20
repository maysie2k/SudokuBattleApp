import SwiftUI

struct HelpView: View {
    private enum SectionAnchor: String, CaseIterable {
        case sudoku
        case soloPlay
        case arenaBattle
        case scoringSystem
        case strategyTips
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("HELP")
                        .font(.vonique(40, fallbackWeight: .medium))
                        .foregroundStyle(.black)

                    Text("SUDOKU ARENA - HELP & GAME GUIDE")
                        .font(.titilliumBoard(24, fallbackWeight: .semibold))
                        .foregroundStyle(.black)

                    Text("Welcome to Sudoku Arena - a fast-paced twist on classic Sudoku, featuring Solo challenges and real-time Arena Battles.")
                        .font(.titilliumBoard(17, fallbackWeight: .regular))
                        .foregroundStyle(.black)
                        .fixedSize(horizontal: false, vertical: true)

                    indexBar(proxy: proxy)

                    divider

                    sectionHeader("The Basics of Sudoku", id: .sudoku)
                    paragraph("Sudoku is played on a 9x9 grid.")
                    paragraph("Your objective:")
                    bullet("Fill every empty cell with a number from 1 to 9")
                    bullet("Each number must appear once per row")
                    bullet("Each number must appear once per column")
                    bullet("Each number must appear once per 3x3 box")
                    paragraph("No duplicates are allowed in any row, column, or box.")
                    paragraph("Logic wins. Guessing usually costs you.")

                    divider

                    sectionHeader("Solo Play", id: .soloPlay)
                    paragraph("Choose your difficulty:")
                    bullet("Simple - 29 empty cells")
                    bullet("Medium - 40 empty cells")
                    bullet("Hard - 46 empty cells")
                    bullet("Master - 55 empty cells")
                    paragraph("After selecting a difficulty:")
                    bullet("A short countdown begins")
                    bullet("The board unlocks and the challenge starts")

                    subHeader("Goal")
                    paragraph("Fill all empty cells correctly to complete the puzzle.")

                    subHeader("Lives System")
                    bullet("You start with 5 lives")
                    bullet("Each incorrect placement removes 1 life")
                    bullet("At 0 lives, the game ends")
                    paragraph("Accuracy matters.")

                    subHeader("Input Rules")
                    bullet("Select a cell")
                    bullet("Tap a number (1-9)")
                    bullet("Illegal or incorrect moves are rejected and count as mistakes")

                    subHeader("Visual Guidance")
                    bullet("Selected cell is highlighted")
                    bullet("Matching numbers can be highlighted")
                    bullet("Completed rows, columns, and 3x3 boxes are highlighted")
                    bullet("Number tiles fade once all 9 placements are complete")

                    subHeader("End States")
                    bullet("Puzzle completed -> Win screen and leaderboard update")
                    bullet("No lives left -> Game Over with reset option")

                    subHeader("Solo Leaderboard")
                    paragraph("Tracks top performances by difficulty.")
                    paragraph("Higher scores rank higher.")

                    divider

                    sectionHeader("Arena Battle (2-Player Real-Time)", id: .arenaBattle)
                    paragraph("Arena Battle is competitive Sudoku.")

                    subHeader("Matchmaking")
                    bullet("Tap Arena Battle")
                    bullet("You are automatically matched with another live player")
                    bullet("No invite code required")

                    subHeader("Shared Start")
                    bullet("Both players receive the same puzzle")
                    bullet("A synchronized countdown runs")
                    bullet("Boards unlock at the same time")

                    subHeader("Goal")
                    paragraph("Be the first to complete your board.")
                    paragraph("Speed wins the match.")
                    paragraph("Performance determines your score.")

                    subHeader("Live Synced Elements")
                    bullet("Squares remaining")
                    bullet("Power Push progress and triggers")
                    bullet("Punishment effects")
                    bullet("Emotes")
                    bullet("Match result")

                    subHeader("Power Push Meter")
                    paragraph("Power Push uses a 10-segment meter.")
                    bullet("Each correct placement fills 1 segment")
                    bullet("At 10/10, a random punishment is sent to your opponent")
                    bullet("After triggering, the meter resets to 0")
                    bullet("Any wrong placement resets the meter to 0")

                    subHeader("Possible Punishments")
                    bullet("Temporary input lock")
                    bullet("Hide a row or column")
                    bullet("Remove filled numbers (must re-enter)")
                    bullet("Fade a number set")
                    bullet("Black out a 3x3 box briefly")

                    subHeader("Wrong Entry Behavior")
                    bullet("There is no strike counter or pause lock from mistakes")
                    bullet("Wrong entries still hurt score and break Power Push progress")

                    subHeader("Emotes")
                    paragraph("Send quick animated reactions during battle.")
                    paragraph("Strategic or playful - your choice.")

                    subHeader("Arena End State")
                    paragraph("First player to complete the board wins.")
                    bullet("Winner sees YOU WIN")
                    bullet("Opponent sees YOU LOSE")

                    divider

                    sectionHeader("Scoring System", id: .scoringSystem)
                    paragraph("Winning a match is about finishing first.")
                    paragraph("Your leaderboard score reflects your average score on how well you played.")
                    paragraph("Score per game is based on:")
                    bullet("How much of the board you completed")
                    bullet("How quickly you solved")
                    bullet("How many mistakes you made")
                    bullet("Your longest streak of correct placements")

                    subHeader("What This Means")
                    bullet("Completing the board gives the strongest score boost")
                    bullet("Faster solving increases your score")
                    bullet("Fewer mistakes improve your rank")
                    bullet("Long clean streaks add bonus value")
                    bullet("A controlled, accurate solve can outscore a rushed, mistake-heavy win")
                    paragraph("Speed wins battles.")
                    paragraph("Skill wins leaderboards.")

                    divider

                    sectionHeader("Strategy Tips", id: .strategyTips)
                    bullet("Avoid reckless guessing - errors reduce your score")
                    bullet("Maintain streaks for bonus performance value")
                    bullet("In Arena, balance aggression with control")
                    bullet("Build Power Push steadily - avoid risky resets")

                    divider
                    paragraph("Welcome to Sudoku Arena.")
                    paragraph("Solve fast.")
                    paragraph("Solve clean.")
                    paragraph("Solve smarter than your opponent.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func indexBar(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SECTIONS")
                .font(.titilliumBoard(18, fallbackWeight: .semibold))
                .foregroundStyle(.black)

            HStack(spacing: 8) {
                indexButton("Sudoku", anchor: .sudoku, proxy: proxy)
                indexButton("Solo Play", anchor: .soloPlay, proxy: proxy)
            }
            HStack(spacing: 8) {
                indexButton("Arena Battle", anchor: .arenaBattle, proxy: proxy)
                indexButton("Scoring System", anchor: .scoringSystem, proxy: proxy)
            }
            HStack(spacing: 8) {
                indexButton("Strategy Tips", anchor: .strategyTips, proxy: proxy)
            }
        }
    }

    private func indexButton(_ title: String, anchor: SectionAnchor, proxy: ScrollViewProxy) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.28)) {
                proxy.scrollTo(anchor.rawValue, anchor: .top)
            }
        } label: {
            Text(title)
                .font(.titilliumBoard(15, fallbackWeight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.72))
                .clipShape(Capsule())
        }
    }

    private func sectionHeader(_ title: String, id: SectionAnchor) -> some View {
        Text(title)
            .font(.titilliumBoard(24, fallbackWeight: .semibold))
            .foregroundStyle(.black)
            .id(id.rawValue)
    }

    private func subHeader(_ title: String) -> some View {
        Text(title)
            .font(.titilliumBoard(19, fallbackWeight: .semibold))
            .foregroundStyle(.black)
            .padding(.top, 4)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.titilliumBoard(17, fallbackWeight: .regular))
            .foregroundStyle(.black)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.titilliumBoard(17, fallbackWeight: .regular))
            Text(text)
                .font(.titilliumBoard(17, fallbackWeight: .regular))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.black)
    }

    private var divider: some View {
        Rectangle()
            .fill(.black.opacity(0.14))
            .frame(height: 1)
            .padding(.vertical, 2)
    }
}
