plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

// Play Games IDs are public identifiers, not API secrets. Fill android/play-games.properties
// or use matching ULTTTT_* environment variables in release automation.
val playGamesProperties = java.util.Properties().apply {
    val configFile = rootProject.file("play-games.properties")
    if (configFile.exists()) configFile.inputStream().use { load(it) }
}
fun playGamesConfig(key: String): String =
    providers.environmentVariable("ULTTTT_" + key).orNull?.trim()
        ?.takeIf { it.isNotEmpty() } ?: playGamesProperties.getProperty(key, "").trim()

val playGamesAppId = playGamesConfig("PLAY_GAMES_APP_ID")
require(playGamesAppId.isEmpty() || Regex("^[0-9]{8,20}$").matches(playGamesAppId)) {
    "PLAY_GAMES_APP_ID must be the numeric game services project ID from Play Console."
}
val playGamesIds = listOf(
    "PGS_FIRST_WIN_ID", "PGS_FIVE_WINS_ID", "PGS_TEN_WINS_ID",
    "PGS_FIRST_ONLINE_WIN_ID", "PGS_TWENTY_FIVE_ONLINE_WINS_ID",
    "PGS_ONLINE_WINS_LEADERBOARD_ID"
)
playGamesIds.forEach { key ->
    require(playGamesConfig(key).isEmpty() || Regex("^[a-zA-Z0-9_-]+$").matches(playGamesConfig(key))) {
        "Invalid Play Games resource ID in $key"
    }
}

val releaseVersionCode = providers.environmentVariable("ULTTTT_VERSION_CODE").orNull
val releaseVersionName = providers.environmentVariable("ULTTTT_VERSION_NAME").orNull
val uploadStorePath = providers.environmentVariable("ANDROID_UPLOAD_KEYSTORE_PATH").orNull
val uploadStorePassword = providers.environmentVariable("ANDROID_UPLOAD_KEY_PASSWORD").orNull
// Live AdMob identifiers are NOT inferred from the publisher ID. Supply them at release time.
// A release built without both IDs compiles safely but cannot request live advertisements.
val liveAdMobAppId = providers.environmentVariable("ULTTTT_ADMOB_ANDROID_APP_ID").orNull.orEmpty().trim()
val liveAdMobBannerId = providers.environmentVariable("ULTTTT_ADMOB_ANDROID_BANNER_UNIT_ID").orNull.orEmpty().trim()
val liveAdMobConfigured = Regex("^ca-app-pub-1217971050094766~[0-9]{10}$").matches(liveAdMobAppId) &&
    Regex("^ca-app-pub-1217971050094766/[0-9]{10}$").matches(liveAdMobBannerId)
if ((liveAdMobAppId.isNotEmpty() || liveAdMobBannerId.isNotEmpty()) && !liveAdMobConfigured)
    throw GradleException("Both valid Ultttt Android AdMob app and banner unit IDs must be supplied together.")
if (providers.environmentVariable("ULTTTT_REQUIRE_LIVE_ADMOB").orNull == "true" && !liveAdMobConfigured)
    throw GradleException("Production release requires real Android AdMob app and banner unit IDs.")
val configuredAppId = if (liveAdMobConfigured) liveAdMobAppId else "ca-app-pub-3940256099942544~3347511713"
val configuredBannerId = if (liveAdMobConfigured) liveAdMobBannerId else ""

android {
    namespace = "com.killjoy00.ultttt"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.killjoy00.ultttt"
        minSdk = 26
        targetSdk = 36
        versionCode = releaseVersionCode?.toIntOrNull() ?: 5
        versionName = releaseVersionName ?: "1.1.1"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        manifestPlaceholders["admobAppId"] = configuredAppId
        resValue("string", "game_services_project_id",
            if (playGamesAppId.isNotEmpty()) playGamesAppId else "0000000000")
        buildConfigField("boolean", "PLAY_GAMES_CONFIGURED", playGamesAppId.isNotEmpty().toString())
        playGamesIds.forEach { key ->
            buildConfigField("String", key, "\"${playGamesConfig(key)}\"")
        }
        buildConfigField("boolean", "ADMOB_CONFIGURED", liveAdMobConfigured.toString())
        buildConfigField("String", "ADMOB_BANNER_UNIT_ID", "\"$configuredBannerId\"")
    }

    signingConfigs {
        create("upload") {
            if (!uploadStorePath.isNullOrBlank()) {
                storeFile = file(uploadStorePath)
                storeType = "PKCS12"
                storePassword = uploadStorePassword
                keyAlias = "upload"
                keyPassword = uploadStorePassword
            }
        }
    }

    buildTypes {
        getByName("debug") {
            manifestPlaceholders["admobAppId"] = "ca-app-pub-3940256099942544~3347511713"
            buildConfigField("boolean", "ADMOB_CONFIGURED", "true")
            buildConfigField("String", "ADMOB_BANNER_UNIT_ID", "\"ca-app-pub-3940256099942544/9214589741\"")
        }
        release {
            // Enable R8 so the AAB includes a mapping for readable crash reports.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
            // Include symbols from any unstripped native libraries in the bundle.
            ndk {
                debugSymbolLevel = "SYMBOL_TABLE"
            }
            // Debug/CI builds never require signing secrets; release uploads always do.
            if (!uploadStorePath.isNullOrBlank())
                signingConfig = signingConfigs.getByName("upload")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true; buildConfig = true }
    packaging { resources.excludes += "/META-INF/{AL2.0,LGPL2.1}" }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2026.03.00")
    implementation(composeBom)
    implementation("androidx.activity:activity-compose:1.12.4")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")
    implementation("com.google.android.gms:play-services-ads:25.5.0")
    implementation("com.google.android.gms:play-services-games-v2:22.1.0")
    implementation("com.google.android.ump:user-messaging-platform:4.0.0")
    implementation("com.android.billingclient:billing:9.1.0")
    // The Privacy Sandbox ad-services transitive dependency requests Guava 31.1;
    // use a maintained Android variant instead of pulling an obsolete artifact.
    implementation("com.google.guava:guava:33.6.0-android")
    testImplementation("junit:junit:4.13.2")
}
