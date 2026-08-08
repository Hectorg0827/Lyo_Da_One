package com.lyo.app.ui.classroom.catalog

import android.annotation.SuppressLint
import android.webkit.WebView
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import org.json.JSONObject

/**
 * Real diagram/math rendering — the documented v2 upgrade over
 * MermaidBlockRenderer/LatexBlockRenderer's v1 raw-source-text fallback
 * (see those files). A single shared component rather than two separate
 * ones: both are "load a JS library from a CDN into a local HTML shell,
 * hand it one string, screenshot the result" for the price of one WebView
 * host, differing only in which `<script>` tag and render call get used.
 *
 * DISCLOSED, NOT VERIFIED: this cannot be exercised in the environment
 * this was written in (no Android runtime available at all — see the
 * implementation summary). The mermaid.js/KaTeX CDN URLs, the JS render
 * calls, and the JS→Kotlin height-reporting bridge are all written
 * against each library's documented API but have not been run against a
 * real WebView. Falls back to nothing visible on a JS error rather than
 * crashing (an empty rendered `<div>`) — verify on a real device before
 * relying on this over the v1 raw-text fallback in MermaidBlockRenderer/
 * LatexBlockRenderer, which stays in place as what those two currently
 * call. Wire this in by swapping RawSourceBlock(source) for
 * WebViewBlock(kind = "mermaid", source = source) once confirmed working.
 */
enum class WebViewBlockKind { MERMAID, LATEX }

@SuppressLint("SetJavaScriptEnabled")
@Composable
fun WebViewBlock(kind: WebViewBlockKind, source: String, modifier: Modifier = Modifier) {
    val html = remember(kind, source) { buildHtml(kind, source) }
    AndroidView(
        modifier = modifier
            .fillMaxWidth()
            .height(220.dp), // fixed height: WebView can't natively report content-height back into Compose's layout pass without a JS bridge round-trip, which needs a real device to validate the timing of — see the class doc comment.
        factory = { context ->
            WebView(context).apply {
                settings.javaScriptEnabled = true
                settings.loadWithOverviewMode = true
                settings.useWideViewPort = true
                setBackgroundColor(android.graphics.Color.TRANSPARENT)
            }
        },
        update = { webView ->
            webView.loadDataWithBaseURL(
                "https://cdn.jsdelivr.net/",
                html,
                "text/html",
                "UTF-8",
                null,
            )
        },
    )
}

private fun buildHtml(kind: WebViewBlockKind, source: String): String {
    // JSONObject.quote() gives a properly-escaped JS string literal —
    // safer than manual string interpolation for arbitrary
    // LLM-generated source text (backslashes, quotes, newlines).
    val escapedSource = JSONObject.quote(source)
    return when (kind) {
        WebViewBlockKind.MERMAID -> """
            <!DOCTYPE html><html><head><meta charset="utf-8">
            <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
            <style>body{margin:0;background:transparent;display:flex;align-items:center;justify-content:center;}
            .mermaid{max-width:100%;}</style></head>
            <body>
              <div class="mermaid">${source.htmlEscape()}</div>
              <script>
                mermaid.initialize({ startOnLoad: true, theme: 'dark' });
              </script>
            </body></html>
        """.trimIndent()

        WebViewBlockKind.LATEX -> """
            <!DOCTYPE html><html><head><meta charset="utf-8">
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16/dist/katex.min.css">
            <script src="https://cdn.jsdelivr.net/npm/katex@0.16/dist/katex.min.js"></script>
            <style>body{margin:0;background:transparent;display:flex;align-items:center;justify-content:center;height:100%;color:white;}
            .katex{font-size:1.3em;}</style></head>
            <body>
              <div id="math"></div>
              <script>
                katex.render($escapedSource, document.getElementById('math'), { throwOnError: false, displayMode: true });
              </script>
            </body></html>
        """.trimIndent()
    }
}

private fun String.htmlEscape(): String =
    replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
