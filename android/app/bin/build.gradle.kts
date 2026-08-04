plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.application_flutter"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.application_flutter"
        minSdk = flutter.minSdkVersion  // ✅ Back to 21 - no select-tf-ops needed
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"
        multiDexEnabled = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        getByName("debug") {
            // normal debug build
        }
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // ✅ ONLY standard TFLite - NO select-tf-ops!
    implementation("org.tensorflow:tensorflow-lite:2.12.0")
    
    // ✅ LocalBroadcastManager for notifications
    implementation("androidx.localbroadcastmanager:localbroadcastmanager:1.1.0")

    // ✅ Kotlin standard library
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.10")
}

flutter {
    source = "../.."
}
