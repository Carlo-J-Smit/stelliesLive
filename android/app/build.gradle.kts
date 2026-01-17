import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.stellieslive.app"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    // 🔐 Load key.properties
    val keystoreProperties = Properties().apply {
        val file = rootProject.file("key.properties")
        if (file.exists()) {
            load(FileInputStream(file))
        }
    }

    defaultConfig {
        applicationId = "com.stellieslive.app"
        minSdk = 23
        targetSdk = 35
        versionCode = 6
        versionName = "0.4.0"
    }

    signingConfigs {
        create("release") {
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
        }
    }

    buildTypes {
    getByName("release") {
        isMinifyEnabled = false
        isShrinkResources = false // ✅ add this line to stop the crash
        signingConfig = signingConfigs.getByName("release")
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}


    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}

