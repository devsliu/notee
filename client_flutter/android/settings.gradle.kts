pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        // 阿里云镜像优先，解决 dl.google.com / repo.maven.apache.org TLS 握手问题
        maven("https://maven.aliyun.com/repository/google")
        maven("https://maven.aliyun.com/repository/central")
        maven("https://maven.aliyun.com/repository/gradle-plugin")
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    // PREFER_PROJECT：子项目（含 Flutter 插件）自己声明的 repos 优先，settings 里的镜像作为 fallback
    repositoriesMode.set(RepositoriesMode.PREFER_PROJECT)
    repositories {
        maven("https://maven.aliyun.com/repository/google")
        maven("https://maven.aliyun.com/repository/central")
        google()
        mavenCentral()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")

// 全局覆盖所有子项目（含 Flutter 插件库）的 Android 配置
// 解决 keyboard_height_plugin 等老插件锁 compileSdk=31 与新版 androidx 冲突
gradle.beforeProject {
    plugins.withId("com.android.library") {
        val lib = extensions.getByType<com.android.build.api.dsl.LibraryExtension>()
        lib.compileSdk = 36
        lib.compileOptions {
            sourceCompatibility = JavaVersion.VERSION_21
            targetCompatibility = JavaVersion.VERSION_21
        }
    }
    plugins.withId("com.android.application") {
        val app = extensions.getByType<com.android.build.api.dsl.ApplicationExtension>()
        app.compileSdk = 36
        app.compileOptions {
            sourceCompatibility = JavaVersion.VERSION_21
            targetCompatibility = JavaVersion.VERSION_21
        }
    }
}
