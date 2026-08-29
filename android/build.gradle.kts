allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// 统一把各 Android 模块（含 file_picker 等插件）的 compileSdk 提升到 36，
// 以满足 flutter_plugin_android_lifecycle 等依赖对 API 36 的最低要求。
// 兼容项目评估时机：已评估的直接赋值，未评估的用 afterEvaluate。
subprojects {
    val applyCompileSdk = {
        extensions.findByName("android")?.let { ext ->
            when (ext) {
                is com.android.build.api.dsl.ApplicationExtension -> ext.compileSdk = 36
                is com.android.build.api.dsl.LibraryExtension -> ext.compileSdk = 36
            }
        }
    }
    if (state.executed) {
        applyCompileSdk()
    } else {
        afterEvaluate { applyCompileSdk() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
