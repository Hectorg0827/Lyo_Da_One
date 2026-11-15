package com.lyo.app.ui.classroom.catalog

/** Native, accessible text for the arithmetic notation emitted in lesson prose.
 * Only delimited math is converted; currency and ordinary prose are preserved.
 * This is a readable fallback, not a full TeX typesetter.
 */
internal fun readableClassroomMath(text: String): String {
    private val mathOperators = linkedMapOf(
        "longrightarrow" to "⟶", "rightarrow" to "→", "leftarrow" to "←",
        "Rightarrow" to "⇒", "Leftarrow" to "⇐", "implies" to "⇒",
        "leftrightarrow" to "↔", "to" to "→",
        "times" to "×", "cdot" to "·", "div" to "÷",
        "leq" to "≤", "geq" to "≥", "neq" to "≠",
        "approx" to "≈", "equiv" to "≡", "pm" to "±",
        "infty" to "∞", "sum" to "∑", "int" to "∫",
        "alpha" to "α", "beta" to "β", "gamma" to "γ",
        "delta" to "δ", "theta" to "θ", "lambda" to "λ",
        "mu" to "μ", "pi" to "π", "sigma" to "σ", "omega" to "ω",
    )

    val math = Regex("""\$\$([\s\S]+?)\$\$|\$([^$\n]+)\$|\\\(([\s\S]+?)\\\)|\\\[([\s\S]+?)\\\]""")
    val rendered = math.replace(text) { match ->
        var expression = match.groupValues.drop(1).first { it.isNotEmpty() }
        val fraction = Regex("""\\(?:dfrac|tfrac|frac)\{([^{}]+)\}\{([^{}]+)\}""")
        repeat(8) {
            expression = fraction.replace(expression) { part ->
                fun group(value: String) = if (value.all { it.isLetterOrDigit() || it == '.' }) value else "($value)"
                "${group(part.groupValues[1])}/${group(part.groupValues[2])}"
            }
        }
        for ((command, symbol) in mathOperators) {
            expression = expression.replace(Regex("""\\$command\b"""), symbol)
        }
        expression = expression.replace(Regex("""\\(?:sqrt)\{([^{}]+)\}"""), "√($1)")
        expression = expression.replace(Regex("""\\(?:text|mathrm|operatorname)\{([^{}]*)\}"""), "$1")
        expression = expression.replace(Regex("""\\(?:left|right)\b"""), "")
        expression.trim()
    }
    // Some model answers use raw arrows outside math delimiters. Convert only
    // a small, named TeX whitelist; never interpret arbitrary TeX or scripts.
    var accessible = rendered
    for ((command, symbol) in mathOperators) {
        accessible = accessible.replace(Regex("""\\$command\b"""), symbol)
    }
    return accessible
}
