import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Optional release signing. app/android/key.properties is GITIGNORED
// (app/android/.gitignore) and holds the upload-keystore credentials:
//   storeFile=..., storePassword=..., keyAlias=..., keyPassword=...
// See packaging/README.md "Android release builds" for keystore creation.
// Never commit the keystore or this file.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties =
    Properties().apply {
        if (keystorePropertiesFile.exists()) {
            keystorePropertiesFile.inputStream().use { load(it) }
        }
    }

android {
    // namespace = the code/R package (where MainActivity lives), kept as the
    // flutter-create default so the manifest's ".MainActivity" resolves. This
    // is intentionally NOT the applicationId — the on-device identity below is
    // com.incubtek.jeliya to match the macOS bundle id.
    namespace = "com.incubtek.jeliya_app"
    compileSdk = flutter.compileSdkVersion
    // The libjeliya_ffi.so in jniLibs are linked with NDK r29 (scripts/
    // build-android-libs.mjs); keep the packaging toolchain coherent.
    ndkVersion = "29.0.14206865"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.incubtek.jeliya"
        // minSdk 26 (Android 8) — settled floor; the runtime-proof .so link
        // against API 26 and the in-market low-end target devices.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Ship all three in-market ABIs. armeabi-v7a is REQUIRED: real target
        // devices (e.g. moto g play 2023) run 32-bit-only Android builds.
        //
        // `flutter build apk --split-per-abi` passes -Psplit-per-abi=true and
        // configures AGP's splits.abi with these same three ABIs; AGP rejects
        // ndk.abiFilters alongside splits ("Conflicting configuration"), so
        // skip the filter for that build only. Every other build — including
        // the on-device assembleDebug fat APK — keeps filtering exactly as
        // before.
        if (project.findProperty("split-per-abi")?.toString() != "true") {
            ndk {
                abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
            }
        }
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                // Relative storeFile paths resolve against app/android/app;
                // an absolute path in key.properties is simplest.
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // With app/android/key.properties present, release artifacts are
            // signed with the real upload keystore. Without it, local/dev
            // release builds stay debug-signed so `flutter run --release`
            // still works on-device — but those artifacts are NOT
            // distributable: release distribution (Play or sideload) requires
            // the keystore. Do NOT check any real keys into the repo.
            signingConfig =
                if (keystorePropertiesFile.exists()) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }
}

flutter {
    source = "../.."
}
