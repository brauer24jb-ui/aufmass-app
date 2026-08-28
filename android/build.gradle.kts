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
    // project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// HIER IST DER NEUE TRICK, DER DAS GEOCODING-PAKET ZWINGT, AUF 36 ZU LAUFEN:
subprojects {
    afterEvaluate {
        val androidExt = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        androidExt?.compileSdkVersion(36)
    }
}