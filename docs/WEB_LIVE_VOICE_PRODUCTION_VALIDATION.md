# Web Live Voice — Android parity and production acceptance

This is a release gate for `lyoai.app`, not proof of completion from source
inspection alone. The Web client remains a voice delivery layer over canonical
Chat. Do not enable a separate voice AI transport, paid GPT-Live service, or
production API configuration as part of this UI release.

## Automated release checks

1. `node scripts/verify-chat-voice-contract.mjs` — one Web microphone owner,
   canonical voice metadata, segment playback and interruption safeguards.
2. In `web/`, `npm test`, `npx tsc --noEmit`, and `npx next build` — including
   `chat-input-voice-parity.test.mjs` and `voice-session.test.mjs`.
3. Merge only with green CI. Railway's `LyoWeb` service in the `Lyo` environment
   of the `caring-cat` project builds `web/` from `main` automatically.
4. Wait for `https://lyoai.app/api/health` to report the exact release SHA
   (the `deploy-check` CI job enforces this). Check the backend health endpoint
   at `https://api.lyoai.app/health` independently.
5. Review Railway deployment status and errors on the actual production Web
   and backend services, not the older Vercel or unrelated Railway projects.

## Real-device acceptance (required before calling the experience validated)

Use a dedicated, signed-in test account with no customer data. Do not send
external emails or trigger third-party actions. Repeat the voice quality
scenarios in [live-voice-quality-validation.md](live-voice-quality-validation.md)
on Android Chrome and desktop Chrome. Spot-check mobile Safari or Edge where
supported, using the browser's actual microphone and speaker.

| Check | Pass condition |
| --- | --- |
| Composer parity | Attachment `+`, live mic, text input and send sit on one row; mic height is no greater than the input |
| Start and stop | Mic starts the session with browser permission; its Stop state and the status-strip End control both cleanly end it |
| Listening | Live transcript updates, silence doesn't orphan the session, and complete turns are automatically sent |
| Answer | First audible reply and spoken text match one canonical assistant message |
| Interruption | Spoken interruption when genuinely supported; Android Chrome and fallback browsers offer a working tap Interrupt path |
| Echo | Ten minutes through device speaker without Lyo falsely interrupting itself |
| Mixed input | Attachments and typed turns remain in the same chat thread when switching out of Live Voice |
| Chat history | End Live Voice, refresh, reopen the conversation, then verify both sides of voice exchange remain |
| Resume | Short exchanges, English/Spanish switching, and a temporary network drop recover without duplicate turns |
| Layout | No Android navigation overlap or horizontal clipping at 320, 360, 390 and 768 CSS-pixel widths |

Compare timing and turn-taking to the targets in the voice-quality document;
record measured p50/p95 latency, first-audio time, false barge-ins, device,
browser, and release commit. No automated unit test can validate real acoustic
echo, microphone permission behavior, natural TTS prosody, or perceived latency.

## Block and rollback rules

- **Block release completion** if the production SHA is stale, login fails,
  audio cannot be heard, a turn is duplicated/lost, or the browser traps the mic.
- **Block parity sign-off** if the on-device composer or status strip clips,
  the microphone is taller than the input, or attachments no longer work.
- **Rollback** the Web service to the last known-good Railway deployment if
  the new release causes a live voice regression. Do not roll back the backend
  or unrelated services to undo a Web-only UI change.
- Report `code verified`, `deployed`, and `real-device validated` separately;
  none of these statuses implies the next one.
