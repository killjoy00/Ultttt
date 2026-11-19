plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

val releaseVersionCode = providers.environmentVariable("ULTTTT_VERSION_CODE").orNull
val releaseVersionName = providers.environmentVariable("ULTTTT_VERSION_NAME").orNull
val uploadStorePath = providers.environmentVariable("ANDROID_UPLOAD_KEYSTORE_PATH").orNull
val uploadStorePassword = providers.environmentVariable("ANDROID_UPLOAD_KEY_PASSWORD").orNull

android {
    namespace = "com.killjoy00.ultttt"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.killjoy00.ultttt"
        minSdk = 26
        targetSdk = 36
        versionCode = releaseVersionCode?.toIntOrNull() ?: 1
        versionName = releaseVersionName ?: "1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
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
        release {
            isMinifyEnabled = false
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
    buildFeatures { compose = true }
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
    testImplementation("junit:junit:4.13.2")
}
