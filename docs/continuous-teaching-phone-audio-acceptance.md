# Continuous Teaching — Android physical audio acceptance

This is a device evidence checklist, **not** a claim that audible QA has passed.

## Artifact / environment
1. Obtain the latest `lyo-CONTINUOUS-TEACHING-preview-PHONE-QA-only` staging APK from the workflow `.github/workflows/lyo-continuous-teaching-android-preview-device-qa.yml` on branch `rc/lyo-continuous-teaching-focused-clients-20261119`.
2. Install only on a spare Android phone or work profile. Its package ID may replace the regular app if installed in the same profile.
3. Verify Settings/About reports the exact isolated API host: `lyo-continuousteaching-preview-backend-staging.up.railway.app`. NEVER use real learner data.
4. Record APK commit SHA, device model, Android version, network, and microphone permission state. Do not paste credentials or signed WebSocket URLs into reports.
5. Confirm the isolated preview DB enum repair has run and an authenticated classroom session persists progress before starting the audio test.

## Voice acceptance
- Start **20 independent classes** across short and long subjects. Record first visible teacher text, first audible teacher speech, full authoritative scene arrival, and first-response p50/p95.
- Perform **10 lesson transitions** by explicitly pressing Continue. The temporary teacher should appear immediately and stop when the real scene starts.
- Complete **20 audible turns** with the phone speaker enabled (at least 10 English and 10 Spanish). After each, confirm the *same* established teacher voice, intelligible words, no dead air, and transcript agreement.
- Interrupt narration **five times** using Skip/Next/Interrupt while speaking. Confirm no delayed duplicate speech, abrupt switch to robotic system TTS, or overlapping voices.
- Test mic permission denied then allowed, app background/foreground, headset plug/unplug, slow network, one temporary disconnect, and session reopen.
- Verify ungraded bridge replies never create quiz submissions, mastery events or advancement; actual lesson progress must persist and recover.

## Pass / fail
- **Pass:** zero audible overlap, zero lost or duplicated graded turns, all 20 turns audible, five interruptions recover, EN/ES consistent, authenticated account and session isolation, exact scene resumption.
- **Fail:** persistence or account deletion error, stuck microphone, two voices at once, temporary bridge continuing after real scene, TTS unexpectedly switching engine, missing audio, stale captions, mismatched backend SHA.
- Attach only synthetic-account evidence, redacted timing summary (p50/p95) and high-level logs; no personal data or raw tokens.

**Release rule:** This check is not replaceable by compiler tests, emulator tests, or Railway TTS HTTP 200 responses. Production Web, Android publication and paid-AI activation remain OFF until the real-device evidence is recorded.
