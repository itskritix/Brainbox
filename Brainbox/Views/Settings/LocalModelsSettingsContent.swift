import SwiftUI

struct LocalModelsSettingsContent: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LocalModelService.self) private var localModelService

    @State private var modelIdInput = ""
    @State private var modelToDelete: LocalModelInfo?

    var body: some View {
        let theme = themeManager.colors

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Local Models")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(theme.textPrimary)

                    Text("Download and run AI models locally on your Mac using Apple MLX. Models run entirely on-device — no API key needed.")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(.trailing, 36)

                // Error message
                if let error = localModelService.errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.error)
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .transition(.opacity)
                }

                // Download section
                settingsGroup(theme: theme) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Download Model")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.textPrimary)

                        HStack(spacing: 8) {
                            TextField("Hugging Face model ID (e.g. mlx-community/Qwen3-4B-4bit)", text: $modelIdInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(theme.textPrimary)
                                .padding(6)
                                .background(theme.surfacePrimary)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))

                            Button {
                                let id = modelIdInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !id.isEmpty else { return }
                                let name = id.components(separatedBy: "/").last ?? id
                                localModelService.downloadModel(id: id, displayName: name)
                                modelIdInput = ""
                            } label: {
                                Text("Download")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(theme.accent)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.borderless)
                            .disabled(modelIdInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }

                // Suggested models
                settingsGroup(theme: theme) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Suggested Models")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)

                        settingsDivider(theme: theme)

                        ForEach(Array(LocalModelService.suggestedModels.enumerated()), id: \.element.id) { index, model in
                            let isDownloaded = localModelService.downloadedModels.contains { $0.id == model.id }
                            let isDownloading = localModelService.activeDownloads.contains(model.id)

                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.name)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(theme.textPrimary)
                                    Text(model.size)
                                        .font(.system(size: 10))
                                        .foregroundStyle(theme.textTertiary)
                                }

                                Spacer()

                                if isDownloaded {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.green)
                                } else if isDownloading {
                                    ProgressView(value: localModelService.downloadProgress[model.id] ?? 0)
                                        .frame(width: 80)
                                } else {
                                    Button {
                                        localModelService.downloadModel(id: model.id, displayName: model.name)
                                    } label: {
                                        Text("Download")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(theme.accent)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)

                            if index < LocalModelService.suggestedModels.count - 1 {
                                settingsDivider(theme: theme)
                            }
                        }
                    }
                }

                // Active downloads
                if !localModelService.activeDownloads.isEmpty {
                    settingsGroup(theme: theme) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Downloading")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(theme.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)

                            settingsDivider(theme: theme)

                            ForEach(Array(localModelService.activeDownloads).sorted(), id: \.self) { modelId in
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(modelId.components(separatedBy: "/").last ?? modelId)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(theme.textPrimary)
                                        Text(modelId)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(theme.textTertiary)
                                    }

                                    Spacer()

                                    ProgressView(value: localModelService.downloadProgress[modelId] ?? 0)
                                        .frame(width: 100)

                                    Button {
                                        localModelService.cancelDownload(id: modelId)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 13))
                                            .foregroundStyle(theme.textTertiary)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                            }
                        }
                    }
                }

                // Downloaded models
                if !localModelService.downloadedModels.isEmpty {
                    settingsGroup(theme: theme) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Downloaded Models")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(theme.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)

                            settingsDivider(theme: theme)

                            ForEach(Array(localModelService.downloadedModels.enumerated()), id: \.element.id) { index, model in
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(model.displayName)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(theme.textPrimary)

                                        Text(model.id)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(theme.textTertiary)

                                        Text(formattedSize(model.sizeBytes))
                                            .font(.system(size: 10))
                                            .foregroundStyle(theme.textTertiary)
                                    }

                                    Spacer()

                                    Button {
                                        modelToDelete = model
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11))
                                            .foregroundStyle(theme.error)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)

                                if index < localModelService.downloadedModels.count - 1 {
                                    settingsDivider(theme: theme)
                                }
                            }
                        }
                    }

                    // Total disk usage
                    HStack {
                        Image(systemName: "internaldrive")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.textTertiary)
                        Text("Total disk usage: \(formattedSize(localModelService.totalDiskUsage))")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }
            .padding(24)
        }
        .alert("Delete Model", isPresented: Binding(
            get: { modelToDelete != nil },
            set: { if !$0 { modelToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                modelToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let model = modelToDelete {
                    localModelService.deleteModel(id: model.id)
                    modelToDelete = nil
                }
            }
        } message: {
            if let model = modelToDelete {
                Text("Are you sure you want to delete \(model.displayName)? This will remove the model files from disk.")
            }
        }
    }

    private func formattedSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
