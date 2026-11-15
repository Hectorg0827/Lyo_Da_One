# Android Classroom streaming teacher voice — isolated staging pilot

## Safety and scope
Branch: `exp/android-classroom-streaming-tts-staging-20261115`, based on the accepted Classroom staging QA branch. Not intended for production or Play Store distribution.

Enable only when BOTH build parameters are supplied:

```sh
-PLYO_STAGING_API_BASE_URL=https://lyojourneystagingbackend-staging.up.railway.app
-PLYO_STAGING_CLASSROOM_TTS_STREAMING_PILOT=true
```

Otherwise Classroom continues using the existing authenticated full-MP3 path. The production build always writes `CLASSROOM_TTS_STREAMING_PILOT=false`. This experiment requires no backend endpoint addition; it uses the existing authenticated `POST /api/v1/tts/synthesize/stream`.

The streaming pilot puts lesson text in the HTTP **POST body**, never the URL or logs. Bearer authentication goes in an HTTP header; no credentials are stored in source or a log.

## Evidence from live staging, Nov 15

In a recent Railway proxy sample, 28 full-MP3 requests ended as HTTP 499; most clustered around 8 seconds, matching Android's old call timeout. At least one successful uncached Kokoro synthesis took approximately 9.5 seconds. The Android QA branch now uses a 15-second cutoff in staging and retains the old 8 seconds in production. This is a reliability fix, *not* a proven reduction in response time.

The streaming pilot is intended to test whether a progressive ExoPlayer POST source begins audible playback faster, without a full-MP3 wait.

## Gates before any merge or deployment

1. CI must compile with streaming explicitly enabled and pass unit tests; confirm staging API URL and generated `CLASSROOM_TTS_STREAMING_PILOT=true`.
2. The instrumented Android DataSpec test verifies POST body vs URL. **This does not establish that a user can hear a stream.**
3. Install only on a dedicated Android test profile or device. The staging build shares the Play Store application ID, so it can replace the installed app.
4. Sign in to a test account connected to the **staging** backend. Run science, fractions, and a free-topic class in English and Spanish; record at least 20 teacher turns with 3 skips, 3 pauses, a reconnect, and a forced stream failure.
5. Verify exactly one teacher voice identity, no mid-sentence repetition after a stream error, and separate student/companion voices. Check that all transcripts and grade records remain backend-owned.
6. Capture only fixed event names and elapsed milliseconds in `adb logcat -s LyoClassroomVoiceQA:I`. Relevant events: `stream_audio_play_started`, `stream_failed_before_audio_full_retry`, `stream_interrupted_captions_only`, `shared_audio_play_started`, `device_fallback_after_stream_error`. Never upload raw learner transcripts or auth tokens.
7. Compare full-MP3 staging and streamed pilot separately for p50/p95 time to audible first word, abandoned turns, request errors, mid-turn stalls, and synthetic voice fallback. No speed claim without comparable device measurements.
8. Verify user-visible captions and controls during slow/failed provider responses. Use TalkBack, different screen sizes, and a controlled offline/online transition.

**Decision:** An Android CI success means compile and request-shape confidence only. Production release needs device voice quality, privacy, correctness and stable performance evidence. Do not enable this pilot globally based on compilation or instrumentation alone.
