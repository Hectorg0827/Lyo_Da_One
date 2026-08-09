package com.lyo.app.ui.classroom.catalog

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.PI
import kotlin.math.sin

private const val DELTA = 1e-9

/**
 * Coverage for ExpressionEvaluator — the recursive-descent parser backing
 * ExplorableBlock's v2 live plot. Precedence/associativity bugs here would
 * silently mis-plot a curve rather than crash or fail loudly, which is
 * exactly the kind of thing worth pinning down with real test cases rather
 * than trusting the implementation by inspection.
 */
class ExpressionEvaluatorTest {

    private fun eval(expr: String, vars: Map<String, Double> = emptyMap()): Double? =
        ExpressionEvaluator.evaluateExpression(expr, vars)

    @Test
    fun `evaluates basic arithmetic`() {
        assertEquals(5.0, eval("2 + 3")!!, DELTA)
        assertEquals(-1.0, eval("2 - 3")!!, DELTA)
        assertEquals(6.0, eval("2 * 3")!!, DELTA)
        assertEquals(2.0, eval("6 / 3")!!, DELTA)
    }

    @Test
    fun `multiplication and division bind tighter than addition and subtraction`() {
        assertEquals(14.0, eval("2 + 3 * 4")!!, DELTA)
        assertEquals(20.0, eval("2 * 3 + 4 * 3.5")!!, DELTA)
    }

    @Test
    fun `exponentiation binds tighter than multiplication and is right-associative`() {
        assertEquals(18.0, eval("2 * 3^2")!!, DELTA) // not (2*3)^2 == 36
        assertEquals(512.0, eval("2^3^2")!!, DELTA) // 2^(3^2) == 2^9, not (2^3)^2 == 64
    }

    @Test
    fun `unary minus binds looser than exponentiation but works standalone`() {
        assertEquals(-4.0, eval("-2^2")!!, DELTA) // -(2^2), matching standard convention
        assertEquals(4.0, eval("(-2)^2")!!, DELTA)
        assertEquals(-5.0, eval("-5")!!, DELTA)
        assertEquals(3.0, eval("-(-3)")!!, DELTA)
    }

    @Test
    fun `parentheses override default precedence`() {
        assertEquals(20.0, eval("(2 + 3) * 4")!!, DELTA)
        assertEquals(1.5, eval("(2 + 4) / (3 + 1)")!!, DELTA)
    }

    @Test
    fun `substitutes x and named params`() {
        assertEquals(7.0, eval("a * x^2 + b * x", mapOf("x" to 1.0, "a" to 3.0, "b" to 4.0))!!, DELTA)
        assertEquals(0.0, eval("x", mapOf("x" to 0.0))!!, DELTA)
    }

    @Test
    fun `functions evaluate correctly`() {
        assertEquals(0.0, eval("sin(0)")!!, DELTA)
        assertEquals(1.0, eval("cos(0)")!!, DELTA)
        assertEquals(sin(PI / 2), eval("sin(3.14159265358979 / 2)")!!, 1e-6)
        assertEquals(1.0, eval("exp(0)")!!, DELTA)
        assertEquals(0.0, eval("log(1)")!!, DELTA)
        assertEquals(3.0, eval("sqrt(9)")!!, DELTA)
        assertEquals(5.0, eval("abs(-5)")!!, DELTA)
    }

    @Test
    fun `functions compose with the surrounding expression`() {
        assertEquals(10.0, eval("2 * sqrt(9) + 4")!!, DELTA)
    }

    @Test
    fun `division by zero returns null instead of Infinity or NaN`() {
        assertNull(eval("1 / 0"))
        assertNull(eval("x / y", mapOf("x" to 1.0, "y" to 0.0)))
    }

    @Test
    fun `a non-finite result from a function returns null`() {
        assertNull(eval("sqrt(-1)")) // NaN
        assertNull(eval("log(0)")) // -Infinity
    }

    @Test
    fun `unknown identifiers and functions return null instead of throwing`() {
        assertNull(eval("unknownVar"))
        assertNull(eval("notAFunction(1)"))
        assertNull(eval("a * x", mapOf("x" to 1.0))) // 'a' not bound
    }

    @Test
    fun `malformed expressions return null instead of throwing`() {
        assertNull(eval(""))
        assertNull(eval("("))
        assertNull(eval("2 +"))
        assertNull(eval("2 + + "))
        assertNull(eval("2 3")) // trailing garbage after a complete expression
        assertNull(eval("()"))
    }

    @Test
    fun `whitespace is insignificant`() {
        assertEquals(eval("2+3*4"), eval("  2 + 3 * 4  "))
    }

    @Test
    fun `a realistic director-authored expression evaluates across a param sweep`() {
        // "a * x^2 + b * x" with a=1, b=0 is a parabola; spot-check a few points.
        val vars = mapOf("a" to 1.0, "b" to 0.0)
        assertEquals(0.0, eval("a * x^2 + b * x", vars + ("x" to 0.0))!!, DELTA)
        assertEquals(1.0, eval("a * x^2 + b * x", vars + ("x" to 1.0))!!, DELTA)
        assertEquals(4.0, eval("a * x^2 + b * x", vars + ("x" to 2.0))!!, DELTA)
        assertEquals(4.0, eval("a * x^2 + b * x", vars + ("x" to -2.0))!!, DELTA)
    }

    @Test
    fun `decimal literals parse correctly`() {
        assertEquals(0.5, eval("1 / 2")!!, DELTA)
        assertEquals(3.14, eval("3.14")!!, DELTA)
        assertEquals(2.5, eval("1.25 * 2")!!, DELTA)
    }

    @Test
    fun `evaluateExpression never throws on adversarial input`() {
        val adversarial = listOf(
            "((((((", "^^^", "1/////0", "sin(", "x^^2",
            "𝔘𝔫𝔦𝔠𝔬𝔡𝔢", "1e10", "--5", "2^", "*3",
        )
        for (expr in adversarial) {
            // The only contract under test: no exception escapes. A null
            // result is an acceptable outcome for every one of these.
            eval(expr)
        }
        assertTrue(true)
    }
}
