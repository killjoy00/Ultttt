package com.killjoy00.ultttt

import android.app.Activity
import android.content.Context
import androidx.activity.ComponentActivity
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.viewinterop.AndroidView
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.AdSize
import com.google.android.gms.ads.AdView
import com.google.android.gms.ads.MobileAds
import com.google.android.ump.ConsentInformation
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform

/** One banner, below gameplay, after UMP consent and Play purchase restoration. */
class AndroidMonetization(private val activity: ComponentActivity) : PurchasesUpdatedListener {
    companion object {
        const val REMOVE_ADS_PRODUCT_ID = "com.killjoy00.ultttt.remove_ads"
        private const val PREFS_NAME = "ultttt.monetization"
        private const val OWNED_KEY = "remove_ads_owned"
    }

    private val preferences = activity.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val consent = UserMessagingPlatform.getConsentInformation(activity)
    private val billingClient = BillingClient.newBuilder(activity)
        .setListener(this)
        .enablePendingPurchases(
            PendingPurchasesParams.newBuilder().enableOneTimeProducts().build()
        )
        .enableAutoServiceReconnection()
        .build()

    var removeAdsOwned by mutableStateOf(preferences.getBoolean(OWNED_KEY, false))
        private set
    var canShowBanner by mutableStateOf(false)
        private set
    var privacyOptionsRequired by mutableStateOf(false)
        private set
    var removeAdsPrice by mutableStateOf<String?>(null)
        private set
    var purchaseMessage by mutableStateOf<String?>(null)
        private set

    private var product: ProductDetails? = null
    private var gameplayReady = false
    private var connectionStarted = false
    private var entitlementChecked = false
    private var consentRequested = false
    private var sdkInitialized = false

    /** Defer purchase lookup and consent forms until after the optional first-run tutorial. */
    fun onGameplayReady() {
        if (gameplayReady) return
        gameplayReady = true
        connectBilling()
    }

