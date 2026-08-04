plugins {
    id("kotlin-android")
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}
android {
    namespace = "com.example.application_flutter"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.application_flutter"
        minSdk = flutter.minSdkVersion
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

    
    signingConfigs {
        create("release") {
            
            storeFile = file("upload-keystore.jks")
            storePassword = "notitrack"
            keyAlias = "upload"
            keyPassword = "notitrack"
        }
    }

    buildTypes {
        getByName("debug") {
            // Nothing special
        }
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    implementation("org.tensorflow:tensorflow-lite:2.12.0")
    implementation("androidx.localbroadcastmanager:localbroadcastmanager:1.1.0")
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.10")
}

flutter {
    source = "../.."
}
