import SwiftUI

struct StreamingIndicator: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(themeManager.colors.textTertiary)
                    .frame(width: 5, height: 5)
                    .offset(y: animating ? -3 : 3)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .task {
            animating = false
            try? await Task.sleep(nanoseconds: 50_000_000)
            animating = true
        }
    }
}
