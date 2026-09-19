package io.github.brettleehari.arivu.app

import io.github.brettleehari.arivu.app.profile.Capability
import io.github.brettleehari.arivu.app.profile.Profiles
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import java.io.File
import org.junit.Test

/**
 * spine: C11 — one product, two platforms. Compliance Leaf.
 *
 * [ProfileSelectorTest] proves the *selection* is a function of the device probe alone. This test
 * proves the thing selection cannot: that the numbers being selected are the **same numbers** in
 * all three places they are written down — `/core` (the shared engine, and the only copy iOS and
 * Android both link), `/android` (Kotlin `Profiles.COMPACT` + `Policy`) and `/ios` (Swift
 * `Policy`). C11 says an 8 GB Android phone and an 8 GB iPhone get the same profile; that claim is
 * false the moment one tree's constant drifts, and nothing else in the repo would notice.
 *
 * It is a source-text test on purpose. A shared *runtime* value would be better, and
 * `arivu_default_profile()` is meant to become it (Profile.kt: "when the C API carries a profile,
 * this object feeds it whole"). Until then the three copies are a fact, and an untested fact in a
 * compliance matrix is a claim, not evidence.
 *
 * Unit tests run with working directory android/app; `../..` is the repo root.
 *
 * iOS is in the tree now, so nothing here skips any more: a missing Swift constant is drift, not
 * absence, and it fails. The memory model (`model_bytes`, `kv_bytes_per_token`,
 * `compute_buffer_bytes`, `runtime_overhead_bytes`) is compared core↔iOS directly, because Android's
 * `Profile` carries no memory model and so cannot stand in the middle of that comparison.
 */
class ProfileParityTest {

    private val repo = File("../..")
    private val coreProfile = File(repo, "core/src/profile.cpp")
    /** The C defaults live in profile.cpp today; arivu_c.cpp is the fallback if they move back. */
    private val coreSampling = listOf(File(repo, "core/src/profile.cpp"), File(repo, "core/src/arivu_c.cpp"))
        .first { it.isFile && "arivu_default_sampling_params" in it.readText() }
    private val swiftPolicy = repo.resolve("ios").walkTopDown()
        .firstOrNull { it.isFile && it.name == "Policy.swift" }

    /**
     * The Swift memory model lives in `Profile.swift`, not `Policy.swift`. That distinction is the
     * whole reason this test used to miss the drift it now catches: `kv_bytes_per_token`,
     * `compute_buffer_bytes`, `runtime_overhead_bytes` and `model_bytes` are the four numbers that
     * decide whether the app is killed, they exist only in `/core` and `/ios` — Android's `Profile`
     * carries no memory model at all — and nothing compared them in any direction.
     */
    private val swiftProfile = repo.resolve("ios").walkTopDown()
        .firstOrNull { it.isFile && it.name == "Profile.swift" }

    /** Body of a `extern "C"`-style function, from its opening brace to the first column-0 `}`. */
    private fun cFunctionBody(file: File, signature: String): String {
        val text = file.readText()
        val start = text.indexOf(signature)
        assertTrue("${file.path} has no $signature", start >= 0)
        val open = text.indexOf('{', start)
        val end = text.indexOf("\n}", open)
        assertTrue("${file.path}: $signature is not closed", end > open)
        return text.substring(open, end)
    }

    /** `p.field = <literal>;` assignments, with `ull`/`u`/`f` suffixes and `N * kMiB` resolved. */
    private fun cAssignments(body: String): Map<String, String> =
        Regex("""\bp\.(\w+)\s*=\s*([^;]+);""").findAll(stripComments(body)).associate { m ->
            m.groupValues[1] to normalise(m.groupValues[2])
        }

    private fun stripComments(s: String) =
        s.lines().joinToString("\n") { it.substringBefore("//") }.replace(Regex("""/\*.*?\*/""", RegexOption.DOT_MATCHES_ALL), "")

    private fun normalise(raw: String): String {
        var v = raw.trim().replace("_", "")
        Regex("""^(\d+)ull\s*\*\s*kMiB$""").find(v)?.let { return (it.groupValues[1].toLong() * 1024 * 1024).toString() }
        v = v.removeSuffix("ull").removeSuffix("ll").removeSuffix("u").removeSuffix("L")
        if (v.endsWith("f") && v.drop(1).any { it == '.' }) v = v.dropLast(1)
        return v.trim().trim('"')
    }

    /**
     * `label: value` pairs from the body of a Swift literal initialiser, e.g.
     * `public static let compact = Profile(` … `)`. One field per line, which is how the file is
     * written; comment lines and the trailing comma are stripped.
     */
    private fun swiftInitArguments(file: File, declaration: String): Map<String, String> {
        val text = file.readText()
        val start = text.indexOf(declaration)
        assertTrue("${file.path} has no `$declaration`", start >= 0)
        val open = text.indexOf('(', start)
        val end = text.indexOf("\n    )", open)
        assertTrue("${file.path}: `$declaration` is not closed", end > open)
        return text.substring(open + 1, end)
            .lines()
            .map { it.substringBefore("//").trim() }
            .filter { it.isNotEmpty() }
            .mapNotNull { Regex("""^(\w+):\s*(.+?),?$""").find(it) }
            .associate { m -> m.groupValues[1] to m.groupValues[2].trim().trim(',').replace("_", "").trim('"') }
    }

