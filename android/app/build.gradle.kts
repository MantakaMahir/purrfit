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

val dartDefines = (project.findProperty("dart-defines") as String?)
    ?.split(',')
    ?.mapNotNull { encoded: String ->
        runCatching { String(Base64.getDecoder().decode(encoded), Charsets.UTF_8) }.getOrNull()
    }
    .orEmpty()

val sampleAdMobAppId = "ca-app-pub-3940256099942544~3347511713"
val configuredAdMobAppId = secretProperty("ADMOB_APP_ID")?.takeIf { it.isNotBlank() }
val monetizationEnabled = "PURRFIT_ENABLE_MONETIZATION=true" in dartDefines
val uploadSigningValues = listOf(
    "PURRFIT_UPLOAD_STORE_FILE",
    "PURRFIT_UPLOAD_STORE_PASSWORD",
    "PURRFIT_UPLOAD_KEY_ALIAS",
    "PURRFIT_UPLOAD_KEY_PASSWORD",
).associateWith { secretProperty(it)?.takeIf(String::isNotBlank) }
val uploadSigningConfigured = uploadSigningValues.values.any { it != null }
val releaseRequested = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}

if (releaseRequested && uploadSigningConfigured) {
    val missing = uploadSigningValues.filterValues { it == null }.keys
    require(missing.isEmpty()) { "Missing release signing values: ${missing.joinToString()}" }
}
if (releaseRequested && monetizationEnabled) {
    require(uploadSigningConfigured) { "Monetized release builds require an upload key." }
    require(configuredAdMobAppId?.matches(Regex("ca-app-pub-[0-9]{16}~[0-9]{10}")) == true &&
        configuredAdMobAppId != sampleAdMobAppId) {
        "Monetized release builds require a production ADMOB_APP_ID Gradle property."
    }
    val rewardedUnit = dartDefines.lastOrNull { it.startsWith("ADMOB_REWARDED_ID=") }
        ?.substringAfter('=')
    require(rewardedUnit?.matches(Regex("ca-app-pub-[0-9]{16}/[0-9]{10}")) == true &&
        !rewardedUnit.startsWith("ca-app-pub-3940256099942544/")) {
        "Monetized release builds require --dart-define=ADMOB_REWARDED_ID with a production ad unit ID."
    }
}

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
        // The bundled SDK expects a valid ID even when ads are disabled.
        manifestPlaceholders["adMobAppId"] = sampleAdMobAppId
    }

    signingConfigs {
        if (uploadSigningConfigured && uploadSigningValues.values.all { it != null }) {
            create("releaseUpload") {
                storeFile = rootProject.file(uploadSigningValues.getValue("PURRFIT_UPLOAD_STORE_FILE")!!)
                storePassword = uploadSigningValues.getValue("PURRFIT_UPLOAD_STORE_PASSWORD")
                keyAlias = uploadSigningValues.getValue("PURRFIT_UPLOAD_KEY_ALIAS")
                keyPassword = uploadSigningValues.getValue("PURRFIT_UPLOAD_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            if (monetizationEnabled && configuredAdMobAppId != null) {
                manifestPlaceholders["adMobAppId"] = configuredAdMobAppId
            }
            isMinifyEnabled = true
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            signingConfig = signingConfigs.findByName("releaseUpload")
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
