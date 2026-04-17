plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.evshare.evshare"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.evshare.evshare"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // TODO: Set your actual signing key properties
            // keytool -genkey -v -keystore release.keystore -alias voltbnb -keyalg RSA -keysize 2048 -validity 10000
            storeFile = file("../release.keystore")
            storePassword = System.getenv("KEYSTORE_PASSWORD") ?: "changeme"
            keyAlias = System.getenv("KEY_ALIAS") ?: "voltbnb"
            keyPassword = System.getenv("KEY_PASSWORD") ?: "changeme"
        }
    }

    buildTypes {
        release {
            // Use release signing config instead of debug
            signingConfig = signingConfigs.getByName("release")
            minifyEnabled = true
            shrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
