package io.github.brettleehari.arivu.app

import io.github.brettleehari.arivu.app.profile.Capability
import io.github.brettleehari.arivu.app.profile.DeviceProbe
import io.github.brettleehari.arivu.app.profile.Profile
import io.github.brettleehari.arivu.app.profile.ProfileSelector
import io.github.brettleehari.arivu.app.profile.Profiles
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import java.lang.reflect.Modifier

/**
 * spine: C11 — capability follows what the device can carry, never which platform it runs on.
 * One profile ships today; the selection is tested against a catalogue of several so the *shape*
 * is verified now, rather than the first time a second profile exists.
 */
class ProfileSelectorTest {

    private val gb = 1024L * 1024 * 1024

    private fun profile(name: String, ram: Long, cores: Int, ctx: Int = 2048, threads: Int = 4) = Profile(
        name = name,
        modelAsset = "model/$name.gguf.so",
        minTotalRamBytes = ram,
        minPerformanceCores = cores,
        nCtx = ctx,
        nBatch = 512,
        kvQ8_0 = true,
        maxThreads = threads,
        replyReserveTokens = 512,
        maxReplyTokens = 768,
        repackWeights = false,
        temperature = 0.7f,
        topK = 20,
        topP = 0.8f,
        capabilities = setOf(Capability.CHAT),
    )

    private val large = profile("large", ram = 7 * gb, cores = 4, ctx = 8192, threads = 6)
    private val medium = profile("medium", ram = 5 * gb, cores = 4, ctx = 4096)
    private val small = profile("small", ram = 3 * gb, cores = 2)
    private val catalogue = listOf(large, medium, small)   // most demanding first

    // --- selection ------------------------------------------------------------------------------

    @Test
    fun picksTheMostDemandingProfileTheDeviceCanCarry() {
        assertEquals("large", ProfileSelector.select(DeviceProbe(8 * gb, 6), catalogue).name)
        assertEquals("medium", ProfileSelector.select(DeviceProbe(6 * gb, 4), catalogue).name)
        assertEquals("small", ProfileSelector.select(DeviceProbe(4 * gb, 4), catalogue).name)
    }

    /** The point of C11: the profile is a function of the two numbers, and of nothing else. */
    @Test
    fun twoDevicesWithTheSameNumbersGetTheSameProfile() {
        val androidEightGb = DeviceProbe(8 * gb, 6)
        val iphoneEightGb = DeviceProbe(8 * gb, 6)
        assertSame(ProfileSelector.select(androidEightGb, catalogue), ProfileSelector.select(iphoneEightGb, catalogue))
    }

    /** RAM alone is not enough: a big-memory, few-core device is held back. */
    @Test
    fun coresCountAsWellAsMemory() {
        assertEquals("small", ProfileSelector.select(DeviceProbe(16 * gb, 2), catalogue).name)
    }

    /**
     * Below the floor there is nothing to choose, and nothing to choose it for: the compatibility
     * gate refuses the device and offers to uninstall before any of this runs (spine: C6, SPINE R8).
     */
    @Test
    fun belowTheFloorFallsBackToTheFloorProfile() {
        assertEquals("small", ProfileSelector.select(DeviceProbe(1 * gb, 1), catalogue).name)
    }

    @Test
    fun threadsComeFromTheDeviceWithinTheProfilesCeiling() {
        assertEquals(4, large.threads(DeviceProbe(8 * gb, 4)))
        assertEquals(6, large.threads(DeviceProbe(8 * gb, 8)))   // clamped to the profile's ceiling
        assertEquals(4, small.threads(DeviceProbe(4 * gb, 8)))
        assertEquals(2, small.threads(DeviceProbe(4 * gb, 1)))   // never below what the profile needs
    }

    // --- what actually ships --------------------------------------------------------------------

    /** SPINE R3: no model picker and no second model in iteration-1. A second entry is a Spine change. */
    @Test
    fun exactlyOneProfileShipsToday() {
        assertEquals(listOf(Profiles.COMPACT), Profiles.SHIPPED)
        assertEquals(setOf(Capability.CHAT), Profiles.COMPACT.capabilities)
        assertTrue(Profiles.COMPACT.can(Capability.CHAT))
    }

    /** The values the shipped profile carries are the ones the decisions fixed (leaves/BRIEF.md "Context", D-007, D-013, D-015). */
    @Test
    fun theShippedProfileCarriesTheDecidedValues() {
        with(Profiles.COMPACT) {
            assertEquals(2048, nCtx)
            assertEquals(512, nBatch)
            assertTrue(kvQ8_0)
            assertEquals(512, replyReserveTokens)
            assertEquals(768, maxReplyTokens)
            assertFalse(repackWeights)
            assertEquals(0.7f, temperature, 0f)
            assertEquals(20, topK)
            assertEquals(0.8f, topP, 0f)
            assertEquals("model/qwen3-0.6b-q4_k_m.gguf.so", modelAsset)
        }
    }

    /** Every device the compatibility gate lets through can carry the shipped profile (D-009). */
    @Test
    fun theShippedProfileFitsEveryDeviceTheGateAllows() {
        val atTheFloor = DeviceProbe(BuildConfig.MIN_TOTAL_RAM_BYTES, 2)
        assertTrue(Profiles.COMPACT.fits(atTheFloor))
        assertSame(Profiles.COMPACT, ProfileSelector.select(atTheFloor))
    }

    /**
     * spine: C8 — a profile is chosen, never edited. Every field is a `val`, so nothing in the app
     * (and no settings screen that does not exist) can move a tunable at runtime.
     */
    @Test
    fun profileFieldsAreImmutable() {
        Profile::class.java.declaredFields
            .filterNot { it.isSynthetic || Modifier.isStatic(it.modifiers) }
            .forEach { assertTrue("Profile.${it.name} is not final", Modifier.isFinal(it.modifiers)) }
    }
}
