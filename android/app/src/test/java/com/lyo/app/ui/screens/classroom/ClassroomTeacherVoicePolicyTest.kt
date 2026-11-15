package com.lyo.app.ui.screens.classroom

import org.junit.Assert.assertEquals
import org.junit.Test

class ClassroomTeacherVoicePolicyTest {
    @Test
    fun `teacher voice remains stable when a later speech turn changes teacher alias`() {
        val policy = ClassroomTeacherVoicePolicy()
        val initial = policy.resolve("teacher_2", "echo")
        assertEquals(ClassroomVoiceIdentity("teacher_2", "echo"), initial)
        assertEquals(initial, policy.resolve("teacher_1", "onyx"))
        assertEquals(initial, policy.resolve("teacher_4", "shimmer"))
    }

    @Test
    fun `student and companion keep independent voices`() {
        val policy = ClassroomTeacherVoicePolicy()
        policy.resolve("teacher_2", "echo")
        assertEquals(ClassroomVoiceIdentity("student_maya", "alloy"), policy.resolve("student_maya", "alloy"))
        assertEquals(ClassroomVoiceIdentity("lyo", "nova"), policy.resolve("lyo", "nova"))
        assertEquals(ClassroomVoiceIdentity("teacher_2", "echo"), policy.resolve("teacher_3", "fable"))
    }

    @Test
    fun `each classroom player can choose its own teacher`() {
        val first = ClassroomTeacherVoicePolicy()
        val second = ClassroomTeacherVoicePolicy()
        assertEquals("echo", first.resolve("teacher_2", "echo").voice)
        assertEquals("shimmer", second.resolve("teacher_4", "shimmer").voice)
    }
}
