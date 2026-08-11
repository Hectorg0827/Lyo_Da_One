package com.lyo.app.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.background
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// ── Pure parsing — no Compose dependency, directly unit-testable ────────────
// (see MarkdownParserTest / MarkdownInlineParserTest).

/** One block-level element of parsed markdown. */
sealed class MarkdownBlock {
    data class Heading(val level: Int, val text: String) : MarkdownBlock()
    data class Paragraph(val text: String) : MarkdownBlock()
    data class BulletItem(val text: String) : MarkdownBlock()
    data class NumberedItem(val number: Int, val text: String) : MarkdownBlock()
    data class CodeBlock(val language: String?, val code: String) : MarkdownBlock()
    data class Blockquote(val text: String) : MarkdownBlock()
}

/**
 * A minimal, dependency-free block-level markdown parser covering the
 * subset chat lessons actually use: headings, paragraphs, bullet/numbered
 * lists, fenced code blocks, and blockquotes.
 *
 * Deliberately does not attempt GFM tables or LaTeX math — web renders both
 * via browser-only libraries (remark-gfm, KaTeX), and iOS doesn't render
 * real LaTeX either (UnifiedBlockRenderer.swift's dataViz "math" case is a
 * plain-text fallback). Matching that same, already-shipped scope here
 * rather than reaching for a WebView-based renderer that has not been
 * verified on a real device (see WebViewBlock.kt's own disclosure).
 */
object MarkdownParser {
    private val numberedItem = Regex("""^(\d+)\.\s+(.*)$""")

    fun parseBlocks(markdown: String): List<MarkdownBlock> {
        val blocks = mutableListOf<MarkdownBlock>()
        val lines = markdown.replace("\r\n", "\n").split("\n")
        var i = 0
        val paragraph = StringBuilder()

        fun flushParagraph() {
            if (paragraph.isNotBlank()) {
                blocks.add(MarkdownBlock.Paragraph(paragraph.toString().trim()))
            }
            paragraph.clear()
        }

        while (i < lines.size) {
            val trimmed = lines[i].trim()
            when {
                trimmed.isBlank() -> {
                    flushParagraph()
                    i++
                }
                trimmed.startsWith("```") -> {
                    flushParagraph()
                    val language = trimmed.removePrefix("```").trim().ifBlank { null }
                    val code = StringBuilder()
                    i++
                    while (i < lines.size && !lines[i].trim().startsWith("```")) {
                        if (code.isNotEmpty()) code.append('\n')
                        code.append(lines[i])
                        i++
                    }
                    i++ // skip the closing fence (or end of input if unterminated)
                    blocks.add(MarkdownBlock.CodeBlock(language, code.toString()))
                }
                trimmed.startsWith("#") -> {
                    flushParagraph()
                    val level = trimmed.takeWhile { it == '#' }.length.coerceIn(1, 6)
                    blocks.add(MarkdownBlock.Heading(level, trimmed.drop(level).trim()))
                    i++
                }
                trimmed.startsWith("> ") || trimmed == ">" -> {
                    flushParagraph()
                    blocks.add(MarkdownBlock.Blockquote(trimmed.removePrefix(">").trim()))
                    i++
                }
                trimmed.startsWith("- ") || trimmed.startsWith("* ") -> {
                    flushParagraph()
                    blocks.add(MarkdownBlock.BulletItem(trimmed.drop(2).trim()))
                    i++
                }
                numberedItem.matches(trimmed) -> {
                    flushParagraph()
                    val match = numberedItem.find(trimmed)!!
                    val number = match.groupValues[1].toIntOrNull()
                        ?: (blocks.count { it is MarkdownBlock.NumberedItem } + 1)
                    blocks.add(MarkdownBlock.NumberedItem(number, match.groupValues[2].trim()))
                    i++
                }
                else -> {
                    if (paragraph.isNotEmpty()) paragraph.append(' ')
                    paragraph.append(trimmed)
                    i++
                }
            }
        }
        flushParagraph()
        return blocks
    }
}

/** One inline styled run within a markdown block's text. */
sealed class MarkdownSpan {
    data class Plain(val text: String) : MarkdownSpan()
    data class Bold(val text: String) : MarkdownSpan()
    data class Italic(val text: String) : MarkdownSpan()
    data class BoldItalic(val text: String) : MarkdownSpan()
    data class Code(val text: String) : MarkdownSpan()
}

/** Inline emphasis/code within a single line — bold, italic, and inline code. */
object MarkdownInlineParser {
    // Order matters: bold+italic before bold before italic before code, so
    // "***x***" doesn't get eaten by the plain "**" rule first.
    private val token = Regex(
        """(\*\*\*(.+?)\*\*\*)|(\*\*(.+?)\*\*)|(\*(.+?)\*)|(`(.+?)`)""",
    )

