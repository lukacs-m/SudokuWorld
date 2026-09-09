import Foundation
import Model
import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif

/// Settings: input preferences, assistance toggles, notifications, themes,
/// Game Center status, and purchases (paywall + restore).
struct SettingsView: View {
    // TODO: replace with the real App Store ID before release.
    private static let appStoreReviewURL =
        URL(string: "https://apps.apple.com/app/id0000000000?action=write-review")!

    @State private var viewModel = SettingsViewModel()
    @State private var showPaywall = false

    @Environment(ThemeStore.self) private var themeStore
    @Environment(PremiumGate.self) private var premiumGate
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        List {
            if viewModel.isLoaded {
                premiumSection(theme: theme)
                inputSection(theme: theme)
                assistanceSection(theme: theme)
                notificationSection(theme: theme)
                themeSection(theme: theme)
                gameCenterSection(theme: theme)
                #if DEBUG
                    debugSection
                #endif
                aboutSection(theme: theme)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.screenBackground)
        .navigationTitle(Text("settings.title", bundle: .module))
        .task { await viewModel.load() }
        .task { await viewModel.observeAuthState() }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Sections

    private func inputSection(theme _: Theme) -> some View {
        Section {
            Picker(selection: Binding(
                get: { viewModel.settings.inputMode },
                set: { newValue in viewModel.update { $0.inputMode = newValue } },
            )) {
                Text("settings.input.cellFirst", bundle: .module)
                    .tag(InputMode.cellFirst)
                Text("settings.input.digitFirst", bundle: .module)
                    .tag(InputMode.digitFirst)
            } label: {
                Text("settings.input.mode", bundle: .module)
            }

            toggle("settings.timerVisible", value: \.timerVisible)
            toggle("settings.haptics", value: \.hapticsEnabled)
        } header: {
            Text("settings.section.game", bundle: .module)
        }
    }

    private func assistanceSection(theme _: Theme) -> some View {
        Section {
            toggle("settings.autoCleanNotes", value: \.autoCleanNotes)
            toggle("settings.mistakeHighlighting", value: \.mistakeHighlighting)
            toggle("settings.autoCheck", value: \.autoCheck)
            toggle("settings.hardcoreDefault", value: \.hardcoreByDefault)
            NavigationLink {
                LearnView()
            } label: {
                Label {
                    Text("settings.learn", bundle: .module)
                } icon: {
                    Image(systemName: "graduationcap")
                }
            }
        } header: {
            Text("settings.section.assistance", bundle: .module)
        } footer: {
            Text("settings.hardcore.footer", bundle: .module)
        }
    }

    private func notificationSection(theme _: Theme) -> some View {
        Section {
            Toggle(isOn: Binding(
                get: { viewModel.notifications.dailyReminderEnabled },
                set: { newValue in
                    Task {
                        await viewModel.updateNotifications { $0.dailyReminderEnabled = newValue }
                    }
                },
            )) {
                Text("settings.notification.daily", bundle: .module)
            }
            Toggle(isOn: Binding(
                get: { viewModel.notifications.streakReminderEnabled },
                set: { newValue in
                    Task {
                        await viewModel.updateNotifications { $0.streakReminderEnabled = newValue }
                    }
                },
            )) {
                Text("settings.notification.streak", bundle: .module)
            }
            if viewModel.notifications.dailyReminderEnabled {
                Picker(selection: Binding(
                    get: { viewModel.notifications.reminderHour },
                    set: { newValue in
                        Task {
                            await viewModel.updateNotifications { $0.reminderHour = newValue }
                        }
                    },
                )) {
                    ForEach(0 ..< 24, id: \.self) { hour in
                        Text(String(format: "%02d:00", hour)).tag(hour)
                    }
                } label: {
                    Text("settings.notification.hour", bundle: .module)
                }
            }
        } header: {
            Text("settings.section.notifications", bundle: .module)
        } footer: {
            if viewModel.notificationsDenied {
                Text("settings.notification.denied", bundle: .module)
                    .foregroundStyle(themeStore.theme(for: colorScheme).conflict)
            }
        }
    }

    private func themeSection(theme _: Theme) -> some View {
        Section {
            Picker(selection: Binding(
                get: { viewModel.settings.appearance ?? .system },
                set: { newValue in
                    viewModel.update { $0.appearance = newValue }
                    themeStore.selectAppearance(newValue)
                },
            )) {
                Text("settings.appearance.light", bundle: .module)
                    .tag(AppearancePreference.light)
                Text("settings.appearance.dark", bundle: .module)
                    .tag(AppearancePreference.dark)
                Text("settings.appearance.system", bundle: .module)
                    .tag(AppearancePreference.system)
            } label: {
                Text("settings.appearance", bundle: .module)
            }
            .pickerStyle(.segmented)

            ThemePickerView(
                selected: viewModel.settings.theme,
                isPremium: premiumGate.isPremium,
                onSelect: { id in
                    if viewModel.selectTheme(id, isPremium: premiumGate.isPremium) {
                        themeStore.select(id)
                    }
                },
                onLocked: { showPaywall = true },
            )
            .padding(.vertical, 6)
        } header: {
            Text("settings.section.theme", bundle: .module)
        }
    }

    private func gameCenterSection(theme: Theme) -> some View {
        Section {
            switch viewModel.authState {
            case let .authenticated(playerName):
                Label {
                    Text(playerName)
                } icon: {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .foregroundStyle(theme.success)
                }

            case .authenticating:
                HStack {
                    ProgressView()
                    Text("settings.gameCenter.connecting", bundle: .module)
                        .foregroundStyle(theme.textSecondary)
                }

            default:
                Button {
                    Task { await viewModel.signInToGameCenter() }
                } label: {
                    Label {
                        Text("settings.gameCenter.signIn", bundle: .module)
                    } icon: {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                    }
                }
            }
        } header: {
            Text("settings.section.gameCenter", bundle: .module)
        }
    }

    private func premiumSection(theme: Theme) -> some View {
        Section {
            if premiumGate.isPremium {
                Label {
                    Text("paywall.active", bundle: .module)
                } icon: {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(theme.accent)
                }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    Label {
                        Text("settings.premium.upgrade", bundle: .module)
                    } icon: {
                        Image(systemName: "crown")
                    }
                }
            }
            Button {
                Task { await viewModel.restore() }
            } label: {
                HStack {
                    Label {
                        Text("paywall.restore", bundle: .module)
                    } icon: {
                        Image(systemName: "arrow.clockwise")
                    }
                    if viewModel.restorePhase == .restoring {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(viewModel.restorePhase == .restoring)
            if let supportID = viewModel.purchasesUserID {
                SupportIDRow(supportID: supportID, theme: theme)
            }
        } header: {
            Text("settings.section.premium", bundle: .module)
        } footer: {
            let feedback = viewModel.restorePhase.footerFeedback(theme: theme)
            // An always-present VStack would give the section a blank footer
            // (and its insets) when neither line has anything to say.
            if feedback != nil || viewModel.purchasesUserID != nil {
                VStack(alignment: .leading, spacing: 4) {
                    if let feedback {
                        Text(feedback.key, bundle: .module)
                            .foregroundStyle(feedback.color)
                    }
                    if viewModel.purchasesUserID != nil {
                        Text("settings.support.footer", bundle: .module)
                    }
                }
            }
        }
    }

    #if DEBUG
        private var debugSection: some View {
            Section {
                NavigationLink {
                    DebugMenuView()
                } label: {
                    Label {
                        Text("home.debug", bundle: .module)
                    } icon: {
                        Image(systemName: "hammer")
                    }
                }
            }
        }
    #endif

    private func aboutSection(theme: Theme) -> some View {
        Section {
            Link(destination: Self.appStoreReviewURL) {
                Label {
                    Text("settings.rate", bundle: .module)
                } icon: {
                    Image(systemName: "star")
                }
            }
        } footer: {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            Text(
                String(
                    format: String(localized: "settings.version", bundle: .module),
                    version ?? "—",
                ),
            )
            .font(.caption)
            .foregroundStyle(theme.textSecondary)
            .frame(maxWidth: .infinity)
        }
    }

    private func toggle(
        _ titleKey: LocalizedStringKey,
        value keyPath: WritableKeyPath<GameSettings, Bool>,
    ) -> some View {
        Toggle(isOn: Binding(
            get: { viewModel.settings[keyPath: keyPath] },
            set: { newValue in viewModel.update { $0[keyPath: keyPath] = newValue } },
        )) {
            Text(titleKey, bundle: .module)
        }
    }
}

private extension SettingsViewModel.RestorePhase {
    /// The premium footer's only source of truth for restore feedback: nil
    /// means the phase has nothing to say, so the footer collapses.
    func footerFeedback(theme: Theme) -> (key: LocalizedStringKey, color: Color)? {
        switch self {
        case .restored: ("paywall.restored", theme.success)
        case .nothingToRestore: ("paywall.nothingToRestore", .secondary)
        case .failed: ("paywall.restoreFailed", theme.conflict)
        case .idle, .restoring: nil
        }
    }
}

/// The RevenueCat app user ID a player quotes to support; tapping copies it.
private struct SupportIDRow: View {
    let supportID: String
    let theme: Theme

    @State private var copied = false
    @State private var copiedResetTask: Task<Void, Never>?

    var body: some View {
        Button {
            copy()
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("settings.support.id", bundle: .module)
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        if copied {
                            Text("settings.support.copied", bundle: .module)
                                .font(.caption)
                                .foregroundStyle(theme.success)
                        } else {
                            Image(systemName: "doc.on.doc")
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                    Text(supportID)
                        .font(.caption.monospaced())
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            } icon: {
                Image(systemName: "person.text.rectangle")
            }
        }
        .accessibilityLabel(Text("settings.support.id", bundle: .module))
        .accessibilityValue(supportID)
    }

    private func copy() {
        #if canImport(UIKit)
            UIPasteboard.general.string = supportID
        #endif
        withAnimation { copied = true }
        AccessibilityNotification
            .Announcement(String(localized: "settings.support.copied", bundle: .module))
            .post()
        copiedResetTask?.cancel()
        copiedResetTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation { copied = false }
        }
    }
}
