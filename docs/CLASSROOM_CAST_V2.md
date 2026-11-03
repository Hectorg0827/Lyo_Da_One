# LYO Classroom 2.0 — Teacher, Companion and Classmates

## Character contract

- **Teacher**: one of `teacher_1` through `teacher_4` selected stably for the topic. The teacher narrates, illustrates, and grades only through the existing server-owned teaching system.
- **Lyo**: the learner's companion (`lyo`), never rendered as the teacher. His separate badge is always visible.
- **AI classmates**: Maya, Sam, Rio and Zack. Their four original illustrations are reused without changing the character art. They are never shown as participants until a real `StudentPrompt` has been received and spoken.

## Implementation and safety

- Web and Android use the same cast ID and topic-to-teacher mapping.
- Voice requests send `speaker_id` and voice preference to the shared backend TTS endpoint. The default Kokoro provider provides nine distinct English cast voices, including Lyo's separate companion voice. For locales without a verified set of voices, the existing native locale voice is retained rather than silently substituting an English voice or enabling paid TTS.
- The backend's optional AI classmate author creates one short, lesson-grounded turn every three eligible scenes, up to four per session. It does not receive learner answers, own grading, or change progression.
- The backend switch `LYO_CLASSROOM_AI_PEERS_ENABLED` defaults to **false**. Enable it only after staging model-cost, latency, and education-quality acceptance; do not enable it in production just because the code has merged.
- No extra LYO Live voice spending, OpenAI TTS fallback, or production deployment is enabled by this change.
- The client uses actual `StudentPrompt` events; the former hard-coded Sam peer state is removed.
- Android's forced landscape/full-screen mode is removed to restore the platform's normal orientation and safe system-bar handling.

## Acceptance before release

1. Confirm the eight character portraits match the existing asset designs on Android and mobile web. The supplied PNGs contain a checkerboard background baked into the image; clean transparent assets would improve presentation without changing the characters.
2. Verify the same subject selects the same teacher on both clients, and Lyo never narrates as the teacher.
3. Confirm nine distinct *audible* English voices against the configured Kokoro instance. Verify Spanish and other locales explicitly before promising unique voices in those languages.
4. Enable classmate generation only on staging with model-usage monitoring. Watch a generated classmate ask a relevant question, speak, appear in transcript, and remain consistent after reconnection. A failed generation must leave the teacher functional.
5. Confirm the four-peer per-session ceiling; do not add phantom classmate seats in solo mode.
6. Test Android classroom launch, rotation, system-button insets, voice interruption, transcript, recovery, and no crash across several lessons.
7. iOS Classroom needs the same character contract after the user resumes iOS work; Apple is deferred for now.

This feature branch is intentionally review-only. Both repositories deploy production from `main`; merge and deployment require separate validation.
