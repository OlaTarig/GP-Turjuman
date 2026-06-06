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
    namespace = "com.example.turjuman"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.turjuman"
        // MediaPipe Tasks Vision requires API 24+
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // Prevent Gradle from compressing ML model files — required for MediaPipe and TFLite
    androidResources {
        noCompress += listOf("tflite", "task", "lite", "bin")
    }
}

dependencies {
    // MediaPipe Tasks Vision: PoseLandmarker + HandLandmarker
    implementation("com.google.mediapipe:tasks-vision:0.10.13")

    // TFLite benchmark instrumentation tests
    androidTestImplementation("org.tensorflow:tensorflow-lite:2.14.0")
    androidTestImplementation("org.tensorflow:tensorflow-lite-gpu:2.14.0")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test:runner:1.5.2")
}

flutter {
    source = "../.."
}