import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing material lives outside version control. Without it the
// release build stops here with an explanation instead of quietly shipping a
// debug-signed artifact.
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
val keystoreProperties = Properties().apply {
    if (hasReleaseSigning) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val isReleaseBuild = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

android {
    namespace = "com.dinurymomshad.docmark"
    // WHY: flutter_secure_storage 11 ships an AAR built against API 37;
    // the Flutter default (36) fails AAR metadata checks. AGP 9.1.0 allows
    // 37 with an acknowledgment flag in gradle.properties.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.dinurymomshad.docmark"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // WHY: local_auth needs API 23 for the biometric prompt and
        // sqlcipher_flutter_libs needs 23 for its native SQLCipher build.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

if (!hasReleaseSigning && isReleaseBuild) {
    throw GradleException(
        "Missing android/key.properties: a release build needs storeFile, " +
            "storePassword, keyAlias and keyPassword. Create the file (it is " +
            "git-ignored) or build a debug variant. Refusing to sign a release " +
            "with the debug key.",
    )
}

flutter {
    source = "../.."
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
