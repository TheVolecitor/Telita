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
    val configureAndroid = {
        if (project.hasProperty("android")) {
            val androidExt = project.extensions.getByName("android")
            try {
                val setNdkVersion = androidExt.javaClass.getMethod("setNdkVersion", String::class.java)
                setNdkVersion.invoke(androidExt, "26.1.10909125")
            } catch (e: Exception) {}
        }
    }
    if (state.executed) {
        configureAndroid()
    } else {
        afterEvaluate { configureAndroid() }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
