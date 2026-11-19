package com.lyo.app.data.classroom

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ClassroomContinuousTeachingEventTest {
    @Test fun bridgeMessageIsParsedAsUngradedAsideNotSceneStart() {
        val wire = """
            {"event_type":"bridge_message","session_id":"session-1","data":{
              "generation":2,"phase":"transition","text":"What else do you notice?",
              "prompt":true,"ungraded":true,"ai_generated":false
            }}
        """.trimIndent()
        val message = parseServerEvent(wire)
        assertTrue(message is ClassroomServerEvent.BridgeMessageEvent)
        val aside = message as ClassroomServerEvent.BridgeMessageEvent
        assertEquals(2, aside.generation)
        assertEquals("transition", aside.phase)
        assertEquals("What else do you notice?", aside.text)
        assertTrue(aside.prompt)
        assertFalse(aside.aiGenerated)
    }

    @Test fun fakeGradedBridgeOrInvalidGenerationIsRejected() {
        assertNull(parseServerEvent(
            """{"event_type":"bridge_message","data":{"generation":1,"phase":"startup","text":"Hello","prompt":true,"ungraded":false}}"""
        ))
        assertNull(parseServerEvent(
            """{"event_type":"bridge_message","data":{"generation":0,"phase":"startup","text":"Hello","prompt":true,"ungraded":true}}"""
        ))
    }

    @Test fun unknownBridgeReplyCannotMasqueradeAsServerLessonEvent() {
        assertNull(parseServerEvent(
            """{"event_type":"bridge_reply","data":{"generation":1,"text":"A guess"}}"""
        ))
    }
}
