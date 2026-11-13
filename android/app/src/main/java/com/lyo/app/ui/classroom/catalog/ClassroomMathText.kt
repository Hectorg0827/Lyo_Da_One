package com.lyo.app.ui.classroom.catalog

/** Native, accessible text for the arithmetic notation emitted in lesson prose.
 * Only delimited math is converted; currency and ordinary prose are preserved.
 * This is a readable fallback, not a full TeX typesetter.
 */
internal fun readableClassroomMath(text: String): String {
    val math = Regex("""\$\$([\s\S]+?)\$\$|\$([^$\n]+)\$|\\\(([\s\S]+?)\\\)|\\\[([\s\S]+?)\\\]""")
    return math.replace(text) { match ->
        var expression = match.groupValues.drop(1).first { it.isNotEmpty() }
        val fraction = Regex("""\\(?:dfrac|tfrac|frac)\{([^{}]+)\}\{([^{}]+)\}""")
        repeat(8) {
            expression = fraction.replace(expression) { part ->
                fun group(value: String) = if (value.all { it.isLetterOrDigit() || it == '.' }) value else "($value)"
                "${group(part.groupValues[1])}/${group(part.groupValues[2])}"
            }
        }
        for ((command, symbol) in mapOf("times" to "×", "cdot" to "·", "div" to "÷", "leq" to "≤", "geq" to "≥", "neq" to "≠", "pi" to "π")) {
            expression = expression.replace(Regex("""\\$command\b"""), symbol)
        }
        expression = expression.replace(Regex("""\\(?:text|mathrm)\{([^{}]*)\}"""), "$1")
        expression.trim()
    }
}
