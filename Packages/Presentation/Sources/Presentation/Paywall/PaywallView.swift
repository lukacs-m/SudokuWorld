import Common
import Foundation
import Model
import SwiftUI

/// The Premium paywall: benefits, the three products (monthly / annual /
/// lifetime, annual pre-selected as best value), restore, and legal links.
/// Shows a graceful unavailable state when purchases are not configured —
/// the app remains fully playable. No urgency, no tricks.
struct PaywallView: View {
    // TODO: real policy URLs before release.
    private static let privacyURL = URL(string: "https://sudokuworld.app/privacy")!
    private static let termsURL = URL(string: "https://sudokuworld.app/terms")!

    @State private var viewModel = PaywallViewModel()
    @State private var selectedID: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header(theme: theme)
                    benefits(theme: theme)
                    content(theme: theme)
                }
                .padding(20)
            }
            .background(theme.screenBackground)
            .task { await viewModel.load() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.textSecondary)
                    }
                    .accessibilityLabel(Text("common.close", bundle: .module))
                }
            }
        }
    }

    private func header(theme: Theme) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 44))
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)
            Text("paywall.title", bundle: .module)
                .font(.title.weight(.bold))
                .foregroundStyle(theme.textPrimary)
            Text("paywall.subtitle", bundle: .module)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private func benefits(theme: Theme) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                benefit(
                    "paywall.benefit.variants",
                    systemImage: "square.grid.3x3.fill",
                    theme: theme,
                )
                benefit(
                    "paywall.benefit.archive",
                    systemImage: "calendar.badge.clock",
                    theme: theme,
                )
                benefit("paywall.benefit.themes", systemImage: "paintpalette.fill", theme: theme)
            }
        }
    }

    private func benefit(
        _ titleKey: LocalizedStringKey,
        systemImage: String,
        theme: Theme,
    ) -> some View {
        Label {
            Text(titleKey, bundle: .module)
                .font(.subheadline)
                .foregroundStyle(theme.textPrimary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(theme.accent)
        }
    }

    @ViewBuilder
    private func content(theme: Theme) -> some View {
        if viewModel.isPremium || viewModel.purchasePhase == .purchased
            || viewModel.purchasePhase == .restored
        {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(theme.success)
                    .accessibilityHidden(true)
                Text("paywall.active", bundle: .module)
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
            }
            .padding(.vertical, 12)
        } else {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
                    .padding(.vertical, 30)

            case let .loaded(offerings):
                products(offerings, theme: theme)

            case .empty, .failed:
                VStack(spacing: 8) {
                    Image(systemName: "cart.badge.questionmark")
                        .font(.title)
                        .foregroundStyle(theme.textSecondary)
                        .accessibilityHidden(true)
                    Text("paywall.unavailable", bundle: .module)
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 20)
            }

            if case let .failed(message) = viewModel.purchasePhase {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(theme.conflict)
            }

            Button {
                Task { await viewModel.restore() }
            } label: {
                Text("paywall.restore", bundle: .module)
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textSecondary)
            .disabled(viewModel.purchasePhase == .purchasing)

            HStack(spacing: 6) {
                Link(destination: Self.privacyURL) {
                    Text("paywall.privacy", bundle: .module)
                }
                Text("·")
                Link(destination: Self.termsURL) {
                    Text("paywall.terms", bundle: .module)
                }
            }
            .font(.caption)
            .foregroundStyle(theme.textSecondary)
        }
    }

    private func products(_ offerings: PaywallOfferings, theme: Theme) -> some View {
        VStack(spacing: 10) {
            ForEach(offerings.products) { product in
                productRow(product, theme: theme)
            }
            PrimaryButton("paywall.cta") {
                guard let selectedID else { return }
                Task { await viewModel.purchase(productID: selectedID) }
            }
            .disabled(selectedID == nil || viewModel.purchasePhase == .purchasing)
            if viewModel.purchasePhase == .purchasing {
                ProgressView()
            }
        }
        .onAppear {
            // Annual is the anchor: pre-selected, tagged best value.
            if selectedID == nil {
                selectedID = (offerings.products.first { $0.kind == .annual }
                    ?? offerings.products.first)?.id
            }
        }
    }

    private func productRow(_ product: PaywallProduct, theme: Theme) -> some View {
        let selected = product.id == selectedID
        return Button {
            selectedID = product.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(product.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)
                        if product.kind == .annual {
                            Text("paywall.bestValue", bundle: .module)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(theme.accent.opacity(0.14), in: Capsule())
                                .foregroundStyle(theme.accent)
                        }
                    }
                    Text(kindLabel(product.kind), bundle: .module)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                    if let trialDays = product.trialDays {
                        Text(
                            String(
                                format: String(localized: "paywall.trial", bundle: .module),
                                trialDays,
                            ),
                        )
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.success)
                    }
                }
                Spacer()
                Text(product.priceText)
                    .font(.headline)
                    .foregroundStyle(theme.accent)
            }
            .padding(14)
            .background(
                selected ? theme.accent.opacity(0.10) : theme.cardBackground,
                in: RoundedRectangle(cornerRadius: 14),
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        selected ? theme.accent : theme.accent.opacity(0.25),
                        lineWidth: selected ? 1.5 : 1,
                    ),
            )
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.purchasePhase == .purchasing)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func kindLabel(_ kind: PaywallProduct.Kind) -> LocalizedStringKey {
        switch kind {
        case .monthly: "paywall.kind.monthly"
        case .annual: "paywall.kind.annual"
        case .lifetime: "paywall.lifetime"
        }
    }
}
