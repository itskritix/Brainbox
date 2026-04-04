import SwiftUI

struct MessageActionBar: View {
    @Environment(ThemeManager.self) private var themeManager
    let onCopy: () -> Void
    let onBranch: () -> Void
    let onRegenerate: (() -> Void)?
    let modelLabel: String?

    @State private var showCopied = false

    var body: some View {
        let theme = themeManager.colors

        HStack(spacing: 14) {
            // Copy
            Button {
                onCopy()
                showCopied = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    showCopied = false
                }
            } label: {
                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(showCopied ? theme.accent : theme.textTertiary)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.borderless)
            .help("Copy response")

            // Branch
            Button(action: onBranch) {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.borderless)
            .help("Branch conversation from here")

            // Regenerate (last message only)
            if let onRegenerate {
                Button(action: onRegenerate) {
                    Image(systemName: "arrow.trianglehead.2.clockwise")
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.borderless)
                .help("Regenerate response")
            }

            // Model label
            if let modelLabel, !modelLabel.isEmpty {
                Text(modelLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .font(.system(size: 12))
    }
}

struct UserMessageActionBar: View {
    @Environment(ThemeManager.self) private var themeManager
    let onCopy: () -> Void
    let onEdit: (() -> Void)?

    @State private var showCopied = false

    var body: some View {
        let theme = themeManager.colors

        HStack(spacing: 14) {
            // Edit
            if let onEdit {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.borderless)
                .help("Edit message")
            }

            // Copy
            Button {
                onCopy()
                showCopied = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    showCopied = false
                }
            } label: {
                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(showCopied ? theme.accent : theme.textTertiary)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.borderless)
            .help("Copy message")
        }
        .font(.system(size: 12))
    }
}
