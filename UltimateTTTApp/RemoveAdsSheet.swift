import SwiftUI

struct RemoveAdsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var purchases: PurchaseManager
    @ObservedObject var ads: AdManager

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if purchases.adsRemoved {
                        Label("Ads removed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Thanks for supporting Ultimate Tic Tac Toe. Your purchase is linked to your Apple Account.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("A one-time purchase removes banner ads. Online play and achievements remain free.")
                            .font(.subheadline)
                        if let product = purchases.product {
                            Button {
                                Task { await purchases.buyRemoveAds() }
                            } label: {
                                HStack {
                                    Label("Remove ads", systemImage: "cart")
                                    Spacer()
                                    Text(product.displayPrice)
                                }
                            }
                            .disabled(purchases.isPurchasing)
                        } else {
                            Text("Remove Ads will be available after the product is configured in App Store Connect.")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        }
                    }
                    Button("Restore purchases") {
                        Task { await purchases.restorePurchases() }
                    }
                } header: {
                    Text("Remove ads")
                }

                if ads.privacyOptionsRequired {
                    Section("Privacy") {
                        Button("Advertising privacy choices") {
                            Task { await ads.showPrivacyOptions() }
                        }
                    }
                }
                if let error = purchases.errorMessage ?? ads.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .navigationTitle("Purchases & privacy")
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