    fun parse(text: String): List<MarkdownSpan> {
        val spans = mutableListOf<MarkdownSpan>()
        var lastIndex = 0
        for (match in token.findAll(text)) {
            if (match.range.first > lastIndex) {
                spans.add(MarkdownSpan.Plain(text.substring(lastIndex, match.range.first)))
            }
            val groups = match.groupValues
            when {
                groups[1].isNotEmpty() -> spans.add(MarkdownSpan.BoldItalic(groups[2]))
                groups[3].isNotEmpty() -> spans.add(MarkdownSpan.Bold(groups[4]))
                groups[5].isNotEmpty() -> spans.add(MarkdownSpan.Italic(groups[6]))
                groups[7].isNotEmpty() -> spans.add(MarkdownSpan.Code(groups[8]))
            }
            lastIndex = match.range.last + 1
        }
        if (lastIndex < text.length) spans.add(MarkdownSpan.Plain(text.substring(lastIndex)))
        return spans
    }
}

// ── Compose rendering ────────────────────────────────────────────────────────

/**
 * Renders a markdown string as styled Compose text — headings, paragraphs,
 * lists, fenced code blocks, blockquotes, and inline bold/italic/code.
 *
 * The structured-lesson text block content (hook/callout/summary beats, quiz
 * questions and explanations) is written in this same markdown web and iOS
 * already render; without this it was shown as literal `**bold**` /
 * `` `code` `` asterisks and backticks.
 */
@Composable
fun MarkdownText(
    markdown: String,
    modifier: Modifier = Modifier,
    color: Color = LocalContentColor.current,
) {
    val blocks = remember(markdown) { MarkdownParser.parseBlocks(markdown) }
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        blocks.forEach { block -> MarkdownBlockView(block, color) }
    }
}

@Composable
private fun MarkdownBlockView(block: MarkdownBlock, color: Color) {
    when (block) {
        is MarkdownBlock.Heading -> Text(
            text = inlineAnnotatedString(block.text, color),
            style = when (block.level) {
                1 -> MaterialTheme.typography.titleLarge
                2 -> MaterialTheme.typography.titleMedium
                else -> MaterialTheme.typography.titleSmall
            },
            color = color,
        )

        is MarkdownBlock.Paragraph -> Text(
            text = inlineAnnotatedString(block.text, color),
            style = MaterialTheme.typography.bodyMedium,
            color = color,
        )

        is MarkdownBlock.BulletItem -> Row {
            Text("•  ", style = MaterialTheme.typography.bodyMedium, color = color)
            Text(inlineAnnotatedString(block.text, color), style = MaterialTheme.typography.bodyMedium, color = color)
        }

        is MarkdownBlock.NumberedItem -> Row {
            Text("${block.number}.  ", style = MaterialTheme.typography.bodyMedium, color = color)
            Text(inlineAnnotatedString(block.text, color), style = MaterialTheme.typography.bodyMedium, color = color)
        }

        is MarkdownBlock.Blockquote -> Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(color.copy(alpha = 0.08f), RoundedCornerShape(10.dp))
                .padding(10.dp),
        ) {
            Text(
                text = inlineAnnotatedString(block.text, color),
                style = MaterialTheme.typography.bodyMedium,
                color = color.copy(alpha = 0.8f),
                fontStyle = FontStyle.Italic,
            )
        }

        is MarkdownBlock.CodeBlock -> Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color.Black.copy(alpha = 0.35f), RoundedCornerShape(10.dp))
                .padding(12.dp),
        ) {
            if (block.language != null) {
                Text(
                    text = block.language.uppercase(),
                    fontFamily = FontFamily.Monospace,
                    fontSize = 11.sp,
                    color = color.copy(alpha = 0.6f),
                )
            }
            Text(
                text = block.code,
                fontFamily = FontFamily.Monospace,
                fontSize = 13.sp,
                color = color,
            )
        }
    }
}

private fun inlineAnnotatedString(text: String, color: Color): AnnotatedString = buildAnnotatedString {
    MarkdownInlineParser.parse(text).forEach { span ->
        when (span) {
            is MarkdownSpan.Plain -> append(span.text)
            is MarkdownSpan.Bold -> withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(span.text) }
            is MarkdownSpan.Italic -> withStyle(SpanStyle(fontStyle = FontStyle.Italic)) { append(span.text) }
            is MarkdownSpan.BoldItalic -> withStyle(
                SpanStyle(fontWeight = FontWeight.Bold, fontStyle = FontStyle.Italic),
            ) { append(span.text) }
            is MarkdownSpan.Code -> withStyle(
                SpanStyle(fontFamily = FontFamily.Monospace, background = color.copy(alpha = 0.14f)),
            ) { append(span.text) }
        }
    }
}
