import SwiftUI

struct LifeIndicatorView: View {
    let lives: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: index < lives ? "heart.fill" : "heart")
                    .foregroundStyle(index < lives ? .red : .gray)
            }
        }
    }
}
