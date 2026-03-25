buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
        classpath("com.google.firebase:firebase-crashlytics-gradle:3.0.2")
    }
}

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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

tasks.register<Exec>("preflightCheck") {
    description = "Run environment preflight checks"
    group = "verification"
    workingDir = file("..")
    
    val localProps = file("local.properties")
    val flutterSdk = if (localProps.exists()) {
        localProps.readLines().find { it.startsWith("flutter.sdk=") }
            ?.substringAfter("=")?.replace("\\\\", "\\") ?: "flutter"
    } else "flutter"
    
    val dartCmd = if (System.getProperty("os.name").lowercase().contains("windows")) {
        if (flutterSdk != "flutter") "$flutterSdk\\bin\\dart.bat" else "dart"
    } else {
        if (flutterSdk != "flutter") "$flutterSdk/bin/dart" else "dart"
    }
    
    commandLine = listOf(dartCmd, "run", "tool/preflight_check.dart")
}

gradle.taskGraph.whenReady {
    allTasks.forEach { task ->
        if (task.name.contains("assemble") || task.name.contains("bundle")) {
            task.dependsOn("preflightCheck")
        }
    }
}
