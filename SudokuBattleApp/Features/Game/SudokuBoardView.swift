import SwiftUI

struct SudokuBoardView: View {
    let board: [SudokuCell]
    let selected: CellPosition?
    let highlightedRows: Set<Int>
    let highlightedColumns: Set<Int>
    let highlightedBoxes: Set<Int>
    let hiddenRow: Int?
    let hiddenColumn: Int?
    let fadedDigit: Int?
    let blackedBox: Int?
    let powerTile: CellPosition?
    let onSelect: (CellPosition) -> Void

    private var selectedValue: Int? {
        guard let selected else { return nil }
        let index = selected.row * 9 + selected.column
        guard board.indices.contains(index) else { return nil }
        return board[index].value
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cellSize = side / 9

            ZStack {
                VStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<9, id: \.self) { column in
                                let index = row * 9 + column
                                if board.indices.contains(index) {
                                    let cell = board[index]
                                    CellView(
                                        cell: cell,
                                        cellSize: cellSize,
                                        isSelected: selected == cell.position,
                                        isMatchingSelectedValue: selectedValue != nil && cell.value == selectedValue,
                                        isHighlighted: highlightedRows.contains(row)
                                            || highlightedColumns.contains(column)
                                            || highlightedBoxes.contains(cell.position.boxIndex),
                                        isHidden: hiddenRow == row || hiddenColumn == column,
                                        shouldFadeDigit: fadedDigit != nil && cell.value == fadedDigit,
                                        isBlackedOut: blackedBox == cell.position.boxIndex,
                                        isPowerTile: powerTile == cell.position && cell.value == nil && !cell.isGiven
                                    )
                                    .frame(width: cellSize, height: cellSize)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        onSelect(cell.position)
                                    }
                                } else {
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(width: cellSize, height: cellSize)
                                }
                            }
                        }
                    }
                }

                GridLinesView(side: side)
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.35), lineWidth: 1)
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct CellView: View {
    let cell: SudokuCell
    let cellSize: CGFloat
    let isSelected: Bool
    let isMatchingSelectedValue: Bool
    let isHighlighted: Bool
    let isHidden: Bool
    let shouldFadeDigit: Bool
    let isBlackedOut: Bool
    let isPowerTile: Bool

    private let matchCyan = Color(red: 0.52, green: 0.82, blue: 0.88)
    private let selectedCyan = Color(red: 0.40, green: 0.76, blue: 0.84)

    var body: some View {
        ZStack {
            Rectangle()
                .fill(backgroundColor)
                .overlay(
                    Rectangle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                )
                .overlay(
                    Rectangle()
                        .stroke(Color.red.opacity(isPowerTile && isSelected ? 0.9 : 0), lineWidth: 2.2)
                )
                .animation(.easeInOut(duration: 0.15), value: cell.value)

            Text(cell.value.map(String.init) ?? "")
                .font(.titilliumBoard(cellSize * 0.70, fallbackWeight: cell.isGiven ? .medium : .regular))
                .foregroundColor(cell.isGiven ? AppTheme.textPrimary : AppTheme.textPrimary.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .scaleEffect(cell.value == nil ? 0.8 : 1)
                .opacity(isHidden ? 0 : (shouldFadeDigit ? 0.25 : 1.0))
                .animation(.spring(response: 0.2, dampingFraction: 0.65), value: cell.value)
        }
    }

    private var backgroundColor: Color {
        if isBlackedOut { return Color.black }
        if isPowerTile { return Color(red: 0.85, green: 0.78, blue: 0.0).opacity(0.65) }
        // Selected-number matching must stay visible even inside completed rows/cols/boxes.
        if isSelected { return selectedCyan.opacity(0.45) }
        if isMatchingSelectedValue { return matchCyan.opacity(0.34) }
        if isHighlighted { return Color.black.opacity(0.08) }
        return Color.white.opacity(0.7)
    }
}

private struct GridLinesView: View {
    let side: CGFloat

    var body: some View {
        Canvas { context, _ in
            let cell = side / 9

            for i in 1..<9 {
                let offset = CGFloat(i) * cell
                let lineWidth: CGFloat = (i % 3 == 0) ? 1.8 : 0.6
                let color: Color = (i % 3 == 0) ? .gray.opacity(0.75) : .gray.opacity(0.30)

                var vertical = Path()
                vertical.move(to: CGPoint(x: offset, y: 0))
                vertical.addLine(to: CGPoint(x: offset, y: side))
                context.stroke(vertical, with: .color(color), lineWidth: lineWidth)

                var horizontal = Path()
                horizontal.move(to: CGPoint(x: 0, y: offset))
                horizontal.addLine(to: CGPoint(x: side, y: offset))
                context.stroke(horizontal, with: .color(color), lineWidth: lineWidth)
            }
        }
        .allowsHitTesting(false)
    }
}
