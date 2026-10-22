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
 * Shared visual rendering surface for Classroom and Chat. Mermaid and KaTeX
 * render in a constrained WebView, with legible source fallback when JavaScript
 * or the external library cannot load (offline, CSP or network failure).
 *
 * Device-level WebView validation is still required before deployment.
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
            // Compose may recompose while the learner is answering. Re-loading
            // a WebView on every recomposition erases the diagram and flickers.
            if (webView.tag != html) {
                webView.tag = html
                webView.loadDataWithBaseURL(
                    "https://cdn.jsdelivr.net/",
                    html,
                    "text/html",
                    "UTF-8",
                    null,
                )
            }
        },
    )
}


/**
 * KaTeX's render() expects the TeX body, not delimiters used by Markdown or
 * model output. Keep unmatched wrappers intact rather than deleting content.
 * Shared by Chat and Classroom through WebViewBlock.
 */
internal fun normalizeKaTeXSource(raw: String): String {
    val source = raw.trim()
    return when {
        source.length >= 4 && source.startsWith("$" + "$") && source.endsWith("$" + "$") ->
            source.substring(2, source.length - 2).trim()
        source.length >= 4 && source.startsWith("\\[") && source.endsWith("\\]") ->
            source.substring(2, source.length - 2).trim()
        source.length >= 4 && source.startsWith("\\(") && source.endsWith("\\)") ->
            source.substring(2, source.length - 2).trim()
        source.length >= 2 && source.startsWith("$") && source.endsWith("$") ->
            source.substring(1, source.length - 1).trim()
        else -> source
    }
}

private fun buildHtml(kind: WebViewBlockKind, source: String): String {
    // JSONObject.quote() gives a properly-escaped JS string literal —
    // safer than manual string interpolation for arbitrary
    // LLM-generated source text (backslashes, quotes, newlines).
    val escapedSource = JSONObject.quote(if (kind == WebViewBlockKind.LATEX) normalizeKaTeXSource(source) else source)
    return when (kind) {
        WebViewBlockKind.MERMAID -> """
            <!DOCTYPE html><html><head><meta charset="utf-8">
            <meta name="viewport" content="width=device-width,initial-scale=1">
            <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
            <style>body{margin:0;padding:8px;background:transparent;color:#eee;font:13px sans-serif;}
            #diagram{max-width:100%;overflow:auto}#diagram svg{max-width:100%;height:auto}
            #fallback{display:none;white-space:pre-wrap;overflow-wrap:anywhere}</style></head>
            <body>
              <div id="diagram" class="mermaid">${source.htmlEscape()}</div>
              <pre id="fallback">${source.htmlEscape()}</pre>
              <script>
                function showFallback(){
                  document.getElementById('diagram').style.display='none';
                  document.getElementById('fallback').style.display='block';
                }
                window.addEventListener('load',function(){
                  if(typeof mermaid==='undefined'){showFallback();return;}
                  try{
                    mermaid.initialize({startOnLoad:false,securityLevel:'strict',theme:'dark'});
                    mermaid.run({nodes:[document.getElementById('diagram')]}).catch(showFallback);
                  }catch(e){showFallback();}
                });
              </script>
            </body></html>
        """.trimIndent()

        WebViewBlockKind.LATEX -> """
            <!DOCTYPE html><html><head><meta charset="utf-8">
            <meta name="viewport" content="width=device-width,initial-scale=1">
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16/dist/katex.min.css">
            <script src="https://cdn.jsdelivr.net/npm/katex@0.16/dist/katex.min.js"></script>
            <style>body{margin:0;padding:8px;background:transparent;color:#eee;font:13px sans-serif}
            #fallback{display:none;white-space:pre-wrap;overflow-wrap:anywhere}</style></head>
            <body>
              <div id="math"></div>
              <pre id="fallback">${source.htmlEscape()}</pre>
              <script>
                try {
                  if (typeof katex==='undefined') throw new Error('KaTeX unavailable');
                  katex.render($escapedSource,document.getElementById('math'),{
                    throwOnError:false,displayMode:true
                  });
                } catch(e) {
                  document.getElementById('math').style.display='none';
                  document.getElementById('fallback').style.display='block';
                }
              </script>
            </body></html>
        """.trimIndent()
    }
}

private fun String.htmlEscape(): String =
    replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
