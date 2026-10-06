plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Secrets are supplied by the release environment, never client dart defines.
val releaseStore = System.getenv("SARISUPPLY_KEYSTORE_PATH")
val releaseAlias = System.getenv("SARISUPPLY_KEY_ALIAS")
val releaseStorePassword = System.getenv("SARISUPPLY_KEYSTORE_PASSWORD")
val releaseKeyPassword = System.getenv("SARISUPPLY_KEY_PASSWORD")
val releaseSigningReady = listOf(releaseStore, releaseAlias, releaseStorePassword, releaseKeyPassword)
    .all { !it.isNullOrBlank() } && releaseStore?.let { file(it).isFile } == true
val productionReleaseRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true) && !it.contains("dev", ignoreCase = true)
}
if (productionReleaseRequested && !releaseSigningReady) {
    throw GradleException("Production release requires a keystore and all SARISUPPLY signing environment variables.")
}

android {
    namespace = "com.sarisupply.sarisupply_driver"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        resValues = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.sarisupply.sarisupply_driver"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningReady) {
            create("production") {
                storeFile = file(releaseStore!!)
                storePassword = releaseStorePassword
                keyAlias = releaseAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    flavorDimensions += "environment"

    productFlavors {
        create("dev") {
            dimension = "environment"
            signingConfig = signingConfigs.getByName("debug")
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "SariSupply Driver Dev")
        }
        create("prod") {
            dimension = "environment"
            if (releaseSigningReady) signingConfig = signingConfigs.getByName("production")
            resValue("string", "app_name", "SariSupply Driver")
        }
    }

    buildTypes {
        release {
            // Flavor signing applies: dev uses debug; prod requires real credentials.
            signingConfig = null
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
