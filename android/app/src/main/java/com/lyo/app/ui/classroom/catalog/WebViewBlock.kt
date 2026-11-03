package com.lyo.app.ui.classroom.catalog

import android.annotation.SuppressLint
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
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
enum class WebViewBlockKind { MERMAID, LATEX, RICH }

@SuppressLint("SetJavaScriptEnabled")
@Composable
fun WebViewBlock(kind: WebViewBlockKind, source: String, modifier: Modifier = Modifier) {
    val html = remember(kind, source) { buildHtml(kind, source) }
    var contentHeight by remember(kind, source) { mutableIntStateOf(if (kind == WebViewBlockKind.MERMAID) 220 else 90) }
    AndroidView(
        modifier = modifier
            .fillMaxWidth()
            .height(contentHeight.coerceIn(58, 850).dp),
        factory = { context ->
            WebView(context).apply {
                settings.javaScriptEnabled = true
                settings.loadWithOverviewMode = true
                settings.useWideViewPort = true
                setBackgroundColor(android.graphics.Color.TRANSPARENT)
                webViewClient = object : WebViewClient() {
                    override fun onPageFinished(view: WebView?, url: String?) {
                        view?.evaluateJavascript(
                            "(function(){return Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)})()",
                        ) { result ->
                            result.trim('"').toDoubleOrNull()?.let { height ->
                                contentHeight = (height + 18).toInt().coerceIn(58, 850)
                            }
                        }
                    }
                }
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

private fun buildHtml(kind: WebViewBlockKind, source: String): String {
    // JSONObject.quote() gives a properly-escaped JS string literal —
    // safer than manual string interpolation for arbitrary
    // LLM-generated source text (backslashes, quotes, newlines).
    val escapedSource = JSONObject.quote(source)
    return when (kind) {
        WebViewBlockKind.RICH -> {
            // All generated text is HTML-escaped before adding our own vetted tags.
            // KaTeX auto-render understands both inline $...$ and display $...$,
            // including formulas embedded in ordinary Markdown lesson prose.
            val safe = source.htmlEscape()
                .replace(Regex("""\*\*([^*]+)\*\*"""), "<strong>$1</strong>")
                .lineSequence()
                .filterNot { it.trim().startsWith("~~~") || it.trim().startsWith("``") }
                .joinToString("<br>")
                .replace(Regex("""(^|<br>)#{1,4}s+"""), "$1")
            """
                <!DOCTYPE html><html><head><meta charset="utf-8">
                <meta name="viewport" content="width=device-width,initial-scale=1">
                <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16/dist/katex.min.css">
                <script src="https://cdn.jsdelivr.net/npm/katex@0.16/dist/katex.min.js"></script>
                <script src="https://cdn.jsdelivr.net/npm/katex@0.16/dist/contrib/auto-render.min.js"></script>
                <style>
                body{margin:0;padding:4px;background:transparent;color:#f4f1ff;
                    font:16px/1.55 system-ui, sans-serif;overflow-wrap:anywhere;}
                strong{font-weight:750;color:#fff;}
                .katex-display{margin:13px 0;overflow-x:auto;overflow-y:hidden;
                    text-align:center;font-size:1.28em;}
                .katex{color:#fff;max-width:100%;}
                #lesson{white-space:normal;}
                </style></head><body>
                <div id="lesson">$safe</div>
                <script>
                function renderLesson() {
                  var root=document.getElementById('lesson');
                  if (typeof renderMathInElement === 'function') {
                    renderMathInElement(root,{delimiters:[
                      {left:'$',right:'$',display:true},
                      {left:'\[',right:'\]',display:true},
                      {left:'\(',right:'\)',display:false},
                      {left:' """
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
,right:' """
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
,display:false}
                    ],throwOnError:false,strict:'ignore'});
                  } else {
                    // Offline fallback: remove the syntactic wrappers so the
                    // student never sees dollar-sign markup.
                    root.innerHTML=root.innerHTML.replace(/$/g,'').replace(/\[/g,'')
                      .replace(/\]/g,'').replace(/$/g,'')
                      .replace(/\frac{([^{}]+)}{([^{}]+)}/g,'($1 / $2)');
                  }
                  requestAnimationFrame(function(){document.title=String(document.body.scrollHeight);});
                }
                if(document.readyState === 'loading')
                  document.addEventListener('DOMContentLoaded',renderLesson);
                else renderLesson();
                </script></body></html>
            """.trimIndent()
        }
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
