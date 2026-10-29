allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// 全局覆盖所有子项目（Flutter 插件库）的 compileSdk 与 Java/Kotlin 版本
// 解决老插件锁 compileSdk=31 与新版 androidx 冲突
subprojects {
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
    // 强制 Kotlin 编译任务存在（keyboard_height_plugin 等老插件）
    plugins.withId("kotlin-android") {
        // 确保 Kotlin 插件初始化
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
