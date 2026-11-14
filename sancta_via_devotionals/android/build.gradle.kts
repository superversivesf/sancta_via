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
// Java/Kotlin target alignment for plugin subprojects: under AGP 9.1 / KGP
// 2.4 the Kotlin JVM-target validation is strict, and shipped plugins
// declare mixed pairs (flutter_timezone: javac 11 / Kotlin 1.8;
// shared_preferences_android: javac 17 / Kotlin default) which fail the
// build. Force every plugin subproject to a single consistent pair (17/17)
// after its own configuration evaluates.
subprojects {
    afterEvaluate {
        project.extensions
            .findByType(com.android.build.gradle.BaseExtension::class.java)
            ?.apply {
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
            .configureEach {
                compilerOptions {
                    jvmTarget.set(
                        org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17,
                    )
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
