package com.lyo.app.ui.classroom

import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import androidx.activity.ComponentActivity
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.lyo.app.ui.classroom.catalog.ClassroomMathRichText
import com.lyo.app.ui.classroom.catalog.WebViewBlock
import com.lyo.app.ui.classroom.catalog.WebViewBlockKind
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** Actually loads KaTeX from APK assets on Android's browser engine. */
@RunWith(AndroidJUnit4::class)
class ClassroomLatexUiTest {
    @get:Rule val compose = createAndroidComposeRule<ComponentActivity>()

    @Test
    fun fractionTypesetsFromBundledAssetsWithoutADataNetwork() {
        compose.setContent {
            WebViewBlock(WebViewBlockKind.LATEX, "\\frac{2}{3}")
        }
        awaitMathHtml("document.querySelector('.katex') !== null")
    }

    @Test
    fun inlineFormulaPreservesTheSurroundingLessonWords() {
        compose.setContent {
            ClassroomMathRichText("A half is " + "$" + "\\frac{1}{2}" + "$" + " of a whole.")
        }
        awaitMathHtml(
            "document.querySelector('.katex') !== null && " +
                "document.body.innerText.includes('A half is') && " +
                "document.body.innerText.includes('of a whole')"
        )
    }

    private fun awaitMathHtml(condition: String) {
        compose.waitForIdle()
        var webView: WebView? = null
        compose.runOnUiThread {
            fun find(view: View): WebView? {
                if (view is WebView) return view
                if (view is ViewGroup) {
                    for (i in 0 until view.childCount) {
                        find(view.getChildAt(i))?.let { return it }
                    }
                }
                return null
            }
            webView = find(compose.activity.window.decorView)
        }
        val web = webView ?: throw AssertionError("Math WebView not mounted")
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(15)
        while (System.nanoTime() < deadline) {
            val answer = AtomicReference<String>("")
            val latch = CountDownLatch(1)
            compose.runOnUiThread {
                web.evaluateJavascript("Boolean($condition)") {
                    answer.set(it)
                    latch.countDown()
                }
            }
            if (latch.await(2, TimeUnit.SECONDS) && answer.get() == "true") return
            Thread.sleep(200)
        }
        fail("Bundled KaTeX did not typeset the actual Android WebView within 15 seconds")
    }
}
