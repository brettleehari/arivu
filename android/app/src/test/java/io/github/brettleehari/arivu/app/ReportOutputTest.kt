package io.github.brettleehari.arivu.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.util.Properties

// spine: C9 — the in-app report of offensive output needs no network: it is a well-formed mailto
// intent (with a share-sheet fallback) addressed to the configured report address. The release gate
// (tools/release_check.sh) additionally rejects the placeholder address (D-010).
// Unit tests run with working directory android/app.
class ReportOutputTest {
    private val email = Regex("^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\\.[A-Za-z0-9-]+)+$")
    // Contract moved (Engineering, per-reply Report): reportOutput now lives in ui/ReportOutput.kt and is shared by
    // the About entry and the per-reply report sheet. Assertions below are unchanged except the file path.
    private val source = File("src/main/java/io/github/brettleehari/arivu/app/ui/ReportOutput.kt").readText()
    private val reportFn = source.substringAfter("fun reportOutput(", "").also {
        assertTrue("reportOutput not found", it.isNotEmpty())
    }

    @Test
    fun reportAddressIsWiredAndWellFormed() {
        val props = Properties().apply { File("../gradle.properties").inputStream().use(::load) }
        val configured = props.getProperty("arivu.reportEmail")
        assertEquals("BuildConfig must carry arivu.reportEmail", configured, BuildConfig.REPORT_EMAIL)
        assertTrue("report address is not an email: $configured", email.matches(BuildConfig.REPORT_EMAIL))
    }

    @Test
    fun intentIsMailtoWithRecipientSubjectAndBody() {
        listOf(
            "Intent.ACTION_SENDTO", "Uri.parse(\"mailto:\")",
            "Intent.EXTRA_EMAIL", "arrayOf(BuildConfig.REPORT_EMAIL)",
            "Intent.EXTRA_SUBJECT", "Intent.EXTRA_TEXT", "context.startActivity(",
        ).forEach { assertTrue("report intent is missing $it", it in reportFn) }
    }

    @Test
    fun fallsBackToShareSheetWhenNoEmailApp() {
        listOf("ActivityNotFoundException", "Intent.ACTION_SEND", "\"text/plain\"", "Intent.createChooser", "BuildConfig.REPORT_EMAIL")
            .forEach { assertTrue("share fallback is missing $it", it in reportFn) }
    }

    @Test
    fun reportStringsExistAndTemplateCarriesVersion() {
        val strings = File("src/main/res/values/strings.xml").readText()
        val used = Regex("R\\.string\\.([a-z0-9_]+)").findAll(reportFn).map { it.groupValues[1] }.toSet()
        assertTrue("report intent uses no string resources", used.isNotEmpty())
        used.forEach { assertTrue("missing string resource $it", "name=\"$it\"" in strings) }
        val template = Regex("R\\.string\\.([a-z0-9_]+),\\s*BuildConfig\\.VERSION_NAME").find(reportFn)?.groupValues?.get(1)
        assertTrue("report body does not include the app version", template != null)
        val templateText = Regex("name=\"$template\">(.*?)</string>", RegexOption.DOT_MATCHES_ALL).find(strings)?.groupValues?.get(1).orEmpty()
        assertTrue("template $template has no %1\$s placeholder for the version", "%1\$s" in templateText)
    }

    /** spine: C9 — the per-reply report carries the reply itself, the reason and the note, and marks the reply. */
    @Test
    fun perReplyReportCarriesReplyReasonNoteAndIsReachableFromEachReply() {
        val strings = File("src/main/res/values/strings.xml").readText()
        val tpl = Regex("name=\"report_reply_template\">(.*?)</string>", RegexOption.DOT_MATCHES_ALL).find(strings)?.groupValues?.get(1).orEmpty()
        listOf("%1\$s", "%2\$s", "%3\$s", "%4\$s").forEach { assertTrue("report_reply_template lacks $it", it in tpl) }
        listOf("report.replyText", "report.reason.label", "report.note").forEach {
            assertTrue("per-reply report body is missing $it", it in reportFn)
        }
        val chat = File("src/main/java/io/github/brettleehari/arivu/app/ui/ChatScreen.kt").readText()
        assertTrue("no Report action on replies", "R.string.report)" in chat && "ReportSheet(" in chat)
        assertTrue("reply is not marked reported", "onReported(" in chat)
        assertTrue("About lost its general report entry", "reportOutput(context)" in File("src/main/java/io/github/brettleehari/arivu/app/ui/AboutScreen.kt").readText())
        listOf("OFFENSIVE", "HARMFUL", "WRONG_DANGEROUS", "OTHER").forEach { assertTrue("reason $it missing", it in source) }
    }

    @Test
    fun reportedFlagSurvivesRestart() {
        val f = File.createTempFile("conv", ".json").apply { deleteOnExit() }
        val m = io.github.brettleehari.arivu.app.chat.Message("r", false, "reply", 1L, io.github.brettleehari.arivu.app.chat.Stop.END_OF_TURN, reported = true)
        io.github.brettleehari.arivu.app.chat.ChatRepository(f).save(listOf(m))
        assertEquals(listOf(m), io.github.brettleehari.arivu.app.chat.ChatRepository(f).load())
    }

    @Test
    fun reportPathUsesNoNetwork() {
        listOf("http://", "https://", "HttpURLConnection", "Socket(", "OkHttp").forEach {
            assertFalse("report path touches the network: $it", it in reportFn)
        }
        assertFalse("INTERNET permission declared", "android.permission.INTERNET" in File("src/main/AndroidManifest.xml").readText())
    }
}
