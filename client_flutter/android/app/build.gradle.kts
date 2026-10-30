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
            // 剥离 native 库的 DWARF 调试信息（NONE=全剥，SYMBOL_TABLE=仅保留函数名）
            debugSymbolLevel = "NONE"
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

    packaging {
        jniLibs {
            useLegacyPackaging = false
            // 只打 arm64-v8a，剥掉其他架构的冗余 .so
            excludes += setOf("**/armeabi-v7a/**", "**/x86_64/**", "**/x86/**")
        }
    }

}

// -------- NDK llvm-strip：对 APK 内所有 .so 剥离 DWARF 调试信息 --------
// AGP 的 debugSymbolLevel 只管 externalNativeBuild 产物，
// Flutter libapp.so、sqlite3、AAR 里的插件 .so 需手动 strip。
val sdkDir = android.sdkDirectory
val ndkDir = File(sdkDir, "ndk/${android.ndkVersion}")
val stripTool = File(ndkDir, "toolchains/llvm/prebuilt/windows-x86_64/bin/llvm-strip.exe")
val buildRoot = layout.buildDirectory.get().asFile

fun stripSo(file: File) {
    if (!stripTool.exists() || !file.exists()) return
    val pb = ProcessBuilder(stripTool.absolutePath, "--strip-all", file.absolutePath)
        .redirectErrorStream(true)
    val proc = pb.start()
    proc.inputStream.bufferedReader().useLines { it.forEach { println("strip[${file.name}]: $it") } }
    proc.waitFor()
}

tasks.register("stripReleaseSoSymbols") {
    onlyIf("llvm-strip.exe exists") { stripTool.exists() }
    doLast {
        val outDir = File(buildRoot, "intermediates/merged_native_libs/release/out/lib")
        if (!outDir.exists()) return@doLast
        outDir.walkTopDown().filter { it.isFile && it.extension == "so" }.forEach { so ->
            stripSo(so)
        }
    }
}

tasks.register("stripFlutterSo") {
    onlyIf("llvm-strip.exe exists") { stripTool.exists() }
    doLast {
        val candidates = listOf(
            File(buildRoot, "intermediates/flutter/release/libapp.so"),
            File(buildRoot, "flutter-apk/intermediates/release/flutter/libapp.so"),
        )
        for (so in candidates) stripSo(so)
    }
}

// 绑定到构建流水线（AGP 9 用 configureEach 代替 tasks.named 避免懒加载问题）
tasks.configureEach {
    if (name == "mergeReleaseNativeLibs") finalizedBy("stripReleaseSoSymbols")
    if (name == "packageRelease") dependsOn("stripFlutterSo")
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
