import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Native resources initialize Firebase before Dart when Android wakes a killed app.
// Deployment supplies the genuine project file; unconfigured builds remain usable.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

val signingProperties = Properties()
val signingFile = rootProject.file("key.properties")
if (signingFile.exists()) signingFile.inputStream().use { signingProperties.load(it) }
val releaseRequested = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
val signingKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
if (releaseRequested && signingKeys.any { signingProperties.getProperty(it).isNullOrBlank() }) {
    throw GradleException("Release signing requires android/key.properties; debug signing is never used for release.")
}

android {
    namespace = "com.example.healthysv2"
    // permission_handler_android requires API 37; runtime targets remain Flutter's defaults.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Replace this identifier with the registered store/Firebase application before publishing.
        applicationId = "com.example.healthysv2"
        manifestPlaceholders["appAuthRedirectScheme"] = "healthys"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signingKeys.all { !signingProperties.getProperty(it).isNullOrBlank() }) {
            create("release") {
                storeFile = rootProject.file(signingProperties.getProperty("storeFile"))
                storePassword = signingProperties.getProperty("storePassword")
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
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
