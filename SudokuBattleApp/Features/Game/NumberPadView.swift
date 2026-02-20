import SwiftUI

struct NumberPadView: View {
    let board: [SudokuCell]
    let onNumberTap: (Int) -> Void

    private var completedDigits: Set<Int> {
        var counts: [Int: Int] = [:]
        for value in board.compactMap(\.value) {
            counts[value, default: 0] += 1
        }
        return Set((1...9).filter { counts[$0, default: 0] >= 9 })
    }

    var body: some View {
        GeometryReader { proxy in
            let buttonWidth = max((proxy.size.width - (8 * 8)) / 9, 28)

            HStack(spacing: 8) {
                ForEach(1...9, id: \.self) { number in
                    let isCompleted = completedDigits.contains(number)
                    Button("\(number)") {
                        onNumberTap(number)
                    }
                    .font(.vonique(38, fallbackWeight: .regular))
                    .frame(width: buttonWidth, height: 56)
                    .foregroundColor(AppTheme.textPrimary)
                    .background(Color.white.opacity(0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
                    .opacity(isCompleted ? 0.3 : 1.0)
                    .disabled(isCompleted)
                }
            }
        }
        .frame(height: 56)
        .padding(.top, 4)
    }
}
