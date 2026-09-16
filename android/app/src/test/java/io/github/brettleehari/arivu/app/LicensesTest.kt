package io.github.brettleehari.arivu.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

// spine: C4 — every shipped component's licence is present in-app, including the model weights.
// Unit tests run with working directory android/app.
class LicensesTest {
    private val dir = File("src/main/assets/licenses")
    private val entries = File(dir, "index.txt").readLines().filter { it.isNotBlank() }.map { it.split("|") }

    @Test
    fun everyEntryHasItsText() = entries.forEach { (name, _, file) ->
        assertTrue("missing licence text for $name", File(dir, file).length() > 500)
    }

    @Test
    fun coversModelWeightsAndRuntime() {
        val names = entries.joinToString("\n") { it[0] }
        listOf(
            "Qwen3", "Unsloth", "llama.cpp", "YaRN", "ggllm.cpp", "Unicode", "libc++", "Compose", "kotlinx.serialization",
            "ThreeTen-BP", "AndroidX", "graphics-path",
        ).forEach { assertTrue("licences screen does not cover $it", it in names) }
    }

    /** licence-audit.md L1: the root NOTICE travels with the binary, byte for byte, and is listed first. */
    @Test
    fun noticeShippedInAppMatchesRootNotice() {
        assertEquals("assets/licenses/NOTICE.txt differs from root NOTICE — copy it", File("../../NOTICE").readText(), File(dir, "NOTICE.txt").readText())
        assertEquals("NOTICE.txt", entries.first()[2])
        val notice = File(dir, "NOTICE.txt").readText()
        listOf(
            "Unsloth", "Jeffrey Quesnelle and Bowen Peng", "cmp-nct", "Unicode License v3",
            "kotlinx.coroutines library. Copyright 2016-2025 JetBrains s.r.o and contributors",
            "kotlinx.serialization library. Copyright 2017-2019 JetBrains s.r.o and respective authors and developers",
            "ThreeTen-BP",
        ).forEach { assertTrue("NOTICE lacks: $it", it in notice) }
    }

    /**
     * licence-audit.md L10: every native library the build actually merges maps to a licence entry. The Gradle test
     * task depends on mergeDebugNativeLibs and passes its output directory (app/build.gradle.kts). A new .so fails here
     * until someone decides which licence covers it.
     */
    @Test
    fun everyShippedNativeLibMapsToALicenceEntry() {
        val libsDir = System.getProperty("arivu.nativeLibsDir")?.let(::File)
        assertTrue("arivu.nativeLibsDir not set or missing: $libsDir", libsDir != null && libsDir.isDirectory)
        val libs = libsDir!!.walk().filter { it.isFile && it.name.endsWith(".so") }.map { it.name }.toSortedSet()
        assertTrue("no native libs found under $libsDir", libs.isNotEmpty())
        val rules = listOf(
            Regex("^libarivu_llama\\.so$") to "Arivu",
            Regex("^libllama\\.so$") to "llama.cpp",
            Regex("^libggml(-base|-cpu-android_[a-z0-9._]+)?\\.so$") to "llama.cpp",
            Regex("^libc\\+\\+_shared\\.so$") to "libc++",
            Regex("^libandroidx\\.graphics\\.path\\.so$") to "graphics-path",
        )
        val names = entries.map { it[0] }
        libs.forEach { lib ->
            val entry = rules.firstOrNull { it.first.matches(lib) }?.second
            assertTrue("$lib has no licence rule — add it to index.txt and this test", entry != null)
            assertTrue("$lib maps to '$entry', which is not in index.txt", names.any { it == entry || it.contains(entry!!) })
        }
        // Code compiled into the llama/ggml libs carries its own notices (licence-audit.md §3).
        if (libs.any { it.startsWith("libggml-cpu") }) assertTrue(names.any { "YaRN" in it })
        if ("libllama.so" in libs) assertTrue(names.any { "ggllm.cpp" in it } && names.any { "Unicode" in it })
    }
}
