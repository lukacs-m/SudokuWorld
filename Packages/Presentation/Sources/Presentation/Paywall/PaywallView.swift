import Common
import Foundation
import Model
import SwiftUI

/// The Premium paywall: benefits, products (subscription + lifetime), and
/// restore. Shows a graceful unavailable state when purchases are not
/// configured (placeholder API key) — the app remains fully playable.
struct PaywallView: View {
    @State private var viewModel = PaywallViewModel()
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
                benefit("paywall.benefit.noAds", systemImage: "rectangle.slash", theme: theme)
                benefit("paywall.benefit.hints", systemImage: "lightbulb.fill", theme: theme)
                benefit("paywall.benefit.themes", systemImage: "paintpalette.fill", theme: theme)
                benefit("paywall.benefit.stats", systemImage: "chart.bar.fill", theme: theme)
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
        }
    }

    private func products(_ offerings: PaywallOfferings, theme: Theme) -> some View {
        VStack(spacing: 10) {
            ForEach(offerings.products) { product in
                Button {
                    Task { await viewModel.purchase(productID: product.id) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.textPrimary)
                            Text(kindLabel(product.kind))
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                        Spacer()
                        Text(product.priceText)
                            .font(.headline)
                            .foregroundStyle(theme.accent)
                    }
                    .padding(14)
                    .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(theme.accent.opacity(0.4), lineWidth: 1),
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.purchasePhase == .purchasing)
            }
            if viewModel.purchasePhase == .purchasing {
                ProgressView()
            }
        }
    }

    private func kindLabel(_ kind: PaywallProduct.Kind) -> String {
        switch kind {
        case let .subscription(period):
            // Interpolating inside a LocalizationValue literal turns the key
            // into "paywall.period.%@" — build the key as a String first.
            moduleString("paywall.period.\(period)")

        case .lifetime:
            String(localized: "paywall.lifetime", bundle: .module)
        }
    }
}
