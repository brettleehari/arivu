package io.github.brettleehari.arivu.app.ui

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.text.format.Formatter
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.core.net.toUri
import io.github.brettleehari.arivu.app.R
import io.github.brettleehari.arivu.app.gate.GateFailure

/**
 * spine: C6, R8 — one plain screen, which check failed and why, one button to uninstall.
 * No "continue anyway". No close button. No crash, no System.exit().
 * Edge-to-edge: content stays clear of status bar, navigation bar and cutouts; scrolls at 200% text.
 */
@Composable
fun IncompatibleScreen(failure: GateFailure) {
    val context = LocalContext.current
    Surface(Modifier.fillMaxSize()) {
        Column(
            Modifier
                .fillMaxSize()
                .safeDrawingPadding()
                .verticalScroll(rememberScrollState())
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text(
                stringResource(R.string.incompatible_title),
                style = MaterialTheme.typography.headlineSmall,
                modifier = Modifier.semantics { heading() },
            )
            Text(reason(failure), style = MaterialTheme.typography.bodyLarge)
            Text(stringResource(R.string.incompatible_body), style = MaterialTheme.typography.bodyMedium)
            Button(onClick = { uninstallSelf(context) }, modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
                Text(stringResource(R.string.incompatible_uninstall))
            }
        }
    }
}

@Composable
private fun reason(f: GateFailure): String {
    val context = LocalContext.current
    return when (f) {
        GateFailure.NoArm64 -> stringResource(R.string.gate_abi)
        GateFailure.LowRamDevice -> stringResource(R.string.gate_low_ram)
        is GateFailure.TotalRam -> stringResource(
            R.string.gate_total_ram,
            Formatter.formatShortFileSize(context, f.actualBytes),
            Formatter.formatShortFileSize(context, f.requiredBytes),
        )
        is GateFailure.Storage -> stringResource(
            R.string.gate_storage,
            Formatter.formatShortFileSize(context, f.actualBytes),
            Formatter.formatShortFileSize(context, f.requiredBytes),
        )
    }
}

/** ACTION_DELETE for our own package (D-006); app settings page if the uninstaller refuses. */
private fun uninstallSelf(context: Context) {
    val pkg = "package:${context.packageName}".toUri()
    try {
        context.startActivity(Intent(Intent.ACTION_DELETE, pkg))
    } catch (_: ActivityNotFoundException) {
        context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg))
    }
}
