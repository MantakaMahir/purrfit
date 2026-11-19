import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

fun secretProperty(name: String): String? =
    (project.findProperty(name) as String?)
        ?: keystoreProperties.getProperty(name)
        ?: System.getenv(name)

fun dartDefines(): List<String> = (project.properties["dart-defines"] as String?)
    ?.split(',')
    ?.mapNotNull { encoded: String ->
        runCatching { String(Base64.getDecoder().decode(encoded)) }.getOrNull()
    }
    ?: emptyList<String>()

val configuredAdMobAppId = (project.findProperty("ADMOB_APP_ID") as String?)
    ?.takeIf { it.isNotBlank() }

android {
    namespace = "com.purrfit.purrfit"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications (uses java.time back-ported).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.purrfit.purrfit"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
                // Google's documented sample application ID keeps local/debug builds
                // bootable without ever serving production ads. Release tasks still
                // fail closed below unless ADMOB_APP_ID is provided explicitly.
                manifestPlaceholders["adMobAppId"] = configuredAdMobAppId
                    ?: "ca-app-pub-3940256099942544~3347511713"
    }

    signingConfigs {
        create("releaseUpload") {
            val storeFilePath = secretProperty("PURRFIT_UPLOAD_STORE_FILE")
            storeFile = storeFilePath?.let { rootProject.file(it) }
            storePassword = secretProperty("PURRFIT_UPLOAD_STORE_PASSWORD")
            keyAlias = secretProperty("PURRFIT_UPLOAD_KEY_ALIAS")
            keyPassword = secretProperty("PURRFIT_UPLOAD_KEY_PASSWORD")
        }
    }

    buildTypes {
        release {
            val isReleaseTask = gradle.startParameter.taskNames.any {
                it.contains("Release", ignoreCase = true)
            }
            if (isReleaseTask && configuredAdMobAppId == null) {
                throw GradleException("Missing ADMOB_APP_ID. Pass -PADMOB_APP_ID=ca-app-pub-...~...")
            }
            if (isReleaseTask) {
                val dartDefines = dartDefines()
                val allowReleaseTestConfig = dartDefines.contains("ALLOW_RELEASE_TEST_CONFIG=true")
                val requiredDefines = listOf(
                    "ADMOB_BANNER_ID",
                    "ADMOB_INTERSTITIAL_ID",
                    "ADMOB_REWARDED_ID",
                )
                val missingDefines = requiredDefines.filter { key ->
                    dartDefines.none { define: String ->
                        define.startsWith("$key=") && define.substringAfter('=').isNotBlank()
                    }
                }
                if (missingDefines.isNotEmpty()) {
                    throw GradleException("Missing release dart-defines: ${missingDefines.joinToString()}")
                }
                if (!allowReleaseTestConfig) {
                    val missingSigning = listOf(
                        "PURRFIT_UPLOAD_STORE_FILE",
                        "PURRFIT_UPLOAD_STORE_PASSWORD",
                        "PURRFIT_UPLOAD_KEY_ALIAS",
                        "PURRFIT_UPLOAD_KEY_PASSWORD",
                    ).filter { secretProperty(it).isNullOrBlank() }
                    if (missingSigning.isNotEmpty()) {
                        throw GradleException("Missing release signing values: ${missingSigning.joinToString()}")
                    }
                }
            }
            isMinifyEnabled = true
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            signingConfig = if (dartDefines().contains("ALLOW_RELEASE_TEST_CONFIG=true")) {
                signingConfigs.getByName("debug")
            } else {
                signingConfigs.getByName("releaseUpload")
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
