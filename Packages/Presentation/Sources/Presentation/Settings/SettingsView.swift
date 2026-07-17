import Foundation
import Model
import SwiftUI

/// Settings: input preferences, assistance toggles, notifications, themes,
/// Game Center status, and purchases (paywall + restore).
struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @State private var showPaywall = false

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        List {
            if viewModel.isLoaded {
                inputSection(theme: theme)
                assistanceSection(theme: theme)
                notificationSection(theme: theme)
                themeSection(theme: theme)
                gameCenterSection(theme: theme)
                premiumSection(theme: theme)
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
                .onDisappear {
                    Task { await viewModel.refreshEntitlements() }
                }
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
            ThemePickerView(
                selected: viewModel.settings.theme,
                isPremium: viewModel.isPremium,
                onSelect: { id in
                    if viewModel.selectTheme(id) {
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
            if viewModel.isPremium {
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
        } header: {
            Text("settings.section.premium", bundle: .module)
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
