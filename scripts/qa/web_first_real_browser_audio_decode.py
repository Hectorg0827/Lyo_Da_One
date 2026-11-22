#!/usr/bin/env python3
"""Decode and play a real WAV through LYO's production browser-audio utility.

This is no-provider staging QA. It verifies Chromium actually decodes,
progresses, ends and interrupts media; it cannot prove a physical speaker was
audible, backend TTS availability or end-user output volume.
"""
import asyncio
import base64
import io
import math
import struct
import wave
from pathlib import Path

from playwright.async_api import async_playwright


def local_teacher_fixture(duration_seconds=1.8, frequency=440):
    """Original bounded audible PCM clip, generated locally with no AI calls."""
    sample_rate = 16000
    count = int(duration_seconds * sample_rate)
    with io.BytesIO() as buff:
        with wave.open(buff, "wb") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(sample_rate)
            pcm = bytearray()
            for i in range(count):
                # Fade in/out to avoid sample-edge clicks.
                edge = min(1.0, i / 300, (count - 1 - i) / 300)
                signal = math.sin(2 * math.pi * frequency * i / sample_rate)
                pcm.extend(struct.pack("<h", round(9000 * max(edge, 0) * signal)))
            wav.writeframes(bytes(pcm))
        return base64.b64encode(buff.getvalue()).decode("ascii")


async def main():
    source = Path("web/src/lib/classroom-audio.mjs").read_text(encoding="utf-8")
    # Source has no imports; expose only the actual exported player in this
    # synthetic, isolated browser document.
    source += "\nwindow.__lyoPlaybackSmoke = playSpeechResponse;\n"
    encoded = local_teacher_fixture()
    async with async_playwright() as p:
        browser = await p.chromium.launch(
            headless=True,
            args=["--no-sandbox", "--autoplay-policy=no-user-gesture-required"],
        )
        try:
            page = await browser.new_page(viewport={"width": 410, "height": 820})
            await page.set_content("<!doctype html><html><body><p>LYO isolated audio acceptance</p></body></html>")
            await page.add_script_tag(type="module", content=source)
            await page.wait_for_function(
                "() => typeof window.__lyoPlaybackSmoke === 'function'",
                timeout=10000,
            )
            regular = await page.evaluate("""async (b64) => {
                const bytes = Uint8Array.from(atob(b64), c => c.charCodeAt(0));
                const source = new Response(bytes, {headers: {'Content-Type': 'audio/wav'}});
                const log = {started: 0, downloaded: 0, ended: 0,
                             progressed: false, maxTime: 0, errors: []};
                const audio = new Audio();
                audio.addEventListener('timeupdate', () => {
                    log.maxTime = Math.max(log.maxTime, audio.currentTime);
                    if (audio.currentTime > 0.15) log.progressed = true;
                });
                audio.addEventListener('ended', () => { log.ended++; });
                audio.addEventListener('error', () => { log.errors.push('decode-error'); });
                const start = performance.now();
                await window.__lyoPlaybackSmoke(Promise.resolve(source), {
                  createAudio: () => audio, MediaSourceClass: undefined,
                  startupTimeoutMs: 8000,
                  onStarted: () => {log.started++;},
                  onDownloaded: () => {log.downloaded++;},
                });
                log.elapsedMs = Math.round(performance.now() - start);
                log.cleaned = audio.paused && !audio.getAttribute('src');
                return log;
            }""", encoded)
            assert regular["started"] == 1, regular
            assert regular["downloaded"] == 1, regular
            assert regular["ended"] == 1, regular
            assert regular["progressed"] and regular["maxTime"] > 0.15, regular
            assert regular["cleaned"] and not regular["errors"], regular
            print("PASS: Chromium decoded WAV via actual LYO player and advanced real playback time; "
                  "playback_ms=" + str(regular["elapsedMs"]), flush=True)
            interrupted = await page.evaluate("""async (b64) => {
                const bytes = Uint8Array.from(atob(b64), c => c.charCodeAt(0));
                const sound = new Response(bytes, {headers: {'Content-Type': 'audio/wav'}});
                const ctl = new AbortController();
                const audio = new Audio();
                const log = {started: 0, ended: 0, abortError: false};
                audio.addEventListener('ended', () => { log.ended++; });
                setTimeout(() => ctl.abort(), 220);
                try {
                  await window.__lyoPlaybackSmoke(Promise.resolve(sound), {
                    signal: ctl.signal, createAudio: () => audio,
                    MediaSourceClass: undefined, startupTimeoutMs: 8000,
                    onStarted: () => { log.started++; },
                  });
                } catch (error) {
                  log.abortError = error?.name === 'AbortError';
                }
                log.cleaned = audio.paused && !audio.getAttribute('src');
                return log;
            }""", encoded)
            assert interrupted["abortError"] is True, interrupted
            assert interrupted["ended"] == 0, interrupted
            assert interrupted["cleaned"] is True, interrupted
            print("PASS: Chromium interruption stopped LYO audio before natural completion; "
                  "cleanup confirmed", flush=True)
        finally:
            await browser.close()


if __name__ == "__main__":
    asyncio.run(main())
