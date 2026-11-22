#!/usr/bin/env python3
"""Bounded staging-only *real* TTS audio probe, not a human listening test.

One disposable learner, two short (English / Spanish) speech requests, then
decode the returned provider audio to check non-silence and duration. Never
print tokens, learner secrets, audio content or signed URLs.
"""
import asyncio
from array import array
import json
import math
import secrets
import subprocess
import time
from urllib.error import HTTPError
from urllib.request import Request, urlopen

import web_first_live_classroom_auth as qa


def decode_audio(raw):
    result = subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", "pipe:0",
         "-f", "s16le", "-ac", "1", "-ar", "16000", "pipe:1"],
        input=raw, capture_output=True, timeout=25, check=False,
    )
    if result.returncode:
        raise RuntimeError("TTS stream did not decode to valid audio")
    pcm = array("h")
    pcm.frombytes(result.stdout[:len(result.stdout) & ~1])
    if not pcm:
        raise RuntimeError("TTS returned no decoded speech")
    duration = len(pcm) / 16000
    rms = math.sqrt(sum(float(sample) ** 2 for sample in pcm) / len(pcm))
    if duration < 0.35 or rms < 90:
        raise RuntimeError("TTS returned empty/near-silent audio")
    return round(duration, 2), round(rms, 1)


async def main():
    marker = secrets.token_hex(11)
    password = "LyoQA-" + secrets.token_hex(18) + "aA9!"
    person = {
        "email": "lyo-tts-qa-" + marker + "@example.org",
        "username": "ttsqa" + marker[:20],
        "password": password, "confirm_password": password,
        "first_name": "Staging", "last_name": "QA",
    }
    created, token, ok = False, None, False
    try:
        for attempt in range(3):
            code, registered = qa.http("POST", "/api/v1/auth/register", person)
            if code in (200, 201):
                break
            if code != 429 or attempt == 2:
                raise RuntimeError("TTS QA registration rejected HTTP " + str(code))
            print("Staging auth throttle; waiting 65s", flush=True)
            await asyncio.sleep(65)
        created = True
        token = registered.get("access_token")
        if not token:
            code, login = qa.http("POST", "/api/v1/auth/login",
                {"email": person["email"], "password": password})
            if code != 200 or not login.get("access_token"):
                raise RuntimeError("TTS QA sign-in rejected")
            token = login["access_token"]
        checks = [
            ("en-US", "Let's solve an algebra equation, one step at a time."),
            ("es-US", "Vamos a resolver una ecuación de álgebra, paso a paso."),
        ]
        for locale, phrase in checks:
            request = Request(
                qa.API + "/api/v1/tts/synthesize/stream",
                data=json.dumps({"text": phrase, "language": locale, "format": "mp3"}).encode(),
                headers={"Authorization": "Bearer " + token,
                         "Content-Type": "application/json",
                         "Accept": "audio/mpeg"},
                method="POST",
            )
            started = time.monotonic()
            try:
                with urlopen(request, timeout=65) as response:
                    if response.status != 200:
                        raise RuntimeError("TTS non-200 HTTP response")
                    first_audio_ms = round((time.monotonic() - started) * 1000)
                    raw = response.read(4 * 1024 * 1024 + 1)
            except HTTPError as exc:
                raise RuntimeError("TTS HTTP " + str(exc.code)) from None
            if not raw or len(raw) > 4 * 1024 * 1024:
                raise RuntimeError("TTS audio absent or exceeded safety cap")
            duration, rms = decode_audio(raw)
            print(f"PASS: {locale} decoded real audio; bytes={len(raw)}; "
                  f"seconds={duration}; rms={rms}; first_audio_ms={first_audio_ms}",
                  flush=True)
        ok = True
    finally:
        if created:
            if not token:
                print("FAIL: synthetic TTS learner cleanup token unavailable", flush=True)
                ok = False
            else:
                for attempt in range(3):
                    code, response = qa.http("DELETE", "/auth/me", token=token)
                    if code == 200 and response.get("deleted") is True:
                        print("PASS: disposable TTS learner deleted", flush=True)
                        break
                    if code != 429 or attempt == 2:
                        ok = False
                        print("FAIL: TTS learner cleanup requires staging reconciliation",
                              flush=True)
                        break
                    await asyncio.sleep(65)
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
