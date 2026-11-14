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


/** A lesson paragraph split into ordinary prose and delimited TeX. */
internal data class ClassroomMathRun(val text: String, val formula: Boolean, val display: Boolean = false)

/**
 * Keep prose and currency intact. A separate formula span is rendered by
 * KaTeX when available, with accessible offline text always present.
 */
internal fun classroomMathRuns(text: String): List<ClassroomMathRun> {
    val delimiters = Regex("""\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\]|\\\(([\s\S]+?)\\\)|\$([^$\n]+?)\$""")
    val runs = mutableListOf<ClassroomMathRun>()
    var offset = 0
    for (match in delimiters.findAll(text)) {
        if (match.range.first > offset) {
            runs += ClassroomMathRun(text.substring(offset, match.range.first), false)
        }
        val groups = match.groupValues
        val expression = groups.drop(1).firstOrNull { it.isNotBlank() }?.trim()
        if (expression.isNullOrEmpty()) {
            runs += ClassroomMathRun(match.value, false)
        } else {
            runs += ClassroomMathRun(expression, true, groups[1].isNotBlank() || groups[2].isNotBlank())
        }
        offset = match.range.last + 1
    }
    if (offset < text.length) runs += ClassroomMathRun(text.substring(offset), false)
    if (runs.isEmpty()) runs += ClassroomMathRun(text, false)
    return runs
}

internal fun hasClassroomMath(text: String): Boolean =
    classroomMathRuns(text).any { it.formula }

internal fun unwrapClassroomFormula(text: String): String {
    val trimmed = text.trim()
    val runs = classroomMathRuns(trimmed)
    return if (runs.size == 1 && runs[0].formula) runs[0].text else trimmed
}
