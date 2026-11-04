package com.lyo.app.ui.classroom.catalog

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.ui.Alignment
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lyo.app.ui.theme.ClassroomTokens

/** Safe, native text rendering: no TeX engine, remote scripts, or code-fence artifacts. */
fun cleanClassroomText(source: String): String {
    val fence = 96.toChar().toString().repeat(3)
    return source.lineSequence()
        .filterNot { it.trim().startsWith("~~~") || it.trim().startsWith(fence) }
        .joinToString("\n")
        .replace(Regex("""\\frac\{([^{}]+)\}\{([^{}]+)\}"""), "$1 / $2")
        .replace("\\times", "×")
        .replace("\\cdot", "·")
        .replace("\\div", "÷")
        .replace("\\left", "")
        .replace("\\right", "")
        .replace("\\[", "")
        .replace("\\]", "")
        .replace("\\(", "")
        .replace("\\)", "")
        .replace("**", "")
        .trim()
}

/** Math is drawn with Android Compose typography, rather than a LaTeX WebView. */
@Composable
fun NativeMathNote(source: String, modifier: Modifier = Modifier) {
    val lines = cleanClassroomText(source).lines().map { it.trim() }.filter { it.isNotEmpty() }
    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        lines.forEach { line ->
            val equation = line.contains('=') && line.any(Char::isDigit)
            val fractions = Regex("""^(.+?)\s*/\s*(.+?)\s*=\s*(.+?)\s*/\s*(.+?)$""").matchEntire(line)
            if (fractions != null) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Center,
                    modifier = Modifier.fillMaxWidth().padding(vertical = 10.dp),
                ) {
                    NativeFraction(fractions.groupValues[1], fractions.groupValues[2])
                    Text("=", color = Color.White, fontSize = 23.sp, modifier = Modifier.padding(horizontal = 12.dp))
                    NativeFraction(fractions.groupValues[3], fractions.groupValues[4])
                }
            } else Text(
                text = line,
                color = Color.White,
                style = if (equation) MaterialTheme.typography.titleLarge else MaterialTheme.typography.bodyMedium,
                fontFamily = if (equation) FontFamily.Serif else FontFamily.Default,
                fontWeight = if (equation) FontWeight.Medium else FontWeight.Normal,
                fontSize = if (equation) 22.sp else 16.sp,
                textAlign = if (equation) TextAlign.Center else TextAlign.Start,
                softWrap = true,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        if (equation) ClassroomTokens.AccentPurple.copy(alpha = 0.10f)
                        else Color.Transparent,
                        RoundedCornerShape(10.dp),
                    )
                    .padding(horizontal = 10.dp, vertical = if (equation) 11.dp else 3.dp),
            )
        }
    }
}

fun looksLikeMathLesson(text: String): Boolean =
    text.contains('=') && text.any(Char::isDigit) &&
        !text.contains("fun ") && !text.contains("const ") && !text.contains("function ")

@Composable
private fun NativeFraction(numerator: String, denominator: String) {
    val barWidth = (maxOf(numerator.length, denominator.length) * 15).coerceIn(52, 126).dp
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(numerator.trim(), color = Color.White, fontSize = 21.sp, fontFamily = FontFamily.Serif)
        Spacer(Modifier.width(barWidth).height(1.dp).background(Color.White))
        Text(denominator.trim(), color = Color.White, fontSize = 21.sp, fontFamily = FontFamily.Serif)
    }
}
