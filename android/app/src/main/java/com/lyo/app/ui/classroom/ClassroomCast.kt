package com.lyo.app.ui.classroom

import androidx.annotation.DrawableRes
import com.lyo.app.R
import java.util.Locale

/** One identity on Web, Android and iOS. Lyo is a companion, not a teacher. */
data class ClassroomPerson(
    val id: String,
    val name: String,
    val voice: String,
    @DrawableRes val portrait: Int,
)

object ClassroomCast {
    val teachers = listOf(
        ClassroomPerson("teacher_1", "Teacher 1", "onyx", R.drawable.lyo_teacher_1),
        ClassroomPerson("teacher_2", "Teacher 2", "echo", R.drawable.lyo_teacher_2),
        ClassroomPerson("teacher_3", "Teacher 3", "fable", R.drawable.lyo_teacher_3),
        ClassroomPerson("teacher_4", "Teacher 4", "shimmer", R.drawable.lyo_teacher_4),
    )
    val classmates = listOf(
        ClassroomPerson("student_maya", "Maya", "alloy", R.drawable.student_clever),
        ClassroomPerson("student_sam", "Sam", "nova", R.drawable.student_genius),
        ClassroomPerson("student_rio", "Rio", "fable", R.drawable.student_funny),
        ClassroomPerson("student_zack", "Zack", "echo", R.drawable.student_growth),
    )
    val companion = ClassroomPerson("lyo", "Lyo", "nova", R.drawable.mascot_standing)

    fun teacherFor(topic: String): ClassroomPerson {
        val normalized = topic.lowercase(Locale.ROOT)
        var codepointSum = 0
        var offset = 0
        while (offset < normalized.length) {
            val point = Character.codePointAt(normalized, offset)
            codepointSum += point
            offset += Character.charCount(point)
        }
        return teachers[((codepointSum % teachers.size) + teachers.size) % teachers.size]
    }

    fun speaker(name: String?, topic: String): ClassroomPerson =
        if (name == "Lyo") companion else
            teachers.firstOrNull { it.name == name || it.id == name }
                ?: classmates.firstOrNull { it.name == name || it.id == name }
                ?: teacherFor(topic)
}
