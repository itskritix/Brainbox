import SwiftUI

struct OnboardingView: View {
    @Environment(ThemeManager.self) private var themeManager
    var keychainService: KeychainService
    var onComplete: () -> Void

    @State private var currentStep: OnboardingStep = .welcome
    @State private var displayName: String = ""
    @State private var apiKeys: [String: String] = [:]

    private enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case displayName = 1
        case apiKeys = 2
        case ready = 3
    }

    var body: some View {
        let theme = themeManager.colors
        // Observe keychain changes so onboarding rows reflect real state.
        let _ = keychainService.revision

        VStack(spacing: 0) {
            Spacer()

            Group {
                switch currentStep {
                case .welcome:
                    welcomeStep(theme: theme)
                case .displayName:
                    displayNameStep(theme: theme)
                case .apiKeys:
                    apiKeysStep(theme: theme)
                case .ready:
                    readyStep(theme: theme)
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            Spacer()

            stepIndicator(theme: theme)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.backgroundPrimary)
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }

    // MARK: - Step 1: Welcome

    private func welcomeStep(theme: AppThemeColors) -> some View {
        VStack(spacing: 24) {
            Image("BrainboxLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            VStack(spacing: 10) {
                Text("Welcome to Brainbox")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(theme.textPrimary)

                Text("Your private AI assistant. Everything runs locally on your Mac — no cloud, no accounts, no tracking.")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            Button {
                currentStep = .displayName
            } label: {
                Text("Get Started")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
                    .background(theme.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.borderless)
            .padding(.top, 8)
        }
    }

    // MARK: - Step 2: Display Name

    private func displayNameStep(theme: AppThemeColors) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 48))
                .foregroundStyle(theme.accent)

            VStack(spacing: 10) {
                Text("What should we call you?")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(theme.textPrimary)

                Text("This is just for personalizing your greeting.")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.textSecondary)
            }

            TextField("Your name", text: $displayName)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(theme.textPrimary)
                .padding(12)
                .frame(width: 300)
                .background(theme.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .stroke(theme.border, lineWidth: 1)
                )
                .onSubmit {
                    // Keep validation in sync with the Continue button below.
                    if displayName.trimmingCharacters(in: .whitespaces).count >= 2 {
                        saveDisplayName()
                        currentStep = .apiKeys
                    }
                }

            HStack(spacing: 12) {
                Button {
                    currentStep = .apiKeys
                } label: {
                    Text("Skip")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.textSecondary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(theme.surfacePrimary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(theme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.borderless)

                Button {
                    saveDisplayName()
                    currentStep = .apiKeys
                } label: {
                    Text("Continue")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(displayName.trimmingCharacters(in: .whitespaces).count >= 2 ? theme.accent : theme.accent.opacity(0.4))
                        .clipShape(Capsule())
                }
                .buttonStyle(.borderless)
                .disabled(displayName.trimmingCharacters(in: .whitespaces).count < 2)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Step 3: API Keys

    private func apiKeysStep(theme: AppThemeColors) -> some View {
        // Compute once per render to avoid repeated Keychain lookups in the
        // button label below (configuredProviders iterates all providers).
        let hasAnyConfiguredProvider = !keychainService.configuredProviders.isEmpty

        return VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundStyle(theme.accent)

            VStack(spacing: 10) {
                Text("Connect Your AI Providers")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(theme.textPrimary)

                Text("Add at least one API key to start chatting. You can always add more later in Settings.")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
            }

            VStack(spacing: 0) {
                ForEach(Array(KeychainService.providers.enumerated()), id: \.element) { index, provider in
                    onboardingApiKeyRow(provider: provider, theme: theme)

                    if index < KeychainService.providers.count - 1 {
                        Rectangle()
                            .fill(theme.border.opacity(0.5))
                            .frame(height: 0.5)
                            .padding(.horizontal, 14)
                    }
                }
            }
            .background(theme.surfacePrimary.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(theme.border.opacity(0.3), lineWidth: 1)
            )
            .frame(maxWidth: 500)

            HStack(spacing: 12) {
                Button {
                    currentStep = .ready
                } label: {
                    Text(hasAnyConfiguredProvider ? "Continue" : "Skip for now")
                        .font(.system(size: 13, weight: hasAnyConfiguredProvider ? .semibold : .regular))
                        .foregroundStyle(hasAnyConfiguredProvider ? .white : theme.textSecondary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(hasAnyConfiguredProvider ? theme.accent : theme.surfacePrimary)
                        .clipShape(Capsule())
                        .overlay(
                            hasAnyConfiguredProvider
                                ? nil
                                : Capsule().stroke(theme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func onboardingApiKeyRow(provider: String, theme: AppThemeColors) -> some View {
        let displayName = KeychainService.providerDisplayName(provider)
        // Read real keychain state rather than a local cache so the row stays in
        // sync with keys configured outside this view (e.g. via Settings) and
        // with revision-driven re-renders.
        let hasKey = keychainService.hasKey(for: provider)
        let binding = Binding<String>(
            get: { apiKeys[provider] ?? "" },
            set: { apiKeys[provider] = $0 }
        )

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)

                    if hasKey {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                    }
                }

                if let url = KeychainService.providerKeyURL(provider) {
                    Link("Get API key", destination: url)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.accent)
                }
            }
            .frame(width: 90, alignment: .leading)

            SecureField("API Key", text: binding)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(theme.textPrimary)
                .padding(6)
                .background(theme.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
                .onSubmit {
                    saveApiKey(for: provider)
                }

            Button {
                saveApiKey(for: provider)
            } label: {
                Text(hasKey ? "Saved" : "Save")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(hasKey ? Color.green : theme.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.borderless)
            .disabled(hasKey && (apiKeys[provider] ?? "").isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .animation(.easeInOut(duration: 0.2), value: hasKey)
    }

    // MARK: - Step 4: Ready

    private func readyStep(theme: AppThemeColors) -> some View {
        let configuredCount = keychainService.configuredProviders.count
        let hasProviders = configuredCount > 0

        return VStack(spacing: 24) {
            Image(systemName: hasProviders ? "checkmark.circle.fill" : "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(hasProviders ? .green : theme.accent)

            VStack(spacing: 10) {
                Text(hasProviders ? "You're all set!" : "You're almost there!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(theme.textPrimary)

                if hasProviders {
                    Text("\(configuredCount) provider\(configuredCount == 1 ? "" : "s") configured. You can start chatting right away.")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                } else {
                    Text("You can add API keys or download local models anytime from Settings (\u{2318},).")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
            }

            Button {
                completeOnboarding()
            } label: {
                Text("Start Chatting")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
                    .background(theme.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.borderless)
            .padding(.top, 8)
        }
    }

    // MARK: - Step Indicator

    private func stepIndicator(theme: AppThemeColors) -> some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                Circle()
                    .fill(step == currentStep ? theme.accent : theme.surfaceSecondary)
                    .frame(width: 8, height: 8)
            }
        }
    }

    // MARK: - Actions

    private func saveDisplayName() {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        if trimmed.count >= 2 {
            UserDefaults.standard.set(trimmed, forKey: UDKey.userName)
        }
    }

    private func saveApiKey(for provider: String) {
        let key = (apiKeys[provider] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        // setAPIKey bumps keychainService.revision, which triggers a re-render
        // so rows pick up the new hasKey(for:) value automatically.
        keychainService.setAPIKey(key, for: provider)
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: UDKey.hasCompletedOnboarding)
        onComplete()
    }
}
