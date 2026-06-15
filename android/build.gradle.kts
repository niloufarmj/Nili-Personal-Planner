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
}
