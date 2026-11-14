# Android phone sign-off — step by step (no coding needed)

This covers the two release blockers that only a person with a real Android
phone can close:

1. **Live Voice speed** (the p50 / p95 numbers).
2. **Final human check** of the app on a real phone.

Plan about 45 minutes. Use a phone you do not mind installing a test app on:
the test app **replaces** the Play Store LYO app on that phone while installed.

---

## Part A — Install the test app (5 minutes)

1. Use the **QA-patched staging APK built from commit `a7fb722ed02cad429de3ef69c7e922dbb323e372`**:
   [verified Android Actions run 43549058224](https://github.com/Hectorg0827/Lyo_Da_One/actions/runs/43549058224).
   That run passed Android staging compilation and unit tests, Web tests and **4/4 emulator UI checks**.
   Do **not** substitute the older release-candidate APK if you are measuring this specific QA patch.
2. Under **Artifacts**, download
   [lyo-android-STAGING-only-apk, artifact 14095174044](https://github.com/Hectorg0827/Lyo_Da_One/actions/runs/43549058224/artifacts/14095174044).
   GitHub login/repository access may be required. GitHub artifacts expire; if it is no longer available,
   request a new **staging** build from the same reviewed QA commit and verify its hash.
3. Unzip the downloaded artifact. Inside is an `.apk`.
4. Send that `.apk` file to your phone (email it to yourself, Google Drive, or
   a USB cable) and tap it on the phone. Android will ask to allow installing
   from that app — allow it, then **Install**.
5. Open LYO. On the login screen, the small grey text at the bottom must say
   **staging**. If it says *production*, stop and do not continue.
6. Tap **Sign up** and create a brand-new test account (any made-up email such
   as `test+phone1@example.com`). This is a separate test server: your real
   account does not exist there, and nothing you do touches real users.

## Part B — Live Voice speed (15 minutes)

Use normal home Wi-Fi, phone volume at a normal level, in a quiet room.

1. Open the **Lyo** tab and start **Live Voice** (the microphone).
2. Ask 20 short questions, one at a time, waiting for each spoken answer.
   Examples: "What is a fraction?", "Why is the sky blue?", "¿Qué es la
   fotosíntesis?". Mix in 4–5 Spanish questions.
3. After each answer, a small green line appears on the screen:

   `Test build timing · last 1.2 s · pause 1.5 s · p50 1.1 s · p95 1.9 s · 12 of 20 turns`

4. Keep going until it says **20 of 20 turns**. Take a screenshot with the displayed
   p50, p95, speed-only PASS/FAIL and turn count. This is **submit-to-first-audio**,
   not an end-to-end measure of perceived pause; note the separate **pause** field.
   Start a new Live Voice session for each new 20-turn trial: samples reset on exit/re-entry.
   If speech is missing, note each affected turn separately. Never count silence as a successful sample.

**What the numbers mean**

- **p50** — the typical wait before Lyo starts speaking (half of the answers
  were faster than this).
- **p95** — the slow case (only 1 answer in 20 was slower than this).

**Pass:** p50 is **1.1 s or less** and p95 is **2.0 s or less**.
If either is higher, that is a real result too — write it down; it means voice
speed needs more work before release.

If an answer is never spoken out loud, note it. A missing answer is a defect,
not a fast answer.

## Part C — Human check on the phone (25 minutes)

Tick each line. Write a short note for anything that looks or feels wrong.

**Voice behaviour**

- [ ] Interrupt Lyo 5 times while it is speaking (use the available
      interruption control or speak, depending on the build). The old answer never comes back.
- [ ] Interrupt or redirect Lyo 5 times while it is **thinking/streaming**.
      No old response arrives later and no duplicate assistant turn appears.
- [ ] Pause for two seconds in the middle of a sentence. Lyo waits for you.
- [ ] No beeps, no filler speech, no answer repeated twice.
- [ ] Turn on airplane mode during an answer, then turn it off. The app shows
      a clear message and recovers; nothing is duplicated.
- [ ] End voice. The spoken conversation is visible in the normal chat.

**Classroom**

- [ ] Start a lesson (for example "Fractions"). The teacher speaks and the
      board shows the lesson within about 30 seconds.
- [ ] Answer one question correctly and one wrongly on purpose. The teacher's
      response matches what you did.
- [ ] Type a written answer. The keyboard does not cover the answer box or the
      Submit button.
- [ ] Leave the app for a minute and come back. The same lesson continues.
- [ ] Close the lesson and reopen it. It offers to resume where you were.

**Around the app**

- [ ] The bottom bar shows exactly: Focus, Discover, Lyo, Community, +.
- [ ] Nothing is cut off or overlapping on your screen, in portrait.
- [ ] Log out, then log in again with the same test account. Your chat is
      still there. Sign up as a second test account: it sees none of the
      first account's chats.
- [ ] Settings → **Delete account** works for the test account.

## Part D — Record the result

Write these down (a note on your phone is fine) and send them back:

| Item | Your result |
| --- | --- |
| Tested app commit and GitHub artifact | a7fb722e / 14095174044 |
| Phone model and Android version | |
| Wi-Fi or mobile data | |
| p50, submit-to-first-audio (20 audible turns) | |
| p95, submit-to-first-audio (20 audible turns) | |
| End-of-speech pause, if shown | |
| Answers never spoken (count) | |
| Playback interruptions (5) | PASS / FAIL |
| Streaming interruptions (5) | PASS / FAIL |
| Part C lines that failed (if any) | |
| Your physical-device decision | PASS / FAIL |

When finished, uninstall the test app and reinstall LYO from the Play Store
if you want the normal app back on that phone.
