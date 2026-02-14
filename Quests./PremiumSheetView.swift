import SwiftUI

struct PremiumSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchaseManager: PurchaseManager

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(LocalizedStringKey("premium_title"))
                    .font(.title2)
                    .fontWeight(.bold)

                Text(LocalizedStringKey("premium_subtitle"))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Label(LocalizedStringKey("premium_feature_recurrence"), systemImage: "repeat")
                    Label(LocalizedStringKey("premium_feature_icons"), systemImage: "paintpalette")
                    Label(LocalizedStringKey("premium_feature_more"), systemImage: "sparkles")
                }
                .font(.subheadline)

                Text(String(format: NSLocalizedString("premium_price_format", comment: ""), purchaseManager.localizedPrice))
                    .font(.headline)

                Button {
                    Task { await purchaseManager.purchaseLifetime() }
                } label: {
                    HStack {
                        if purchaseManager.isPurchaseInProgress {
                            ProgressView()
                        }
                        Text(LocalizedStringKey("premium_buy_button"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(purchaseManager.isPurchaseInProgress || purchaseManager.isPremiumUnlocked)

                Button(LocalizedStringKey("premium_restore_button")) {
                    Task { await purchaseManager.restorePurchases() }
                }
                .buttonStyle(.bordered)

                if purchaseManager.isPremiumUnlocked {
                    Text(LocalizedStringKey("premium_unlocked"))
                        .foregroundStyle(.green)
                }

                if let error = purchaseManager.purchaseErrorMessage, !error.isEmpty {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .padding()
            .navigationTitle(Text("premium_nav_title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("close")) { dismiss() }
                }
            }
        }
    }
}

