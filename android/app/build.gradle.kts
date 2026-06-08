import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.myhalaqat.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.myhalaqat.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storeFileStr = keystoreProperties.getProperty("storeFile") ?: return@create
            keyAlias = keystoreProperties.getProperty("keyAlias") ?: return@create
            keyPassword = keystoreProperties.getProperty("keyPassword") ?: return@create
            storePassword = keystoreProperties.getProperty("storePassword") ?: return@create
            storeFile = rootProject.file(storeFileStr)
        }
    }

    buildTypes {
        release {
            // شلنا الشرط وأجبرناه يستخدم الـ debug فوراً
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
