plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseStore = providers.environmentVariable("SODU_RELEASE_STORE").orNull
val debugStore = providers.environmentVariable("SODU_DEBUG_STORE").orNull

android {
    namespace = "org.sodukromental"
    compileSdk = 36
    buildToolsVersion = "36.0.0"
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "org.sodukromental"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["displayName"] = "Sodukromental"
    }

    signingConfigs {
        if (debugStore != null) {
            getByName("debug") {
                storeFile = file(debugStore)
                storePassword = providers.environmentVariable("SODU_DEBUG_STORE_PASSWORD").get()
                keyAlias = providers.environmentVariable("SODU_DEBUG_KEY_ALIAS").get()
                keyPassword = providers.environmentVariable("SODU_DEBUG_KEY_PASSWORD").get()
            }
        }
        if (releaseStore != null) {
            create("release") {
                storeFile = file(releaseStore)
                storePassword = providers.environmentVariable("SODU_RELEASE_STORE_PASSWORD").get()
                keyAlias = providers.environmentVariable("SODU_RELEASE_KEY_ALIAS").get()
                keyPassword = providers.environmentVariable("SODU_RELEASE_KEY_PASSWORD").get()
            }
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            manifestPlaceholders["displayName"] = "Sodukromental Debug"
        }
        release {
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
