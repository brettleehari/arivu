// JNI binding over patched llama.cpp (tools/llama/). No UI, no Android framework beyond logging.
plugins {
    alias(libs.plugins.android.library)
}

val llamaDir = rootProject.file("../third_party/llama.cpp")

android {
    namespace = "io.github.brettleehari.arivu.llama"
    compileSdk = 37  // Compose BOM 2026.09 requires it; targetSdk stays 36 (decisions.yml D-016)
    ndkVersion = "29.0.14206865"   // r27+ required for 16KB page-size alignment

    defaultConfig {
        minSdk = 30
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        consumerProguardFiles("consumer-rules.pro")
        ndk { abiFilters += "arm64-v8a" }
        externalNativeBuild {
            cmake {
                arguments += listOf(
                    "-DLLAMA_DIR=${llamaDir.absolutePath}",
                    "-DANDROID_STL=c++_shared",
                )
            }
        }
    }

    buildTypes {
        // Native code is always optimised: a debug-built ggml is too slow to judge anything by.
        debug { externalNativeBuild { cmake { arguments += "-DCMAKE_BUILD_TYPE=Release" } } }
        release { externalNativeBuild { cmake { arguments += "-DCMAKE_BUILD_TYPE=Release" } } }
    }

    externalNativeBuild {
        cmake {
            path("src/main/cpp/CMakeLists.txt")
            version = "4.1.2"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Benchmark (W01) loads the model from androidTest assets through the same fd-window path
    // as the app, so it also measures how the packager aligned the asset.
    androidResources { noCompress += listOf("gguf", ".gguf.so") }
    packaging { jniLibs { useLegacyPackaging = true } }
}

/** Stages the fetched GGUF as a generated androidTest asset for the benchmark (never in the library AAR). */
abstract class StageModelAsset : DefaultTask() {
    @get:InputFile abstract val model: RegularFileProperty
    @get:OutputDirectory abstract val outputDir: DirectoryProperty

    @TaskAction
    fun stage() {
        val dir = outputDir.get().asFile.resolve("model").apply { mkdirs() }
        // Same ".so" naming as the app so the packager aligns it identically (D-013).
        model.get().asFile.copyTo(dir.resolve(model.get().asFile.name + ".so"), overwrite = true)
    }
}

val stageBenchModel = tasks.register<StageModelAsset>("stageBenchModel") {
    model.set(rootProject.layout.projectDirectory.file("../models/Qwen3-0.6B-Q4_K_M.gguf"))
}

androidComponents {
    onVariants(selector().withBuildType("debug")) { variant ->
        variant.androidTest?.sources?.assets?.addGeneratedSourceDirectory(stageBenchModel, StageModelAsset::outputDir)
    }
}

dependencies {
    implementation(libs.kotlinx.coroutines.android)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.androidx.test.ext.junit)
    androidTestImplementation(libs.junit)
}
