import SwiftUI

struct DifficultySelectionView: View {
    let onSelect: (SudokuDifficulty) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Select Difficulty")
                .font(.vonique(48, fallbackWeight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            ForEach(SudokuDifficulty.allCases) { difficulty in
                Button {
                    onSelect(difficulty)
                } label: {
                    HStack(spacing: 0) {
                        Spacer()
                        Text(difficulty.title)
                            .font(.vonique(42, fallbackWeight: .regular))
                            .foregroundStyle(AppTheme.textPrimary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }
}
