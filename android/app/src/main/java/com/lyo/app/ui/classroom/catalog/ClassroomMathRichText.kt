package com.lyo.app.ui.classroom.catalog

import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import com.lyo.app.ui.theme.TextPrimary

/**
 * Real KaTeX for delimited inline/display formulas in Classroom copy,
 * with immediately visible, accessible, offline math text in the WebView.
 * Ordinary prose stays native Compose text, retaining typography and scroll.
 */
@Composable
fun ClassroomMathRichText(
    text: String,
    modifier: Modifier = Modifier,
    color: Color = TextPrimary,
    style: TextStyle = LocalTextStyle.current,
) {
    if (hasClassroomMath(text)) {
        WebViewBlock(WebViewBlockKind.MATH_TEXT, text, modifier)
    } else {
        Text(readableClassroomMath(text), modifier = modifier, color = color, style = style)
    }
}
