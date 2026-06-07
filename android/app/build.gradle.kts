import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ─── Load signing credentials from key.properties (never committed to VCS) ───
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) {
        load(keyPropertiesFile.inputStream())
    }
}

android {
    namespace = "com.plateful.plateful"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_21.toString()
    }

    // ─── Signing ──────────────────────────────────────────────────────────────
    signingConfigs {
        create("release") {
            keyAlias = keyProperties.getProperty("keyAlias") ?: ""
            keyPassword = keyProperties.getProperty("keyPassword") ?: ""
            storeFile = keyProperties.getProperty("storeFile")
                ?.let { file(it) }
                ?: file("plateful-release.jks") // fallback path
            storePassword = keyProperties.getProperty("storePassword") ?: ""
        }
    }

    defaultConfig {
        applicationId = "com.plateful.plateful"
        // RevenueCat Paywalls + Customer Center UI require minSdk 24.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            // Keep debug un-minified for fast iteration.
            isMinifyEnabled = false
        }
        release {
            signingConfig = signingConfigs.getByName("release")
            // Enable R8 shrinking + obfuscation for the Play Store build.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required for RevenueCat Paywall / Customer Center themes
    // (Theme.MaterialComponents.*) used by FlutterFragmentActivity.
    implementation("com.google.android.material:material:1.12.0")
}
