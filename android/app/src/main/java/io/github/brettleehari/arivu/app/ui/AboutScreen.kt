package io.github.brettleehari.arivu.app.ui

import android.content.Context
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.paneTitle
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import io.github.brettleehari.arivu.app.BuildConfig
import io.github.brettleehari.arivu.app.R

/** spine: C4 (licences), C5 (what it is and is not good at), C9 (report output). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AboutScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val licenses = remember { loadLicenseIndex(context) }
    var open by rememberSaveable { mutableStateOf<String?>(null) }
    val title = stringResource(R.string.about_title)

    Scaffold(
        modifier = Modifier.semantics { paneTitle = title },
        topBar = {
            TopAppBar(
                title = { Text(title, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                // A word, not an arrow icon: icon literacy varies; words don't (leaves/design.md).
                navigationIcon = { TextButton(onClick = onBack) { Text(stringResource(R.string.back)) } },
                windowInsets = TopBarInsets,
            )
        },
        contentWindowInsets = ScreenInsets,
    ) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .consumeWindowInsets(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Section(R.string.about_what_title, R.string.about_what_body)
            Section(R.string.about_good_title, R.string.about_good_body)
            Section(R.string.about_bad_title, R.string.about_bad_body)
            Section(R.string.about_private_title, R.string.about_private_body)
            // spine: C3, C9 — the full privacy policy, readable offline (a URL alone needs the network we don't have).
            ExpandableRow(
                label = stringResource(R.string.about_privacy_policy),
                isOpen = open == PRIVACY_KEY,
                onToggle = { open = if (open == PRIVACY_KEY) null else PRIVACY_KEY },
            )
            if (open == PRIVACY_KEY) PrivacyPolicy()
            Section(R.string.about_report_title, R.string.about_report_body)
            Button(onClick = { reportOutput(context) }) { Text(stringResource(R.string.about_report_button)) }

            HorizontalDivider()
            Text(
                stringResource(R.string.about_licenses_title),
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.semantics { heading() },
            )
            Column {
                licenses.forEach { entry ->
                    val isOpen = open == entry.name
                    ExpandableRow(
                        label = stringResource(R.string.about_license_entry, entry.name, entry.spdx),
                        isOpen = isOpen,
                        onToggle = { open = if (isOpen) null else entry.name },
                    )
                    if (isOpen) {
                        Text(
                            remember(entry.file) { context.assets.open("licenses/${entry.file}").bufferedReader().readText() },
                            style = MaterialTheme.typography.bodySmall,
                            fontFamily = FontFamily.Monospace,
                            modifier = Modifier.padding(bottom = 8.dp),
                        )
                    }
                }
            }
            Text(
                stringResource(R.string.about_version, BuildConfig.VERSION_NAME),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

/** Full-width 48dp row with a +/− marker and an Open/Closed state for screen readers (leaves/design.md). */
@Composable
private fun ExpandableRow(label: String, isOpen: Boolean, onToggle: () -> Unit) {
    val expanded = stringResource(R.string.a11y_expanded)
    val collapsed = stringResource(R.string.a11y_collapsed)
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp)
            .clickable(role = Role.Button, onClick = onToggle)
            .semantics { stateDescription = if (isOpen) expanded else collapsed }
            .padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.weight(1f),
        )
        Text(
            if (isOpen) "−" else "+",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.padding(start = 12.dp).clearAndSetSemantics {},
        )
    }
}

/**
 * spine: C3 — privacy policy text, derived from leaves/gtm/privacy-policy.html and updated for per-reply
 * reports. The hosted page and this text must say the same thing (checked by hand at release).
 */
@Composable
private fun PrivacyPolicy() {
    Column(Modifier.padding(bottom = 8.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            stringResource(R.string.privacy_intro, BuildConfig.VERSION_NAME),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        PRIVACY_SECTIONS.forEach { (title, body) ->
            Column {
                Text(stringResource(title), style = MaterialTheme.typography.titleSmall, modifier = Modifier.semantics { heading() })
                Text(
                    if (body == R.string.privacy_contact_body) stringResource(body, BuildConfig.REPORT_EMAIL) else stringResource(body),
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
        }
    }
}

private const val PRIVACY_KEY = "arivu:privacy-policy"

private val PRIVACY_SECTIONS = listOf(
    R.string.privacy_short_title to R.string.privacy_short_body,
    R.string.privacy_internet_title to R.string.privacy_internet_body,
    R.string.privacy_stored_title to R.string.privacy_stored_body,
    R.string.privacy_collect_title to R.string.privacy_collect_body,
    R.string.privacy_report_title to R.string.privacy_report_body,
    R.string.privacy_copy_title to R.string.privacy_copy_body,
    R.string.privacy_play_title to R.string.privacy_play_body,
    R.string.privacy_children_title to R.string.privacy_children_body,
    R.string.privacy_choices_title to R.string.privacy_choices_body,
    R.string.privacy_changes_title to R.string.privacy_changes_body,
    R.string.privacy_contact_title to R.string.privacy_contact_body,
)

@Composable
private fun Section(title: Int, body: Int) {
    Column {
        Text(stringResource(title), style = MaterialTheme.typography.titleMedium, modifier = Modifier.semantics { heading() })
        Text(stringResource(body), style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(top = 4.dp))
    }
}

private data class LicenseEntry(val name: String, val spdx: String, val file: String)

private fun loadLicenseIndex(context: Context): List<LicenseEntry> =
    context.assets.open("licenses/index.txt").bufferedReader().readLines()
        .filter { it.isNotBlank() }
        .map { it.split("|").let { p -> LicenseEntry(p[0], p[1], p[2]) } }
