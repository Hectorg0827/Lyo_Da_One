# LYO Android Voice Lab (staging-only GPT-Live prototype)

**No production deployment. Do not merge this draft.** Base is the verified
Samsung no-beeps Android branch from PR #189. Its regular voice mode remains
intact and is still the default experience.

The new "Try more human voice · staging" link appears in the Android Live with
Lyo screen **only** when BOTH are true in a debug/staging APK:

- `LYO_STAGING_API_BASE_URL=https://<dedicated-staging-host>`
- `LYO_GPT_LIVE_TRIAL_UI=true`

A release build always hardcodes `GPT_LIVE_TRIAL_UI=false`; a debug APK
without an explicit staging backend also compiles it off. The new Android
activity is `android:exported="false"`.

The Voice Lab uses Android `AudioRecord` and `AudioTrack` at 24kHz mono PCM16,
with hardware acoustic echo cancellation when available. The mic stays on while
Lyo speaks, and incoming learner transcript clears queued Lyo audio for natural
interruption. No `SpeechRecognizer`, Android TTS, restart tone or manual
tap-to-listen controls are used in the new path.

The phone requests a single-use ticket using the signed-in learner's existing
bearer token and connects only to the staging backend. **No OpenAI key is in
the APK**. The server owns the paid upstream WebSocket and its 60-second cutoff.

The staging backend initially answers only three deterministic sample subjects
(fractions, cells, algebra) for conversation-quality testing. Canonical chat
and full lessons are still in the original LYO chat; no synthetic sample is
silently written into chat history.

## Verification before first paid use

1. Keep the backend's `LYO_GPT_LIVE_TRIAL_ENABLED=false`.
2. Check backend budget tests and Android unit/build tests on this draft.
3. Configure separate staging backend/DB/hostname and a dedicated OpenAI
   project/key **without enabling the paid flag**.
4. Verify disabled ticket requests reject; verify production APK has no Voice
   Lab entry; do not accidentally use `https://api.lyoai.app/`.
5. Only after independent review and authorization enable paid trial
   temporarily, test 60-second audio with real Samsung hardware (speaker,
   Bluetooth, interruptions, echo), then check actual provider charges.
6. Kill the flag immediately if latency, echo, cost or session time exceeds
   the staging safety envelope.

See backend `docs/STAGING_GPT_LIVE_TRIAL.md` for the **fixed $10 total
application cap**, the atomic ledger, reservation scheme, and STOP gate.
