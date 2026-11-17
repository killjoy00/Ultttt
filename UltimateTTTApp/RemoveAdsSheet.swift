import SwiftUI

struct RemoveAdsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var purchases: PurchaseManager
    @ObservedObject var ads: AdManager

    #if DEBUG
    /// Only the screenshot host can show a visual preview before StoreKit
    /// is loaded. The button is disabled and never runs a fake transaction.
    var reviewPreviewPrice: String? = nil
    #endif

    private var unavailableMessage: some View {
        Text("Purchases are unavailable right now.")
            .font(.subheadline)
            .foregroundStyle(GameStyle.muted)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GameStyle.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: purchases.adsRemoved ? "checkmark.shield.fill" : "rectangle.slash")
                        .font(.system(size: 27, weight: .medium))
                        .foregroundStyle(GameStyle.x)
                        .frame(width: 62, height: 62)
                        .background(GameStyle.surface, in: RoundedRectangle(cornerRadius: 19))

                    Text(purchases.adsRemoved ? "Ads removed" : "Play without ads.")
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .foregroundStyle(GameStyle.text)

                    Text(purchases.adsRemoved
                         ? "Your purchase is active. No banner ads will be shown."
                         : "One purchase removes banner ads for good. Every game mode stays free.")
                        .font(.body)
                        .foregroundStyle(GameStyle.muted)

                    if !purchases.adsRemoved {
                        if let product = purchases.product {
                            Button {
                                Task { await purchases.buyRemoveAds() }
                            } label: {
                                HStack {
                                    Text(purchases.isPurchasing ? "Processing…" : "Remove ads")
                                    Spacer()
                                    Text(product.displayPrice)
                                }
                                .font(.headline)
                                .foregroundStyle(GameStyle.onAccent)
                                .padding(.horizontal, 18)
                                .frame(height: 52)
                                .background(GameStyle.x, in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .disabled(purchases.isPurchasing)
                        } else {
                            #if DEBUG
                            if let reviewPreviewPrice {
                                Button {} label: {
                                    HStack {
                                        Text("Remove ads")
                                        Spacer()
                                        Text(reviewPreviewPrice)
                                    }
                                    .font(.headline)
                                    .foregroundStyle(GameStyle.onAccent)
                                    .padding(.horizontal, 18)
                                    .frame(height: 52)
                                    .background(GameStyle.x, in: RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                                // The screenshot scenario cannot initiate a purchase.
                                .allowsHitTesting(false)
                            } else {
                                unavailableMessage
                            }
                            #else
                            unavailableMessage
                            #endif
                        }
                    }

                    Button {
                        Task { await purchases.restorePurchases() }
                    } label: {
                        Text("Restore purchases")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(GameStyle.text)
                            .frame(maxWidth: .infinity)
                            .frame(height: 45)
                            .background(GameStyle.surface, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    if ads.privacyOptionsRequired {
                        Button("Advertising privacy choices") {
                            Task { await ads.showPrivacyOptions() }
                        }
                        .font(.subheadline)
                        .foregroundStyle(GameStyle.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }

                    if let error = purchases.errorMessage ?? ads.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(GameStyle.o)
                            .padding(.top, 2)
                    }
                }
                .padding(24)
            }
            .scrollIndicators(.hidden)
            .background(GameStyle.background.ignoresSafeArea())
            .navigationTitle("Remove ads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
