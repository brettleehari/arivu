package io.github.brettleehari.arivu.app.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// spine: C8 — no themes. Follows the system light/dark setting only; no dynamic colour, so the brand
// and the contrast checks below hold on every OEM skin.
//
// Every role a component on our three screens reads is set explicitly, so no Material baseline
// purple leaks in. Text pairs checked against WCAG 2.1 AA (>= 4.5:1 body, >= 3:1 outlines/large);
// ratios are recorded in leaves/design.md §Colour and contrast. Window background in
// res/values*/colors.xml must match `surface`/`background`.

private val Light = lightColorScheme(
    primary = Color(0xFF1F5C4A),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFD3E8DF),
    onPrimaryContainer = Color(0xFF0B2A20),
    secondary = Color(0xFF4A6359),
    onSecondary = Color.White,
    secondaryContainer = Color(0xFFDCE6E0),
    onSecondaryContainer = Color(0xFF14201B),
    background = Color(0xFFFBFAF7),
    onBackground = Color(0xFF1B1C1A),
    surface = Color(0xFFFBFAF7),
    onSurface = Color(0xFF1B1C1A),
    surfaceVariant = Color(0xFFEDEBE5),
    onSurfaceVariant = Color(0xFF4A4843),
    surfaceContainerLowest = Color(0xFFFFFFFF),
    surfaceContainerLow = Color(0xFFF6F4F0),
    surfaceContainer = Color(0xFFF1EFEA),
    surfaceContainerHigh = Color(0xFFEBE9E4),
    surfaceContainerHighest = Color(0xFFE5E3DE),
    outline = Color(0xFF78766F),
    outlineVariant = Color(0xFFCAC7BF),
    error = Color(0xFFB3261E),
    onError = Color.White,
    errorContainer = Color(0xFFF9DEDC),
    onErrorContainer = Color(0xFF410E0B),
)

private val Dark = darkColorScheme(
    primary = Color(0xFF8FCFB6),
    onPrimary = Color(0xFF06251B),
    primaryContainer = Color(0xFF1F4A3C),
    onPrimaryContainer = Color(0xFFD3E8DF),
    secondary = Color(0xFFB2CCC0),
    onSecondary = Color(0xFF1D352C),
    secondaryContainer = Color(0xFF334B42),
    onSecondaryContainer = Color(0xFFCEE9DC),
    background = Color(0xFF141513),
    onBackground = Color(0xFFE4E2DC),
    surface = Color(0xFF141513),
    onSurface = Color(0xFFE4E2DC),
    surfaceVariant = Color(0xFF2A2B28),
    onSurfaceVariant = Color(0xFFC9C6BE),
    surfaceContainerLowest = Color(0xFF0F100E),
    surfaceContainerLow = Color(0xFF1B1C1A),
    surfaceContainer = Color(0xFF1F201E),
    surfaceContainerHigh = Color(0xFF292A28),
    surfaceContainerHighest = Color(0xFF343532),
    outline = Color(0xFF939089),
    outlineVariant = Color(0xFF48473F),
    error = Color(0xFFF2B8B5),
    onError = Color(0xFF601410),
    errorContainer = Color(0xFF8C1D18),
    onErrorContainer = Color(0xFFF9DEDC),
)

@Composable
fun ArivuTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = if (isSystemInDarkTheme()) Dark else Light, content = content)
}
