extra["kotlin_version"] = "2.2.20"

allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri(rootProject.projectDir.toURI().resolve("libs")) }
        maven { url = uri("https://jitpack.io") }
        maven { url = uri("https://raw.githubusercontent.com/motazyusuf/paymob-android-repo/main/") }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
