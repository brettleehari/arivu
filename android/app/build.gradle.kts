plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

fun prop(name: String): String = providers.gradleProperty(name).get()

// spine: C1 — upload signing. Material lives OUTSIDE the repo: ~/.gradle/gradle.properties (or -P / env vars).
//   arivu.upload.storeFile      ARIVU_UPLOAD_STORE_FILE      absolute path to the PKCS12 upload keystore
//   arivu.upload.storePassword  ARIVU_UPLOAD_STORE_PASSWORD
//   arivu.upload.keyAlias       ARIVU_UPLOAD_KEY_ALIAS       (default arivu-upload)
//   arivu.upload.keyPassword    ARIVU_UPLOAD_KEY_PASSWORD    (default: store password; PKCS12 uses one)
// Absent → the release bundle is unsigned (other Leaves and CI can still build). tools/make_upload_key.sh creates the key.
fun uploadSetting(prop: String, env: String): String? =
    (providers.gradleProperty(prop).orNull ?: providers.environmentVariable(env).orNull)?.takeIf { it.isNotBlank() }

val repoRoot: File = rootProject.projectDir.parentFile.canonicalFile
val uploadStoreFile: File? = uploadSetting("arivu.upload.storeFile", "ARIVU_UPLOAD_STORE_FILE")?.let { file(it).canonicalFile }
val uploadStorePassword: String? = uploadSetting("arivu.upload.storePassword", "ARIVU_UPLOAD_STORE_PASSWORD")
if (uploadStoreFile != null) {
    check(uploadStoreFile.isFile) { "arivu.upload.storeFile does not exist: $uploadStoreFile" }
    check(uploadStorePassword != null) { "arivu.upload.storeFile is set but arivu.upload.storePassword is not" }
    // A keystore inside the repo is one `git add -A` from being published. Throwaway test keys under build/ are allowed.
    val inRepo = uploadStoreFile.toPath().startsWith(repoRoot.toPath())
    val throwaway = uploadStoreFile.toPath().startsWith(repoRoot.resolve("build").toPath()) && "NOT-FOR-UPLOAD" in uploadStoreFile.name
    check(!inRepo || throwaway) { "upload keystore must live outside the repository: $uploadStoreFile" }
}

android {
    namespace = "io.github.brettleehari.arivu.app"
    compileSdk = 37  // Compose BOM 2026.09 requires it; targetSdk stays 36 (decisions.yml D-016)
    ndkVersion = "29.0.14206865"

    defaultConfig {
        applicationId = prop("arivu.applicationId")
        minSdk = 30
        targetSdk = 36
        versionCode = prop("arivu.versionCode").toInt()
        versionName = prop("arivu.versionName")
        ndk { abiFilters += "arm64-v8a" }   // no other ABI in the bundle (gate layer 1)

        buildConfigField("long", "MIN_TOTAL_RAM_BYTES", "${prop("arivu.minTotalRamBytes")}L")
        buildConfigField("long", "MIN_FREE_STORAGE_BYTES", "${prop("arivu.minFreeStorageBytes")}L")
        buildConfigField("String", "REPORT_EMAIL", "\"${prop("arivu.reportEmail")}\"")
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    signingConfigs {
        if (uploadStoreFile != null) {
            create("upload") {
                storeFile = uploadStoreFile
                storePassword = uploadStorePassword
                keyAlias = uploadSetting("arivu.upload.keyAlias", "ARIVU_UPLOAD_KEY_ALIAS") ?: "arivu-upload"
                keyPassword = uploadSetting("arivu.upload.keyPassword", "ARIVU_UPLOAD_KEY_PASSWORD") ?: uploadStorePassword
                storeType = "pkcs12"
            }
        }
    }

    buildTypes {
        release {
            signingConfigs.findByName("upload")?.let { signingConfig = it }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // Unsigned unless the upload key is configured outside the repo (above); see leaves/engineering.md "Release".
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // The GGUF must stay uncompressed so it can be mmap'd straight out of the (split) APK.
    androidResources { noCompress += listOf("gguf", ".gguf.so") }
    packaging { jniLibs { useLegacyPackaging = true } }  // ggml picks a CPU variant by scanning nativeLibraryDir

    assetPacks += ":modelpack"

    bundle {
        abi { enableSplit = true }
        language { enableSplit = false }  // one install works offline in every language
        density { enableSplit = true }
    }

    testOptions { unitTests.isReturnDefaultValues = true }
}

// spine: C3 (M5) — every bundle build runs tools/check_manifest.sh on its own output; the build fails if the
// merged manifest gained a network permission, a non-arm64 ABI, or lost the backup/D2D exclusions.
listOf("Debug", "Release").forEach { variant ->
    val lower = variant.lowercase()
    val aab = layout.buildDirectory.file("outputs/bundle/$lower/app-$lower.aab")
    val check = tasks.register<Exec>("checkManifest$variant") {
        group = "verification"
        description = "tools/check_manifest.sh on the $lower bundle (M5)"
        inputs.file(aab)
        inputs.file(repoRoot.resolve("tools/check_manifest.sh"))
        val stamp = layout.buildDirectory.file("reports/check-manifest-$lower.txt")
        outputs.file(stamp)
        environment("JAVA_HOME", System.getProperty("java.home"))
        // Output is printed and also kept as the task's report (so the check is up-to-date only for an unchanged AAB).
        commandLine("bash", "-c", "\"$1\" \"$2\" | tee \"$3\"; exit \${PIPESTATUS[0]}", "check_manifest",
            repoRoot.resolve("tools/check_manifest.sh").absolutePath, aab.get().asFile.absolutePath, stamp.get().asFile.absolutePath)
        doFirst { stamp.get().asFile.parentFile.mkdirs() }
    }
    tasks.matching { it.name == "bundle$variant" }.configureEach { finalizedBy(check) }
}

// spine: C4 — LicensesTest maps every merged native lib to a licence entry (licence-audit.md L10).
tasks.withType<Test>().configureEach {
    dependsOn("mergeDebugNativeLibs")
    val libs = layout.buildDirectory.dir("intermediates/merged_native_libs/debug")
    inputs.dir(libs)
    systemProperty("arivu.nativeLibsDir", libs.get().asFile.absolutePath)
}

dependencies {
    implementation(project(":llama"))
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.lifecycle.process)
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.material3)
    implementation(libs.compose.ui.tooling.preview)
    debugImplementation(libs.compose.ui.tooling)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.kotlinx.coroutines.android)

    testImplementation(libs.junit)
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:${libs.versions.coroutines.get()}")
}
