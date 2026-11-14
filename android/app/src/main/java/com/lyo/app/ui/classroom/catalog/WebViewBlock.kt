package com.lyo.app.ui.classroom.catalog

import android.annotation.SuppressLint
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import androidx.webkit.WebViewAssetLoader
import android.webkit.WebViewClient
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import org.json.JSONObject

/**
 * Classroom math and diagrams. Math has readable text in the initial HTML,
 * BEFORE a remote CSS/JS library can load: no network/JS means not a blank card.
 * Bundled KaTeX enhances that same DOM from APK assets, even offline.
 */
enum class WebViewBlockKind { MERMAID, LATEX, MATH_TEXT }

@SuppressLint("SetJavaScriptEnabled")
@Composable
fun WebViewBlock(kind: WebViewBlockKind, source: String, modifier: Modifier = Modifier) {
    val html = remember(kind, source) { buildHtml(kind, source) }
    var contentHeightDp by remember(kind, source) {
        mutableIntStateOf(if (kind == WebViewBlockKind.MERMAID) 220 else 96)
    }
    AndroidView(
        modifier = modifier.fillMaxWidth().height(contentHeightDp.dp),
        factory = { context ->
            val assetLoader = WebViewAssetLoader.Builder()
                .addPathHandler("/assets/", WebViewAssetLoader.AssetsPathHandler(context))
                .build()
            WebView(context).apply {
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = false
                settings.allowFileAccess = false
                settings.allowContentAccess = false
                settings.javaScriptCanOpenWindowsAutomatically = false
                settings.loadWithOverviewMode = true
                settings.useWideViewPort = true
                isVerticalScrollBarEnabled = false
                setBackgroundColor(android.graphics.Color.TRANSPARENT)
                webViewClient = object : WebViewClient() {
                    override fun shouldInterceptRequest(
                        view: WebView?, request: WebResourceRequest?
                    ): WebResourceResponse? = request?.url?.let { assetLoader.shouldInterceptRequest(it) }

                    override fun onPageFinished(view: WebView?, url: String?) {
                        view?.evaluateJavascript(
                            "(function(){return Math.max(document.body.scrollHeight," +
                                "document.documentElement.scrollHeight)})()"
                        ) { result ->
                            val cssHeight = result.trim().trim('"').toFloatOrNull()
                            if (cssHeight != null && cssHeight.isFinite()) {
                                contentHeightDp = (cssHeight.toInt() + 12).coerceIn(64, 480)
                            }
                        }
                    }
                }
            }
        },
        update = { webView ->
            // Recomposition must not reload a diagram or erase an equation.
            if (webView.tag != html) {
                webView.tag = html
                webView.loadDataWithBaseURL(
                    "https://appassets.androidplatform.net/assets/katex/",
                    html,
                    "text/html",
                    "UTF-8",
                    null,
                )
            }
        },
    )
}

private fun buildHtml(kind: WebViewBlockKind, source: String): String = when (kind) {
    WebViewBlockKind.MERMAID -> """
        <!DOCTYPE html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
        <style>body{margin:0;padding:8px;background:transparent;color:#eee;font:13px sans-serif}
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

    WebViewBlockKind.LATEX -> {
        val tex = unwrapClassroomFormula(source)
        val fallback = readableClassroomMath("\\(" + tex + "\\)").htmlEscape()
        katexHtml(
            """<div id="math-0" class="math-display">${fallback}</div>""",
            """[{id:"math-0",tex:${safeJs(tex)},display:true}]""",
        )
    }

    WebViewBlockKind.MATH_TEXT -> {
        val runs = classroomMathRuns(source)
        val html = runs.mapIndexed { index, part ->
            if (part.formula) {
                val fallback = readableClassroomMath("\\(" + part.text + "\\)").htmlEscape()
                val cssClass = if (part.display) "math-display" else "math-inline"
                """<span id="math-${index}" class="${cssClass}">${fallback}</span>"""
            } else {
                "<span>" + part.text.htmlEscape() + "</span>"
            }
        }.joinToString("")
        val equations = runs.mapIndexedNotNull { index, part ->
            if (part.formula) """{id:"math-${index}",tex:${safeJs(part.text)},display:${part.display}}""" else null
        }.joinToString(",")
        katexHtml(html, "[$equations]")
    }
}

/** The fallback is visible without JavaScript, CSS, internet, or any CDN response.
 * Only replace it after KaTeX and its layout stylesheet are available.
 */
private fun katexHtml(fallbackMarkup: String, equations: String): String = """
    <!DOCTYPE html><html><head><meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <link id="katex-css" rel="stylesheet" href="katex.min.css">
    <script src="katex.min.js"></script>
    <style>
      html,body{margin:0;background:transparent;color:#f7f6ff;font:16px/1.55 sans-serif}
      main{padding:6px 4px;white-space:pre-wrap;overflow-wrap:anywhere}
      .math-display{display:block;overflow-x:auto;white-space:nowrap;margin:6px 0}
      .math-inline{display:inline-block;vertical-align:middle;white-space:nowrap;max-width:100%;overflow-x:auto}
      .katex-display{margin:.25em 0;overflow-x:auto;overflow-y:hidden}
    </style></head>
    <body><main id="content">${fallbackMarkup}</main>
    <script>
      window.addEventListener('load',function(){
        var css=document.getElementById('katex-css');
        if(typeof katex==='undefined'||!css||!css.sheet) return;
        var equations=${equations};
        equations.forEach(function(eq){
          var node=document.getElementById(eq.id);
          if(!node) return;
          var replacement=document.createElement('span');
          try{
            katex.render(eq.tex,replacement,{throwOnError:true,displayMode:eq.display,trust:false});
            node.replaceChildren(replacement);
          }catch(err){/* keep readable text; never show an empty equation */}
        });
      });
    </script>
    </body></html>
""".trimIndent()

/** JSONObject.quote escapes slash/quotes/newlines. Escape HTML script end too. */
private fun safeJs(value: String): String =
    JSONObject.quote(value).replace("</", "<\\/")

private fun String.htmlEscape(): String =
    replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
