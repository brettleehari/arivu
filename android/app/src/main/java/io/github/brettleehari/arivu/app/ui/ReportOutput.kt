package io.github.brettleehari.arivu.app.ui

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.annotation.StringRes
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.paneTitle
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import io.github.brettleehari.arivu.app.BuildConfig
import io.github.brettleehari.arivu.app.R

/** Why a reply is being reported. Order is the order of the chips. spine: C9 */
enum class ReportReason(@StringRes val label: Int) {
    OFFENSIVE(R.string.report_reason_offensive),
    HARMFUL(R.string.report_reason_harmful),
    WRONG_DANGEROUS(R.string.report_reason_wrong_dangerous),
    OTHER(R.string.report_reason_other),
}

/** A report about one specific reply; null in [reportOutput] means the general report from About. */
data class ReplyReport(val replyText: String, val reason: ReportReason, val note: String)

/**
 * Play AI-generated content policy: in-app reporting. No INTERNET permission, so this hands a
 * pre-filled report to the user's own email app; nothing is sent without them (spine: C3, C9).
 * Email apps are chosen through a mailto: selector so subject and body arrive intact; with no email app,
 * the share sheet is the fallback and the address is written into the text.
 */
fun reportOutput(context: Context, report: ReplyReport? = null) {
    val subject = context.getString(R.string.about_report_subject)
    val body = if (report == null) {
        context.getString(R.string.about_report_template, BuildConfig.VERSION_NAME)
    } else {
        context.getString(
            R.string.report_reply_template,
            BuildConfig.VERSION_NAME,
            context.getString(report.reason.label),
            report.note.trim().ifEmpty { context.getString(R.string.report_no_note) },
            report.replyText,
        )
    }
    val email = Intent(Intent.ACTION_SEND).apply {
        putExtra(Intent.EXTRA_EMAIL, arrayOf(BuildConfig.REPORT_EMAIL))
        putExtra(Intent.EXTRA_SUBJECT, subject)
        putExtra(Intent.EXTRA_TEXT, body)
        selector = Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:"))
    }
    try {
        context.startActivity(email)
    } catch (_: ActivityNotFoundException) {
        val share = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_SUBJECT, subject)
            putExtra(Intent.EXTRA_TEXT, context.getString(R.string.report_share_prefix, BuildConfig.REPORT_EMAIL, body))
        }
        context.startActivity(Intent.createChooser(share, subject))
    }
}

/**
 * spine: C9 — the in-app report sheet for one reply: reason chips, optional note, then the user's email app.
 * Nothing leaves the phone from here; [onReported] marks the reply locally before the hand-off.
 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun ReportSheet(replyText: String, onDismiss: () -> Unit, onReported: () -> Unit) {
    val context = LocalContext.current
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var reason by rememberSaveable { mutableStateOf<ReportReason?>(null) }
    var note by rememberSaveable { mutableStateOf("") }
    val title = stringResource(R.string.report_sheet_title)

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            Modifier
                .fillMaxWidth()
                .semantics { paneTitle = title }
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp)
                .padding(bottom = 16.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(title, style = MaterialTheme.typography.titleLarge, modifier = Modifier.semantics { heading() })
            Text(stringResource(R.string.report_sheet_body), style = MaterialTheme.typography.bodyMedium)
            Text(
                stringResource(R.string.report_reason_label),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            FlowRow(
                Modifier.fillMaxWidth().selectableGroup(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                ReportReason.entries.forEach { r ->
                    FilterChip(
                        selected = reason == r,
                        onClick = { reason = r },
                        label = { Text(stringResource(r.label)) },
                        modifier = Modifier
                            .heightIn(min = 48.dp)
                            .semantics { role = Role.RadioButton; selected = reason == r },
                    )
                }
            }
            OutlinedTextField(
                value = note,
                onValueChange = { note = it },
                label = { Text(stringResource(R.string.report_note_label)) },
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                maxLines = 4,
                modifier = Modifier.fillMaxWidth(),
            )
            Text(
                stringResource(R.string.report_sheet_privacy),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp, androidx.compose.ui.Alignment.End)) {
                TextButton(onClick = onDismiss, modifier = Modifier.heightIn(min = 48.dp)) { Text(stringResource(R.string.cancel)) }
                Button(
                    onClick = {
                        val r = reason ?: return@Button
                        onReported()
                        reportOutput(context, ReplyReport(replyText, r, note))
                        onDismiss()
                    },
                    enabled = reason != null,
                    modifier = Modifier.heightIn(min = 48.dp),
                ) { Text(stringResource(R.string.report_send)) }
            }
        }
    }
}
