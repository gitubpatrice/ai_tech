plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}

android {
    // v0.9.2 (#2) — `com.aitech.ai_tech` est le package historique pré-
    // FilesTech (publié sous cet identifiant sur GitHub Release depuis
    // v0.x.x). Cert SHA-256 lié. Migrer vers `com.filestech.ai_tech`
    // serait destructive (perte historique installations utilisateurs).
    // On conserve. (CLAUDE.md mention `com.filestech.ai_tech` est une
    // erreur documentaire à corriger côté doc, pas côté code.)
    namespace = "com.aitech.ai_tech"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.aitech.ai_tech"
        // MediaPipe GenAI requiert minSdk 24 (Android 7.0).
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Inclure FR + EN ressources Material/AndroidX (réduit également l'APK
        // en élaguant les locales système non listées).
        resourceConfigurations += listOf("fr", "en")
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = keystoreProperties["storeFile"]?.let { rootProject.file(it as String) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    // Splits ABI : bloc retiré v0.9.2.1 hotfix CI.
    //
    // Cause : depuis Flutter 3.41+, le SDK pose
    // `ndk.abiFilters = [armeabi-v7a, arm64-v8a, x86_64]` automatiquement.
    // Avoir aussi `splits.abi { include(...) }` déclenche au build :
    //   "Conflicting configuration : '...' in ndk abiFilters cannot be
    //    present when splits abi filters are set"
    //
    // Le workflow GH Actions Release utilise `flutter build apk --release`
    // (sans `--split-per-abi`) → besoin d'un APK universal → conflit.
    //
    // Pattern : passer par `flutter build apk --release --split-per-abi`
    // (flag explicite) pour obtenir 3 APKs splits côté local. Sans flag :
    // `flutter build apk --release` génère 1 APK universal (CI Release).
    //
    // Aligné RFT v2.13.1 hotfix CI et Pass / Notes Tech (qui n'ont jamais
    // eu ce bloc).

    // Splits ABI côté AAB (Play Store / F-Droid). Identique à `splits.abi`
    // mais via la pipeline App Bundle.
    bundle {
        abi {
            enableSplit = true
        }
        language {
            // Ne PAS splitter par langue : avec generate: true Flutter, les
            // ARB sont packagés et l'utilisateur peut switcher la langue
            // dans Settings indépendamment de la locale système.
            enableSplit = false
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Si key.properties absent, on laisse signingConfig à null :
            // assembleDebug compile (ne touche pas ce buildType), assembleRelease
            // échouera proprement plus tard ("no signing config"). Le throw au
            // config-time cassait `flutter build apk --debug` en CI car Gradle
            // évalue tous les buildTypes même quand on en assemble qu'un seul.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
            // MediaPipe livre des .so déjà compressés ; éviter doublons libc++_shared.
            pickFirsts += listOf(
                "lib/*/libc++_shared.so",
                "lib/*/libtensorflowlite_jni.so",
            )
        }
    }
}

flutter {
    source = "../.."
}
