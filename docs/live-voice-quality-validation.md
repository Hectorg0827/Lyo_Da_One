# Live conversational voice quality validation

This is a production-behavior gate, not a synthetic unit test. Voice remains a
delivery layer over canonical Chat; the test verifies whether that architecture
actually feels conversational through a real microphone and speaker.

## Initial launch targets

These are product targets for the first live pass. They are intentionally
stricter than "it works" and should be revised from measured distributions, not
from one good demo.

| Signal | Target |
| --- | --- |
| microphone speech start -> first audible Lyo audio | p50 <= 1.8 s; p95 <= 3.0 s |
| submitted turn -> first audible Lyo audio | p50 <= 1.1 s; p95 <= 2.0 s |
| first canonical voice segment -> audible playback | p50 <= 650 ms; p95 <= 1.2 s |
| semantic/RMS barge-in -> Lyo stops | perceptually immediate; no continued sentence after interruption |
| false barge-in from Lyo speaker echo | <= 1 incident per 10 minutes and < 2% of spoken turns |
| complete-utterance endpoint wait | normally 350-750 ms |
| incomplete/thinking endpoint | must not repeatedly cut a learner off; deliberate pause scenario must be reviewed |
| rapid follow-up floor recovery | microphone re-armed without a dead-air turn |
| English <-> Spanish switch | same conversation and learner state; no manual mode reset |
| Classroom/Test Prep handoff | first visible/voice acknowledgement <= 2.0 s where the target workflow permits it |
| dropped stream canonical recovery | <= 2.5 s after connectivity returns; no duplicate user or assistant turn |

## Eight-scenario live run

Run these in one Live Conversation session on a real device, in this order, so
the backend VOICE_QUALITY event sequence can be read as one trace.

1. **Latency baseline.** Ask a simple factual question in one sentence. Repeat
   three times. We care about actual audio playback, not when text first appears.
2. **Barge-in.** Ask for a longer explanation. Once Lyo has spoken for roughly
   1-2 seconds, interrupt with a clearly different question. Lyo should stop
   immediately and the new turn should remain on the same Chat thread.
3. **Rapid exchange.** Do five short turns such as "yes", "why?", "example?",
   "okay", and a short follow-up. There should be no forced pause or lost turn.
4. **Language switch.** Speak English, then Spanish, then English again. Do not
   toggle a language selector. Record whether recognition and speech both remain
   usable.
5. **Thinking pause.** Start an unfinished thought ("I think the reason is..."),
   remain silent for about two seconds, then continue. This specifically tests
   whether endpointing cuts off reflective speech.
6. **Echo/false barge.** Let Lyo speak through the device speaker at normal and
   then fairly loud volume. Stay silent. Lyo must not interrupt itself or create
   a phantom learner turn.
7. **Learning-surface handoffs.** In voice, request "Teach this in Classroom",
   then separately "Use this for Test Prep". Voice should remain the same
   canonical learner/session context through the handoff.
8. **Reconnect.** During a generated/spoken answer, briefly remove network
   connectivity and restore it. The canonical conversation should recover
   without duplicating the turn or silently starting another AI path.

## Event interpretation

The client sends no audio or transcript text. The backend only receives bounded
metadata through `/api/v1/lyo2/voice/quality`.

Key events:

- `mic_speech_started`: real browser speech-onset event.
- `turn_submitted`: endpointing completed and canonical Chat was invoked.
- `first_voice_segment`: canonical Chat produced its first speakable segment.
- `first_audio`: actual server-TTS HTML audio playback or device-TTS playback
  began. This is the latency number that matters perceptually.
- `barge_in` / `barge_in_confirmed`: interruption candidate and speech-confirmed interruption.
- `false_barge_in`: RMS interrupted playback but no non-echo learner speech
  appeared inside the confirmation window.
- `echo_rejected`: playback bleed was recognized and suppressed.
- `recognizer_restarted`: browser speech recognition recycled itself.
- `voice_handoff_requested` / `voice_handoff_ready`: canonical Chat selected
  and reached a learning workflow.
- `stream_disconnected` / `stream_recovered`: dropped SSE and canonical
  conversation recovery.

A run is not considered good because every feature emitted an event. It is good
only when the measured timings and the observed conversational behavior both
meet the targets above.