    /** `public static let name[: Type] = <literal>` in a Swift file. */
    private fun swiftLets(file: File): Map<String, String> =
        Regex("""public static (?:let|var)\s+(\w+)\s*(?::\s*[\w.<>\[\] ]+)?\s*=\s*([^\n{]+)""")
            .findAll(file.readText())
            .associate { m ->
                m.groupValues[1] to m.groupValues[2].substringBefore("//").trim().trim(',').replace("_", "").trim('"')
            }

    // ---------------------------------------------------------------------------------------
    // core ↔ android
    // ---------------------------------------------------------------------------------------

    @Test
    fun coreDefaultProfileMatchesTheAndroidProfile() {
        val core = cAssignments(cFunctionBody(coreProfile, "arivu_profile arivu_default_profile("))
        val a = Profiles.COMPACT
        val expected = mapOf(
            "id" to a.name,
            "n_ctx" to a.nCtx.toString(),
            "n_batch" to a.nBatch.toString(),
            "n_threads" to a.maxThreads.toString(),
            "kv_q8_0" to a.kvQ8_0.toString(),
            "repack" to a.repackWeights.toString(),
            "reply_reserve_tokens" to a.replyReserveTokens.toString(),
            "max_reply_tokens" to a.maxReplyTokens.toString(),
            "min_total_ram_bytes" to a.minTotalRamBytes.toString(),
            "min_free_storage_bytes" to BuildConfig.MIN_FREE_STORAGE_BYTES.toString(),
        )
        expected.forEach { (field, want) ->
            assertEquals(
                "core/src/profile.cpp arivu_default_profile().$field disagrees with Profiles.COMPACT " +
                    "— C11 says both platforms get one set of numbers; change both or neither",
                want, core[field],
            )
        }
        // The one profile that ships offers chat and nothing else, in both trees (SPINE R2, R4, R6).
        assertEquals("ARIVUCAPCHAT", core["capabilities"]?.uppercase()?.replace("_", ""))
        assertEquals(setOf(Capability.CHAT), a.capabilities)
    }

    @Test
    fun coreDefaultSamplingMatchesTheAndroidProfile() {
        val core = cAssignments(cFunctionBody(coreSampling, "arivu_sampling_params arivu_default_sampling_params("))
        val a = Profiles.COMPACT
        assertEquals("temperature drift between core and Android (D-007)", a.temperature.toString(), core["temperature"])
        assertEquals("top_k drift between core and Android (D-007)", a.topK.toString(), core["top_k"])
        assertEquals("top_p drift between core and Android (D-007)", a.topP.toString(), core["top_p"])
    }

    // ---------------------------------------------------------------------------------------
    // android ↔ ios
    // ---------------------------------------------------------------------------------------

    /**
     * core ↔ ios, for the half Android cannot take part in.
     *
     * Android's `Profile` has no memory model — no `modelBytes`, no `kvBytesPerToken`, no compute or
     * runtime figures — so these four numbers are written down exactly twice, in
     * `core/src/profile.cpp` and in `ios/ArivuKit/Sources/ArivuCore/Profile.swift`, and until this
     * test existed nothing compared them. They had drifted: Swift carried `kvBytesPerToken = 57_344`, which is the core's
     * own `28*8*128*2` **without** q8_0's 1.0625 bytes per value, understating the KV cache by
     * 7.3 MB at 2048 ctx. This is the check that would have caught it on the day it was typed.
     */
    @Test
    fun coreMemoryModelMatchesTheSwiftProfile() {
        assertTrue("no ios/**/Profile.swift — the iOS memory model must be somewhere", swiftProfile != null)
        val core = cAssignments(cFunctionBody(coreProfile, "arivu_profile arivu_default_profile("))
        val swift = swiftInitArguments(swiftProfile!!, "public static let compact = Profile(")

        // Swift label -> C field. Only the fields that are literals in both places: `nCtx` and the
        // rest come from Policy.swift and are already covered by the Android↔iOS test below.
        val fields = mapOf(
            "id" to "id",
            "modelID" to "model_id",
            "modelBytes" to "model_bytes",
            "kvBytesPerToken" to "kv_bytes_per_token",
            "computeBufferBytes" to "compute_buffer_bytes",
            "runtimeOverheadBytes" to "runtime_overhead_bytes",
        )
        fields.forEach { (swiftName, cName) ->
            val want = core[cName]
            val got = swift[swiftName]
            assertTrue(
                "core/src/profile.cpp arivu_default_profile() has no $cName", want != null,
            )
            assertTrue(
                "${swiftProfile.path} Profile.compact has no $swiftName — the memory model must be " +
                    "written down in full on both sides, or the comparison is vacuous", got != null,
            )
            assertEquals(
                "$cName disagrees between core/src/profile.cpp and ${swiftProfile.path} " +
                    "($swiftName) — these four numbers decide whether the app is killed; the core " +
                    "is the authority, so change it there first (architecture B23, spine: C11)",
                want, got,
            )
        }
    }

