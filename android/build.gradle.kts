allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val forcedCompileSdk = 36

fun forceCompileSdk(androidExt: Any, compileSdk: Int) {
    val setCompileSdkMethod = androidExt.javaClass.methods.firstOrNull { method ->
        (method.name == "setCompileSdk" || method.name == "setCompileSdkVersion") &&
            method.parameterTypes.size == 1
    } ?: return

    runCatching {
        val paramType = setCompileSdkMethod.parameterTypes[0]
        if (
            paramType == Int::class.javaPrimitiveType ||
            paramType == Int::class.javaObjectType
        ) {
            setCompileSdkMethod.invoke(androidExt, compileSdk)
        } else {
            setCompileSdkMethod.invoke(androidExt, "android-$compileSdk")
        }
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

subprojects {
    plugins.withId("com.android.library") {
        extensions.findByName("android")?.let { androidExt ->
            forceCompileSdk(androidExt, forcedCompileSdk)
        }
    }
    plugins.withId("com.android.application") {
        extensions.findByName("android")?.let { androidExt ->
            forceCompileSdk(androidExt, forcedCompileSdk)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
