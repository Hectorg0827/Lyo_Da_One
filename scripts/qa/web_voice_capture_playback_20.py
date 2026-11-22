#!/usr/bin/env python3
"""Synthetic Chromium voice media regression: 20 cycles, 5 interrupts.

Uses the production LYO browser playback and barge-in helpers with a fake
microphone and locally generated WAV. No text/voice AI, remote API, credentials
or production systems. This does NOT certify physical microphone/speaker use,
speech recognition, teacher responses, or real acoustic barge-in.
"""
import asyncio
import base64
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import io
import math
from pathlib import Path
import struct
from threading import Thread
import wave

from playwright.async_api import async_playwright

ROOT = Path(__file__).resolve().parents[2]


def original_wav():
    rate, count = 16000, 6400
    with io.BytesIO() as buffer:
        with wave.open(buffer, "wb") as out:
            out.setnchannels(1)
            out.setsampwidth(2)
            out.setframerate(rate)
            samples = bytearray()
            for i in range(count):
                fade = max(0, min(1, i / 200, (count - i - 1) / 200))
                samples.extend(struct.pack(
                    "<h", round(7000 * fade * math.sin(2 * math.pi * 440 * i / rate))
                ))
            out.writeframes(samples)
        return base64.b64encode(buffer.getvalue()).decode("ascii")


class LocalPage(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/":
            self.send_error(404)
            return
        data = b"<!doctype html><title>LYO isolated media QA</title>"
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *args):
        pass


async def main():
    playback = (ROOT / "web/src/lib/voice-playback.mjs").read_text()
    guard = (ROOT / "web/src/lib/voice-barge-in.mjs").read_text()
    server = ThreadingHTTPServer(("127.0.0.1", 0), LocalPage)
    thread = Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        async with async_playwright() as playwright:
            browser = await playwright.chromium.launch(headless=True, args=[
                "--no-sandbox", "--autoplay-policy=no-user-gesture-required",
                "--use-fake-device-for-media-stream", "--use-fake-ui-for-media-stream",
            ])
            try:
                context = await browser.new_context(permissions=["microphone"])
                page = await context.new_page()
                await page.goto("http://127.0.0.1:" + str(server.server_port) + "/")
                await page.add_script_tag(
                    type="module", content=playback + "\nwindow.__qaPlay = playVoiceBlob;"
                )
                await page.add_script_tag(
                    type="module", content=guard + "\nwindow.__qaBarge = shouldEndTurnOnSpeech;"
                )
                await page.wait_for_function(
                    "() => typeof window.__qaPlay === 'function'"
                    " && typeof window.__qaBarge === 'function'"
                )
                result = await page.evaluate("""async b64 => {
                    const pcm = Uint8Array.from(atob(b64), c => c.charCodeAt(0));
                    const mic = await navigator.mediaDevices.getUserMedia({
                      audio: {echoCancellation: true, noiseSuppression: true}
                    });
                    const track = mic.getAudioTracks()[0];
                    if (!track || track.readyState !== 'live')
                      throw Error('Browser microphone did not become live');
                    const stats = {turns: 0, started: 0, complete: 0, cancelled: 0,
                      overlapped: 0, uncleaned: 0, guardFailures: 0, micReleased: false};
                    let active = null;
                    try {
                      for (let n = 1; n <= 20; n++) {
                        const shouldInterrupt = [3,7,11,15,19].includes(n);
                        const ctl = new AbortController();
                        let started = false, cleaned = false, outcome;
                        try {
                          await window.__qaPlay(new Blob([pcm], {type:'audio/wav'}), {
                            signal: ctl.signal,
                            onAudio: audio => {
                              if (audio) {
                                if (active) stats.overlapped++;
                                active = audio;
                              } else {
                                active = null;
                                cleaned = true;
                              }
                            },
                            onStart: () => {
                              started = true; stats.started++;
                              if (shouldInterrupt) setTimeout(() => ctl.abort(), 90);
                            },
                          });
                          outcome = 'complete';
                        } catch(e) {
                          if (e?.name !== 'AbortError') throw e;
                          outcome = 'cancelled';
                        }
                        if (!started || !cleaned || active) stats.uncleaned++;
                        if (shouldInterrupt) {
                          if (outcome !== 'cancelled') throw Error('Abort did not cancel');
                          stats.cancelled++;
                        } else {
                          if (outcome !== 'complete') throw Error('Unexpected abort');
                          stats.complete++;
                        }
                        const decisions = [
                          window.__qaBarge({monitorState:'ready', loudEnough:true, isEcho:false}),
                          window.__qaBarge({monitorState:'ready', loudEnough:true, isEcho:true}),
                          window.__qaBarge({monitorState:'ready', loudEnough:false, isEcho:false}),
                          window.__qaBarge({monitorState:'pending', loudEnough:true, isEcho:false}),
                          window.__qaBarge({monitorState:'unavailable', loudEnough:true, isEcho:false}),
                        ];
                        if (JSON.stringify(decisions) !== '[true,false,false,false,false]')
                          stats.guardFailures++;
                        stats.turns++;
                      }
                    } finally {
                      mic.getTracks().forEach(t => t.stop());
                      stats.micReleased = mic.getTracks().every(t => t.readyState === 'ended');
                    }
                    return stats;
                }""", original_wav())
                expected = dict(
                    turns=20, started=20, complete=15, cancelled=5,
                    overlapped=0, uncleaned=0, guardFailures=0, micReleased=True,
                )
                assert result == expected, result
                print("PASS 20 Chromium media cycles, 5 real browser playback aborts, "
                      "browser fake microphone live/released, no audio overlap", flush=True)
                print("NOT physical device acceptance or 20 real spoken AI exchanges", flush=True)
            finally:
                await browser.close()
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)


if __name__ == "__main__":
    asyncio.run(main())
