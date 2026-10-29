plugins {
    id("com.android.application")
    // Kotlin Gradle Plugin (kotlin-android) removed: AGP 9.0.1 ships a
    // built-in Kotlin compiler that handles src/main/kotlin/*.kt (e.g.
    // MainActivity.kt). Applying the KGP triggers Flutter's migration
    // warning and will become a hard failure in future Flutter versions.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    ndkVersion = "29.0.13846066"
    namespace = "com.lhg.notee"
    compileSdk = 36
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.lhg.notee"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            // 设置支持的SO库架构
            abiFilters.add("arm64-v8a")
            //abiFilters.add("armeabi-v7a")
        }
    }

    signingConfigs {
        create("release") {
            storeFile = file("keystore.jks")
            storePassword = "123456"
            keyAlias = "all"
            keyPassword = "123456"
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("release")
        }
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }

}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
