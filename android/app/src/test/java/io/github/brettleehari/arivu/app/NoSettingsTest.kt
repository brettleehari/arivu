package io.github.brettleehari.arivu.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element
import java.io.File
import java.lang.reflect.Modifier
import javax.xml.parsers.DocumentBuilderFactory

// spine: C8 — no settings: the app declares exactly one screen-hosting activity and one service, no
// preference screen, no persisted user preferences, and every tunable is a compile-time constant in Policy.
// Unit tests run with working directory android/app.
class NoSettingsTest {
    private val manifest = File("src/main/AndroidManifest.xml")
    private val mainSrc = File("src/main/java")
    private val androidNs = "http://schemas.android.com/apk/res/android"

    private fun components(tag: String): List<Element> {
        val doc = DocumentBuilderFactory.newInstance().apply { isNamespaceAware = true }.newDocumentBuilder().parse(manifest)
        val nodes = doc.getElementsByTagName(tag)
        return (0 until nodes.length).map { nodes.item(it) as Element }
    }

    @Test
    fun manifestDeclaresExactlyTheExpectedComponents() {
        assertEquals(listOf(".MainActivity"), components("activity").map { it.getAttributeNS(androidNs, "name") })
        assertEquals(listOf(".inference.GenerationService"), components("service").map { it.getAttributeNS(androidNs, "name") })
        assertEquals("no activity-alias", 0, components("activity-alias").size)
        assertEquals("no providers declared by the app", 0, components("provider").size)
        assertEquals("no receivers declared by the app", 0, components("receiver").size)
    }

    @Test
    fun noPreferenceScreenEntryPoint() {
        val text = manifest.readText()
        listOf("APPLICATION_PREFERENCES", "NOTIFICATION_PREFERENCES", "PreferenceActivity", "SettingsActivity").forEach {
            assertFalse("manifest exposes a settings entry point: $it", it in text)
        }
        val xmlRes = File("src/main/res/xml")
        val prefXml = xmlRes.listFiles().orEmpty().filter { f -> "PreferenceScreen" in f.readText() }
        assertTrue("preference XML present: $prefXml", prefXml.isEmpty())
    }

    @Test
    fun noSettingsLibrariesInBuild() {
        val build = File("build.gradle.kts").readText() + File("../gradle/libs.versions.toml").readText()
        listOf("androidx.preference", "datastore").forEach {
            assertFalse("build pulls in a settings library: $it", it in build)
        }
    }

    /** SharedPreferences is allowed only for the gate's cached pass result, which the user cannot change. */
    @Test
    fun noUserPreferencesPersisted() {
        val allowed = setOf("gate/CompatibilityGate.kt")
        val offenders = mainSrc.walk().filter { it.isFile && it.extension == "kt" }
            .filter { f -> listOf("getSharedPreferences", "PreferenceManager", "DataStore").any { it in f.readText() } }
            .map { it.relativeTo(File(mainSrc, "io/github/brettleehari/arivu/app")).invariantSeparatorsPath }
            .filterNot { it in allowed }
            .toList()
        assertTrue("user-visible preference storage outside the allowlist: $offenders", offenders.isEmpty())
    }

    @Test
    fun policyTunablesAreCompileTimeConstants() {
        val fields = Policy::class.java.declaredFields.filterNot { it.name == "INSTANCE" }
        assertTrue("Policy has no tunables?", fields.isNotEmpty())
        fields.forEach {
            assertTrue("Policy.${it.name} is not static final", Modifier.isStatic(it.modifiers) && Modifier.isFinal(it.modifiers))
        }
        // Spot-check the decisions that fixed them (BRIEF.md "Context", D-007).
        assertEquals(2048, Policy.N_CTX)
        assertEquals(0.7f, Policy.TEMPERATURE)
    }
}
