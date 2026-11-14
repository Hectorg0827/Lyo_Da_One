# LYO Live Voice latency acceptance — Web and Android staging

**Status:** QA protocol, not a claim that Live Voice already meets latency targets.

**Scope:** Android device connected to isolated LYO staging backend, a non-production account, English and Spanish prompts. No production writes. iOS is outside this gate.

## Android on-screen timing (no computer needed)

Staging and debug builds show a green line under the Live Voice captions after
every spoken answer, for example
`Test build timing · last 1.2 s · pause 1.5 s · p50 1.1 s · p95 1.9 s · 12 of 20 turns`.
`last`, `p50` and `p95` are submit-to-first-audio; `pause` is end of the
learner's speech to first audio. The production app never shows it. The
step-by-step owner checklist is [ANDROID_DEVICE_SIGNOFF.md](ANDROID_DEVICE_SIGNOFF.md).

## Android local timing (optional, with a computer)

Install the **staging APK from the same GitHub Actions commit being assessed** (staging builds now log these numbers too), then connect Android Debug Bridge (ADB). Check the APK's backend is staging before testing.

```bash
adb logcat -c
adb logcat -v time -s LYO_VOICE_LATENCY:D '*:S'
```

Each first audible response should print only numerical metrics, not transcript or identifiers:

- `asr_end_to_final_ms` — recognition finalization after user finishes speaking
- `asr_final_to_submit_ms` — client handoff to the canonical Chat request
- `submit_to_text_ms` — first streamed text observed by the client
- `submit_to_voice_payload_ms` — first voice segment or `voice_ready`
- `submit_to_audio_ms` — actual TextToSpeech `onStart` after submission
- `end_of_speech_to_audio_ms` — best measure of user-perceived pause
- `p50_audio_ms` / `p95_audio_ms` — rolling first-audio latencies for the latest 20 audible turns
- `audio_turns` — number of audible samples in that rolling window (max 20)

A missing log entry after a complete request is **not** a zero-latency turn; check silent/failed playback and record it as a separate defect. The ASR silence extras are vendor-dependent, so timing must be collected on a real device.

## Minimum acceptance matrix

1. **Twenty valid voice turns** on an actual Android handset: record network type, app SHA and APK artifact ID, device, OS and p50/p95.
2. **Five barge-ins** (interrupt while LYO is speaking), and five interruptions during the thinking/streaming state. Confirm that no previous reply resumes afterward.
3. **English and Spanish** prompts, including natural pauses mid-sentence; do not falsely finish a user turn or switch language incorrectly.
4. **Connectivity:** weak Wi-Fi, switch to cellular, airplane-mode failure, and reconnect; distinguish connection error from a slow response.
5. **Session continuity:** end voice -> regular Chat -> history -> return -> logout -> different account. No lost or leaked conversations.
6. **Audio behavior:** no beep, spoken filler or repeated response; response text and speech follow the same conversation.
7. **Classroom handoff:** generate a course using voice, enter lesson, and verify the teacher/learner interaction stays intact.

Log regressions as reproducible GitHub bugs under #218, with source SHA, app version, device, precise steps, expected/actual behavior and non-sensitive logs. Remove personal text/audio/screenshots containing account information.

## Pass/fail standard

- First record a valid baseline under realistic conditions; do not claim a percentage latency improvement without a comparable before/after run.
- Do not mark the Live Voice gate passed unless first-audio p50 and p95 are reported, the responses are understandable and complete, and interruption/recovery checks pass.
- Independent QA reviews and signs off. Green unit tests alone are **not** live-voice acceptance.
