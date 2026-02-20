import SwiftUI

struct OpponentProgressView: View {
    let progress: Double
    let completion: CompletionState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Opponent")
                .font(.headline)

            ProgressView(value: progress)

            HStack(spacing: 10) {
                Label("R \\(completion.completedRows.count)", systemImage: "rectangle.split.3x1")
                Label("C \\(completion.completedColumns.count)", systemImage: "rectangle.split.1x3")
                Label("B \\(completion.completedBoxes.count)", systemImage: "square.grid.3x3")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
