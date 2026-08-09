package com.lyo.app.ui.classroom.catalog

import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.ln
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.math.tan

/**
 * A small, self-contained recursive-descent evaluator for the expression
 * grammar `director_prompt.py` documents for `board explorable` turns:
 * "x, the named params, + - * / ^ ( ), and sin/cos/tan/exp/log/sqrt/abs".
 * Backs ExplorableBlockRenderer's v2 live plot (see that file) — the only
 * consumer, deliberately kept dependency-free (no parser-combinator/JS
 * -engine library) since the grammar is this small and fixed.
 *
 * Resilience-over-crash, matching the rest of the wire-parsing layer
 * (JsonPointer.resolvePointer, ClassroomServerEvent.parseServerEvent):
 * `evaluateExpression` returns null on ANY parse or evaluation failure
 * (unknown token, unmatched paren, unknown identifier, division by zero,
 * a non-finite result like sqrt of a negative) rather than throwing —
 * ExplorableBlockRenderer skips an unplottable point instead of crashing
 * the whole board on a single malformed LLM-authored expression.
 *
 * Grammar (standard precedence, `^` right-associative, unary minus binds
 * tighter than binary `*`/`/` but LOOSER than `^` — i.e. `-2^2` is
 * `-(2^2) = -4`, matching mathematical convention and most calculators/
 * languages. `signed` sits above `power` for exactly this reason: `power`
 * takes its base from `atom` directly, not from `signed`, so a leading
 * `-` is never "inside" the exponentiation — only `(-2)^2` (an explicit
 * paren) can put it there. `power`'s exponent is `signed` rather than
 * `atom` so a negative exponent like `2^-2` still parses):
 *   expr    := term (('+' | '-') term)*
 *   term    := signed (('*' | '/') signed)*
 *   signed  := '-' signed | '+' signed | power
 *   power   := atom ('^' signed)?          // right-associative
 *   atom    := NUMBER | IDENT | IDENT '(' expr ')' | '(' expr ')'
 */
object ExpressionEvaluator {

    private val FUNCTIONS: Map<String, (Double) -> Double> = mapOf(
        "sin" to ::sin,
        "cos" to ::cos,
        "tan" to ::tan,
        "exp" to ::exp,
        "log" to { x -> ln(x) },
        "sqrt" to ::sqrt,
        "abs" to ::abs,
    )

    /** Evaluates `expression` with `variables` (e.g. `{"x" to 1.5, "a" to 2.0}`)
     *  bound as identifiers. Returns null on any parse/eval failure or a
     *  non-finite result (NaN/Infinity — e.g. `1/0`, `sqrt(-1)`, `log(0)`). */
    fun evaluateExpression(expression: String, variables: Map<String, Double>): Double? {
        val parser = Parser(expression, variables)
        val result = try {
            val value = parser.parseExpr()
            if (!parser.isAtEnd()) return null // trailing garbage after a valid expression
            value
        } catch (e: EvalException) {
            return null
        }
        return result.takeIf { it.isFinite() }
    }

    private class EvalException(message: String) : Exception(message)

    private class Parser(private val source: String, private val variables: Map<String, Double>) {
        private var pos = 0

        fun isAtEnd(): Boolean {
            skipWhitespace()
            return pos >= source.length
        }

        fun parseExpr(): Double {
            var value = parseTerm()
            while (true) {
                skipWhitespace()
                when (peek()) {
                    '+' -> { pos++; value += parseTerm() }
                    '-' -> { pos++; value -= parseTerm() }
                    else -> return value
                }
            }
        }

        private fun parseTerm(): Double {
            var value = parseSigned()
            while (true) {
                skipWhitespace()
                when (peek()) {
                    '*' -> { pos++; value *= parseSigned() }
                    '/' -> {
                        pos++
                        val divisor = parseSigned()
                        if (divisor == 0.0) throw EvalException("division by zero")
                        value /= divisor
                    }
                    else -> return value
                }
            }
        }

        // Deliberately ABOVE power: power's base comes from atom() directly
        // (never from signed()), so a leading '-' can only wrap a whole
        // power expression, not sneak inside one — see the grammar in the
        // class doc comment for why that's what makes -2^2 == -(2^2).
        private fun parseSigned(): Double {
            skipWhitespace()
            if (peek() == '-') {
                pos++
                return -parseSigned()
            }
            if (peek() == '+') {
                pos++
                return parseSigned()
            }
            return parsePower()
        }

        // Right-associative, and the exponent itself allows a leading sign
        // (so `2^-2` parses) via calling parseSigned() rather than atom().
        private fun parsePower(): Double {
            val base = parseAtom()
            skipWhitespace()
            if (peek() == '^') {
                pos++
                val exponent = parseSigned()
                return Math.pow(base, exponent)
            }
            return base
        }

        private fun parseAtom(): Double {
            skipWhitespace()
            val c = peek() ?: throw EvalException("unexpected end of expression")

            if (c == '(') {
                pos++
                val value = parseExpr()
                skipWhitespace()
                if (peek() != ')') throw EvalException("expected ')'")
                pos++
                return value
            }

            if (c.isDigit() || c == '.') {
                return parseNumber()
            }

            if (c.isLetter() || c == '_') {
                val ident = parseIdentifier()
                skipWhitespace()
                if (peek() == '(') {
                    pos++
                    val arg = parseExpr()
                    skipWhitespace()
                    if (peek() != ')') throw EvalException("expected ')' after function argument")
                    pos++
                    val fn = FUNCTIONS[ident] ?: throw EvalException("unknown function '$ident'")
                    return fn(arg)
                }
                return variables[ident] ?: throw EvalException("unknown identifier '$ident'")
            }

            throw EvalException("unexpected character '$c'")
        }

        private fun parseNumber(): Double {
            val start = pos
            while (pos < source.length && (source[pos].isDigit() || source[pos] == '.')) pos++
            val text = source.substring(start, pos)
            return text.toDoubleOrNull() ?: throw EvalException("invalid number '$text'")
        }

        private fun parseIdentifier(): String {
            val start = pos
            while (pos < source.length && (source[pos].isLetterOrDigit() || source[pos] == '_')) pos++
            return source.substring(start, pos)
        }

        private fun peek(): Char? = if (pos < source.length) source[pos] else null

        private fun skipWhitespace() {
            while (pos < source.length && source[pos].isWhitespace()) pos++
        }
    }
}
