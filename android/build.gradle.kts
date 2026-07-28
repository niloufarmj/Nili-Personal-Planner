allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val buildBaseDir = file("${System.getProperty("user.home")}/.gradle_builds/Nili-Personal-Planner/build")

rootProject.layout.buildDirectory.set(buildBaseDir)

subprojects {
    project.layout.buildDirectory.set(buildBaseDir.resolve(project.name))
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
    delete(file("../build"))
}

val copyApkTask = tasks.register("copyApkToProjectBuild") {
    doLast {
        val srcApk = file("${buildBaseDir.path}/app/outputs/flutter-apk/app-debug.apk")
        val dstDir = file("../build/app/outputs/flutter-apk")
        if (srcApk.exists()) {
            dstDir.mkdirs()
            srcApk.copyTo(file("${dstDir.path}/app-debug.apk"), overwrite = true)
        }
    }
}

subprojects {
    tasks.matching { it.name == "assembleDebug" || it.name == "packageDebug" }.configureEach {
        finalizedBy(copyApkTask)
    }
}
