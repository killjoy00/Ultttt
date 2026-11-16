import SwiftUI
import UIKit
import GoogleMobileAds
import UserMessagingPlatform

@MainActor
final class AdManager: ObservableObject {
    @Published private(set) var canShowAds = false
    @Published private(set) var privacyOptionsRequired = false
    @Published var errorMessage: String?

    private var isPreparing = false
    private var didStart = false

    /// Google UMP is checked each app launch before the first ad request.
    func prepare() async {
        guard !isPreparing else { return }
        isPreparing = true
        defer { isPreparing = false }

        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
        privacyOptionsRequired =
            ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        if ConsentInformation.shared.canRequestAds {
            if !didStart {
                MobileAds.shared.start()
                didStart = true
            }
            canShowAds = true
        } else {
            canShowAds = false
        }
    }

    func showPrivacyOptions() async {
        guard privacyOptionsRequired else { return }
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
            canShowAds = ConsentInformation.shared.canRequestAds
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct AdBanner: UIViewRepresentable {
    // These are Google's OFFICIAL TEST IDs. Replace both IDs before release.
    private let bannerUnitID = "ca-app-pub-3940256099942544/2435281174"

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = bannerUnitID
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        banner.rootViewController = window?.rootViewController
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}