    @Test
    fun theSwiftPolicyCarriesTheSameNumbersAsTheAndroidProfile() {
        assertTrue("no ios/**/Policy.swift — iOS is in the tree, so this is drift, not absence",
                   swiftPolicy != null)
        val s = swiftLets(swiftPolicy!!)
        val a = Profiles.COMPACT
        val expected = mapOf(
            "nCtx" to a.nCtx.toString(),
            "nBatch" to a.nBatch.toString(),
            "kvQ8_0" to a.kvQ8_0.toString(),
            "replyReserveTokens" to a.replyReserveTokens.toString(),
            "maxReplyTokens" to a.maxReplyTokens.toString(),
            "repackWeights" to a.repackWeights.toString(),
            "temperature" to a.temperature.toString(),
            "topK" to a.topK.toString(),
            "topP" to a.topP.toString(),
            "maxThreads" to a.maxThreads.toString(),
            "minTotalRamBytes" to a.minTotalRamBytes.toString(),
            "minFreeStorageBytes" to BuildConfig.MIN_FREE_STORAGE_BYTES.toString(),
        )
        expected.forEach { (name, want) ->
            // No `?: return@forEach`. A missing constant used to pass silently, which made every
            // assertion here conditional on the Swift side having bothered to write it down —
            // exactly the hole that let the memory model drift unnoticed.
            val got = s[name]
            assertTrue(
                "${swiftPolicy.path} has no Policy.$name — iOS must carry every number Android " +
                    "decides, or C11 is unprovable for that number",
                got != null,
            )
            assertEquals(
                "${swiftPolicy.path} Policy.$name disagrees with Profiles.COMPACT — an iPhone and an " +
                    "Android phone of the same size must get the same profile (spine: C11)",
                want, got,
            )
        }
        // Not a number, but the same rule: one idle timeout, expressed in each platform's unit.
        s["contextIdleSeconds"]?.let {
            assertEquals("idle timeout drift", Policy.CONTEXT_IDLE_MILLIS, (it.toDouble() * 1000).toLong())
        }
    }

    /**
     * spine: C5, C9 — the system prompt is the only safety mechanism that is not a UI affordance
     * (leaves/NOTES.md prompt probe, D-026). It must be byte-identical on both platforms, or the two
     * stores are reviewing two different models' behaviour.
     */
    @Test
    fun theSystemPromptIsByteIdenticalOnBothPlatforms() {
        assertTrue("no ios/**/Policy.swift — the system prompt must exist on both sides to compare",
                   swiftPolicy != null)
        val text = swiftPolicy!!.readText()
        val start = text.indexOf("systemPrompt")
        assertTrue("${swiftPolicy.path} has no systemPrompt", start >= 0)
        val tail = text.substring(start)
        val end = tail.indexOf("\n    ///").let { if (it > 0) it else tail.length }
        val literals = tail.substring(0, end)
            .lines().filterNot { it.trim().startsWith("//") }.joinToString("\n")
            .let { Regex(""""((?:[^"\\]|\\.)*)"""").findAll(it).map { m -> m.groupValues[1] }.toList() }
        assertFalse("no string literals found for the Swift system prompt", literals.isEmpty())
        assertEquals(
            "the iOS and Android system prompts differ — same model, same job, same words (spine: C11)",
            Policy.SYSTEM_PROMPT, literals.joinToString(""),
        )
    }

    // ---------------------------------------------------------------------------------------
    // the rule that makes the above possible
    // ---------------------------------------------------------------------------------------

    /**
     * `core/src/profile.cpp` is where capability is decided. MULTIPLATFORM.md: "Nothing is
     * `#ifdef`'d by platform, because the tiers will not stay platform-aligned." A platform
     * conditional here would make C11 unprovable, whatever the other tests say. (Elsewhere in
     * `/core`, `__APPLE__` is legitimate — `arivu_memory_kb` reads RSS from mach vs `/proc`.)
     */
    @Test
    fun theProfileArithmeticHasNoPlatformConditional() {
        val text = coreProfile.readText()
        listOf("__APPLE__", "__ANDROID__", "TARGET_OS_", "TARGET_IPHONE", "_WIN32", "__linux__").forEach {
            assertFalse(
                "core/src/profile.cpp branches on the platform ($it) — capability must follow the " +
                    "device, never the platform (spine: C11)",
                it in text,
            )
        }
    }
}
