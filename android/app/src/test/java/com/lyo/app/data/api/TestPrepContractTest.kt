package com.lyo.app.data.api

import com.google.gson.Gson
import org.junit.Assert.*
import org.junit.Test

class TestPrepContractTest {
    @Test fun restoresAccountIntakeWithNoPlan() {
        val json = """{"profile":{"id":"tp1","subject":"Biology","test_date":"2026-10-02",
          "topics":[{"name":"Cells","confidence":3,"weight":1}],"daily_minutes_available":30,
          "study_days_per_week":5,"materials":[],"intake_complete":false,
          "intake_transcript":[{"role":"assistant","content":"When is your test?"}]},
          "plan":null,"timezone":"America/New_York","revision":2,"sessions":[]}"""
        val saved = Gson().fromJson(json, PrepSnapshot::class.java)
        assertEquals("When is your test?", saved.profile?.intake_transcript?.last()?.content)
        assertEquals(2, saved.revision)
        assertNull(saved.plan)
    }
    @Test fun ungradedCompletionIsNotZero() {
        val outcome = Gson().fromJson("""{"performance_score":null,"graded":0,"seen":1}""", PrepOutcome::class.java)
        assertNull(outcome.performance_score)
        assertEquals(0, outcome.graded)
    }
}
