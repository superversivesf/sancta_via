import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "net.superversive.sancta_via.novena_companion"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "net.superversive.sancta_via.novena_companion"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("app/key.properties")
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(keystorePropertiesFile.inputStream())
    }

    // Release signing needs app/key.properties (gitignored, see key.properties.template).
    // Without it, fall back to debug keys so release builds still run locally.
    val hasReleaseKey = keystorePropertiesFile.exists()

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Signing with the release key requires android/app/key.properties
            // (gitignored, see key.properties.template). Signing with the DEBUG
            // key is an explicit opt-out for local release-run testing only -
            // never silent, and store uploads must never use it.
            signingConfig = run {
                val allowDebug = project.findProperty("allowDebugSigning") == "true" ||
                    System.getenv("SV_ALLOW_DEBUG_SIGNING") == "1"
                if (hasReleaseKey) {
                    signingConfigs.getByName("release")
                } else if (allowDebug) {
                    logger.warn("WARNING: release build signed with the DEBUG key (explicit opt-out) - never use for store uploads")
                    signingConfigs.getByName("debug")
                } else {
                    throw org.gradle.api.GradleException(
                        "Release build is unsigned: android/app/key.properties is missing. " +
                        "Generate keystores with tool/generate_keystores.sh (see fastlane/README.md). " +
                        "For a local release test only, set SV_ALLOW_DEBUG_SIGNING=1 or -PallowDebugSigning=true.")
                }
            }
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

// F-Droid: exclude Google Play Core (Flutter pulls it in transitively for deferred
// components the app never uses; F-Droid prohibits those classes in shipped APKs).
configurations.configureEach {
    exclude(group = "com.google.android.play", module = "core")
}
