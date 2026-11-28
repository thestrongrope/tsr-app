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
    
    // Suppress obsolete Java version warnings
    // Suppress obsolete Java version warnings and ensure Kotlin compiles before Java in mixed projects
    afterEvaluate {
        tasks.withType<JavaCompile>().configureEach {
            options.compilerArgs.add("-Xlint:-options")
            val kotlinTask = tasks.findByName(name.replace("JavaWithJavac", "Kotlin"))
            if (kotlinTask != null) {
                dependsOn(kotlinTask)
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