    private fun connectBilling() {
        if (connectionStarted) return
        connectionStarted = true
        billingClient.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                activity.runOnUiThread {
                    if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                        refreshPurchases()
                        loadProduct()
                    } else {
                        purchaseMessage = "Google Play purchases are temporarily unavailable."
                        // Don't request ads before a successful ownership check.
                    }
                }
            }
            override fun onBillingServiceDisconnected() {
                activity.runOnUiThread { purchaseMessage = "Google Play connection lost. Retry in Settings." }
            }
        })
    }

    fun refreshPurchases() {
        if (!gameplayReady) return
        if (!billingClient.isReady) {
            if (!connectionStarted) connectBilling()
            return
        }
        val params = QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.INAPP).build()
        billingClient.queryPurchasesAsync(params) { result, purchases ->
            activity.runOnUiThread {
                if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                    purchaseMessage = "Couldn't verify purchases. Please try again."
                    return@runOnUiThread
                }
                val owned = purchases.any {
                    REMOVE_ADS_PRODUCT_ID in it.products &&
                        it.purchaseState == Purchase.PurchaseState.PURCHASED
                }
                removeAdsOwned = owned
                preferences.edit().putBoolean(OWNED_KEY, owned).apply()
                entitlementChecked = true
                if (owned) canShowBanner = false
                purchases.filter {
                    REMOVE_ADS_PRODUCT_ID in it.products &&
                        it.purchaseState == Purchase.PurchaseState.PURCHASED
                }.forEach(::acknowledgeIfNeeded)
                requestAdConsentIfEligible()
            }
        }
    }

    private fun loadProduct() {
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(
                listOf(QueryProductDetailsParams.Product.newBuilder()
                    .setProductId(REMOVE_ADS_PRODUCT_ID)
                    .setProductType(BillingClient.ProductType.INAPP)
                    .build())
            ).build()
        billingClient.queryProductDetailsAsync(params) { result, details ->
            activity.runOnUiThread {
                product = if (result.responseCode == BillingClient.BillingResponseCode.OK)
                    details.productDetailsList.firstOrNull() else null
                removeAdsPrice = product?.oneTimePurchaseOfferDetailsList?.firstOrNull()?.formattedPrice
            }
        }
    }

    fun buyRemoveAds() {
        if (removeAdsOwned) return
        val details = product ?: run {
            purchaseMessage = "Remove Ads isn't available on Google Play yet."
            return
        }
        val offer = details.oneTimePurchaseOfferDetailsList?.firstOrNull() ?: return
        val offerToken = offer.offerToken ?: run {
            purchaseMessage = "Google Play doesn't offer this purchase yet."
            return
        }
        val productParams = BillingFlowParams.ProductDetailsParams.newBuilder()
            .setProductDetails(details)
            .setOfferToken(offerToken)
            .build()
        val flowParams = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(productParams)).build()
        val result = billingClient.launchBillingFlow(activity, flowParams)
        if (result.responseCode != BillingClient.BillingResponseCode.OK)
            purchaseMessage = "Google Play couldn't start the purchase."
    }

    override fun onPurchasesUpdated(result: BillingResult, purchases: List<Purchase>?) {
        activity.runOnUiThread {
            when (result.responseCode) {
                BillingClient.BillingResponseCode.OK -> {
                    purchases.orEmpty().filter {
                        REMOVE_ADS_PRODUCT_ID in it.products
                    }.forEach { purchase ->
                        if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED) {
                            removeAdsOwned = true
                            preferences.edit().putBoolean(OWNED_KEY, true).apply()
                            canShowBanner = false
                            acknowledgeIfNeeded(purchase)
                            purchaseMessage = "Ads removed. Thanks for supporting the game!"
                        } else if (purchase.purchaseState == Purchase.PurchaseState.PENDING) {
                            purchaseMessage = "Purchase pending. Ads will be removed once it completes."
                        }
                    }
                    refreshPurchases()
                }
                BillingClient.BillingResponseCode.USER_CANCELED -> Unit
                else -> purchaseMessage = "Google Play couldn't complete that purchase."
            }
        }
    }

    private fun acknowledgeIfNeeded(purchase: Purchase) {
        if (purchase.isAcknowledged) return
        val params = AcknowledgePurchaseParams.newBuilder()
            .setPurchaseToken(purchase.purchaseToken).build()
        billingClient.acknowledgePurchase(params) { result ->
            if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                activity.runOnUiThread {
                    purchaseMessage = "Purchase saved. Google Play acknowledgement will retry later."
                }
            }
        }
    }

    private fun requestAdConsentIfEligible() {
        if (!gameplayReady || !entitlementChecked || removeAdsOwned ||
            !BuildConfig.ADMOB_CONFIGURED || consentRequested) return
        consentRequested = true
        val request = ConsentRequestParameters.Builder().build()
        consent.requestConsentInfoUpdate(
            activity, request,
            {
                updatePrivacyOptionsRequirement()
                UserMessagingPlatform.loadAndShowConsentFormIfRequired(activity) {
                    updatePrivacyOptionsRequirement()
                    maybeEnableBanner()
                }
            },
            {
                // Previously saved consent may still be valid; UMP decides.
                updatePrivacyOptionsRequirement()
                maybeEnableBanner()
            }
        )
    }

    private fun updatePrivacyOptionsRequirement() {
        privacyOptionsRequired = consent.privacyOptionsRequirementStatus ==
            ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED
    }

    private fun maybeEnableBanner() {
        if (!consent.canRequestAds() || removeAdsOwned ||
            !entitlementChecked || !BuildConfig.ADMOB_CONFIGURED) {
            canShowBanner = false
            return
        }
        if (sdkInitialized) {
            canShowBanner = true
            return
        }
        sdkInitialized = true
        // Never initialize the ads SDK or request a banner before UMP allows requests.
        MobileAds.initialize(activity) {
            activity.runOnUiThread {
                canShowBanner = !removeAdsOwned && consent.canRequestAds()
            }
        }
    }

    fun showPrivacyOptions() {
        if (!privacyOptionsRequired) return
        UserMessagingPlatform.showPrivacyOptionsForm(activity) {
            updatePrivacyOptionsRequirement()
            maybeEnableBanner()
        }
    }

    fun close() {
        canShowBanner = false
        billingClient.endConnection()
    }
}

/** A single bottom-anchored adaptive banner outside the scrollable game board. */
@Composable
fun BottomGameBanner() {
    val context = LocalContext.current
    val density = LocalDensity.current
    var widthPixels by remember { mutableIntStateOf(0) }
    Box(
        modifier = Modifier.fillMaxWidth().onSizeChanged { widthPixels = it.width },
        contentAlignment = Alignment.Center
    ) {
        if (widthPixels > 0 && BuildConfig.ADMOB_BANNER_UNIT_ID.isNotEmpty()) {
            val widthDp = with(density) { widthPixels.toDp().value.toInt().coerceAtLeast(1) }
            val adSize = remember(context, widthDp) {
                AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(context, widthDp)
            }
            // Reserve the actual adaptive-banner height in the root Column, even
            // while the network request is pending; otherwise board controls can
            // jump when an ad arrives on small phones.
            val adHeight = with(density) { adSize.getHeightInPixels(context).toDp() }
            key(widthDp) {
                val adView = remember(context, widthDp) {
                    AdView(context).apply {
                        adUnitId = BuildConfig.ADMOB_BANNER_UNIT_ID
                        setAdSize(adSize)
                        loadAd(AdRequest.Builder().build())
                    }
                }
                DisposableEffect(adView) { onDispose { adView.destroy() } }
                AndroidView(
                    factory = { adView },
                    modifier = Modifier.fillMaxWidth().height(adHeight)
                )
            }
        }
    }
}
