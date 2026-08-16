package com.lyo.app.ui.components

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Coverage for MarkdownParser/MarkdownInlineParser — the block- and
 * inline-level parsing MarkdownText renders. Kept pure (no Compose types)
 * so it's plain-JUnit testable; the Composable layer that turns these
 * results into AnnotatedString/Text is exercised by inspection instead,
 * same tradeoff ExpressionEvaluatorTest makes for ExplorableBlock's plot.
 */
class MarkdownParserTest {

    // ── Block-level ──────────────────────────────────────────────────────

    @Test
    fun `parses a plain paragraph`() {
        val blocks = MarkdownParser.parseBlocks("Just a sentence.")
        assertEquals(listOf(MarkdownBlock.Paragraph("Just a sentence.")), blocks)
    }

    @Test
    fun `joins wrapped lines into one paragraph`() {
        val blocks = MarkdownParser.parseBlocks("Line one\nLine two")
        assertEquals(listOf(MarkdownBlock.Paragraph("Line one Line two")), blocks)
    }

    @Test
    fun `blank line separates paragraphs`() {
        val blocks = MarkdownParser.parseBlocks("First.\n\nSecond.")
        assertEquals(
            listOf(MarkdownBlock.Paragraph("First."), MarkdownBlock.Paragraph("Second.")),
            blocks,
        )
    }

    @Test
    fun `parses headings by level`() {
        val blocks = MarkdownParser.parseBlocks("# H1\n## H2\n### H3\n###### H6")
        assertEquals(
            listOf(
                MarkdownBlock.Heading(1, "H1"),
                MarkdownBlock.Heading(2, "H2"),
                MarkdownBlock.Heading(3, "H3"),
                MarkdownBlock.Heading(6, "H6"),
            ),
            blocks,
        )
    }

    @Test
    fun `parses bullet list items with either marker`() {
        val blocks = MarkdownParser.parseBlocks("- first\n* second")
        assertEquals(
            listOf(MarkdownBlock.BulletItem("first"), MarkdownBlock.BulletItem("second")),
            blocks,
        )
    }

    @Test
    fun `parses numbered list items preserving their number`() {
        val blocks = MarkdownParser.parseBlocks("1. one\n2. two\n5. five")
        assertEquals(
            listOf(
                MarkdownBlock.NumberedItem(1, "one"),
                MarkdownBlock.NumberedItem(2, "two"),
                MarkdownBlock.NumberedItem(5, "five"),
            ),
            blocks,
        )
    }

    @Test
    fun `parses a blockquote`() {
        val blocks = MarkdownParser.parseBlocks("> A trap to watch for.")
        assertEquals(listOf(MarkdownBlock.Blockquote("A trap to watch for.")), blocks)
    }

    @Test
    fun `parses a fenced code block with a language tag`() {
        val blocks = MarkdownParser.parseBlocks("```python\nprint('hi')\nx = 1\n```")
        assertEquals(
            listOf(MarkdownBlock.CodeBlock("python", "print('hi')\nx = 1")),
            blocks,
        )
    }

    @Test
    fun `parses a fenced code block without a language tag`() {
        val blocks = MarkdownParser.parseBlocks("```\nplain\n```")
        assertEquals(listOf(MarkdownBlock.CodeBlock(null, "plain")), blocks)
    }

    @Test
    fun `an unterminated code fence still returns everything after it as code`() {
        // A malformed/truncated block must not crash or silently drop content.
        val blocks = MarkdownParser.parseBlocks("```\nline one\nline two")
        assertEquals(listOf(MarkdownBlock.CodeBlock(null, "line one\nline two")), blocks)
    }

    @Test
    fun `mixed lesson content parses into the right sequence of blocks`() {
        val markdown = """
            # Solving for x

            Isolate the variable.

            - Move constants first
            - Then divide

            > Watch the sign flip on division by a negative.
        """.trimIndent()

        val blocks = MarkdownParser.parseBlocks(markdown)

        assertEquals(
            listOf(
                MarkdownBlock.Heading(1, "Solving for x"),
                MarkdownBlock.Paragraph("Isolate the variable."),
                MarkdownBlock.BulletItem("Move constants first"),
                MarkdownBlock.BulletItem("Then divide"),
                MarkdownBlock.Blockquote("Watch the sign flip on division by a negative."),
            ),
            blocks,
        )
    }

    @Test
    fun `blank input parses to no blocks`() {
        assertEquals(emptyList<MarkdownBlock>(), MarkdownParser.parseBlocks(""))
        assertEquals(emptyList<MarkdownBlock>(), MarkdownParser.parseBlocks("   \n  \n"))
    }

    // ── Inline ───────────────────────────────────────────────────────────

    @Test
    fun `plain text with no markup is a single plain span`() {
        val spans = MarkdownInlineParser.parse("just words")
        assertEquals(listOf(MarkdownSpan.Plain("just words")), spans)
    }

    @Test
    fun `parses bold, italic, and inline code`() {
        val spans = MarkdownInlineParser.parse("**bold** *italic* `code`")
        assertEquals(
            listOf(
                MarkdownSpan.Bold("bold"),
                MarkdownSpan.Plain(" "),
                MarkdownSpan.Italic("italic"),
                MarkdownSpan.Plain(" "),
                MarkdownSpan.Code("code"),
            ),
            spans,
        )
    }

    @Test
    fun `parses bold-italic as a single combined span`() {
        val spans = MarkdownInlineParser.parse("***everything***")
        assertEquals(listOf(MarkdownSpan.BoldItalic("everything")), spans)
    }

    @Test
    fun `preserves surrounding plain text around emphasis`() {
        val spans = MarkdownInlineParser.parse("solve for **x** here")
        assertEquals(
            listOf(
                MarkdownSpan.Plain("solve for "),
                MarkdownSpan.Bold("x"),
                MarkdownSpan.Plain(" here"),
            ),
            spans,
        )
    }
}
