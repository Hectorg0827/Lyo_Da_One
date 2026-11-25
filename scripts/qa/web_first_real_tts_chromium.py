#!/usr/bin/env python3
"""One real staging TTS -> Chromium decode/playback bilingual acceptance.

No AI text model is invoked. This script refuses to call TTS if the server's
paid fallback is enabled, to avoid usage outside the approved AI trial ledger.
A disposable authenticated learner is removed in finally, even on failure.
It does NOT establish physical-speaker audibility.
"""
import asyncio
import json
import secrets
import sys
import time
from pathlib import Path
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

from playwright.async_api import async_playwright
import web_first_live_classroom_auth as qa


WEB = "https://lyoonestagingweb-staging.up.railway.app"
API = qa.API
assert (urlsplit(WEB).hostname or "").endswith("-staging.up.railway.app")
assert (urlsplit(API).hostname or "").endswith("-staging.up.railway.app")


def refuse_paid_tts_fallback():
    req = Request(API + "/api/v1/tts/health",
                  headers={"Accept": "application/json"})
    with urlopen(req, timeout=25) as response:
        if response.status != 200:
            raise RuntimeError("Staging TTS health unavailable")
        data = json.load(response)
    if data.get("paid_fallback_enabled") is not False:
        raise RuntimeError("Refusing potential paid TTS fallback")
    if data.get("provider_configured") is not True:
        raise RuntimeError("Staging TTS local provider not configured")
    if data.get("status") != "healthy":
        raise RuntimeError("Staging TTS service is not healthy")
    print("PASS: healthy staging TTS with paid fallback disabled", flush=True)


async def run():
    refuse_paid_tts_fallback()
    marker = secrets.token_hex(11)
    password = "LyoQA-" + secrets.token_hex(17) + "aA9!"
    person = {
        "email": "lyo-tts-bilingual-" + marker + "@example.org",
        "username": "ttsqa" + marker[:18],
        "password": password, "confirm_password": password,
        "first_name": "Staging", "last_name": "Voice",
    }
    created = False
    token = None
    browser = None
    passed = False
    try:
        for attempt in range(3):
            status, registered = qa.http("POST", "/api/v1/auth/register", person)
            if status in (200, 201):
                created = True
                break
            if status != 429 or attempt == 2:
                raise RuntimeError("Staging synthetic registration HTTP " + str(status))
            await asyncio.sleep(65)
        token = registered.get("access_token")
        if not token:
            status, login = qa.http("POST", "/api/v1/auth/login",
                                    {"email": person["email"], "password": password})
            if status != 200 or not login.get("access_token"):
                raise RuntimeError("Staging synthetic learner login rejected")
            token = login["access_token"]
        status, identity = qa.http("GET", "/api/v1/auth/me", token=token)
        if status != 200 or not identity.get("id"):
            raise RuntimeError("Synthetic learner identity rejected")
        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True, args=[
                "--no-sandbox", "--autoplay-policy=no-user-gesture-required",
            ])
            context = await browser.new_context(
                viewport={"width": 412, "height": 915}, bypass_csp=True)
            # Real Web staging origin, never production. The browser should
            # expose CORS/auth errors exactly as a real Web learner experiences.
            async def only_staging(route):
                target = urlsplit(route.request.url)
                if (route.request.method.upper() != "GET"
                    and target.hostname not in {urlsplit(WEB).hostname,
                                                urlsplit(API).hostname}):
                    await route.abort(error_code="blockedbyclient")
                    return
                await route.continue_()
            await context.route("**/*", only_staging)
            page = await context.new_page()
            await page.goto(WEB + "/auth/login", wait_until="domcontentloaded",
                            timeout=35000)
            source = Path("web/src/lib/classroom-audio.mjs").read_text()
            await page.add_script_tag(
                type="module",
                content=source + "\nwindow.__lyoQaPlayTTS = playSpeechResponse;\n")
            await page.wait_for_function(
                "() => typeof window.__lyoQaPlayTTS === 'function'",
                timeout=20000)
            for language, phrase in [
                ("en-US", "Let's solve the equation step by step."),
                ("es-US", "Vamos a resolver la ecuación paso a paso."),
            ]:
                result = await page.evaluate("""async ({api, token, language, phrase}) => {
                    const startedAt = performance.now();
                    const response = await fetch(api + '/api/v1/tts/synthesize/stream', {
                        method: 'POST',
                        headers: {'Content-Type': 'application/json',
                                  'Authorization': 'Bearer ' + token},
                        body: JSON.stringify({
                            text: phrase, language, format: 'mp3', speed: 0.98,
                        }),
                        cache: 'no-store',
                    });
                    if (!response.ok) return {error:'tts-http-' + response.status};
                    const audio = new Audio();
                    let played=0, downloaded=0, ended=0, progressed=false;
                    let maxCurrent=0, firstAudibleMs=null;
                    audio.addEventListener('timeupdate', () => {
                        maxCurrent = Math.max(maxCurrent, audio.currentTime);
                        if (maxCurrent >= 0.12) progressed=true;
                    });
                    audio.addEventListener('ended', () => { ended++; });
                    try {
                        await window.__lyoQaPlayTTS(Promise.resolve(response), {
                            createAudio: () => audio, startupTimeoutMs: 60000,
                            onStarted: () => {
                                played++;
                                firstAudibleMs = Math.round(performance.now()-startedAt);
                            },
                            onDownloaded: () => {downloaded++;},
                        });
                    } catch (error) {
                        return {error: error?.name || 'media-failure',
                                started: played > 0};
                    }
                    return {
                        played, downloaded, ended, progressed,
                        maxCurrent: Math.round(maxCurrent * 100)/100,
                        firstAudibleMs,
                        totalMs: Math.round(performance.now()-startedAt),
                        cleaned: audio.paused && !audio.getAttribute('src'),
                    };
                }""", {"api": API, "token": token,
                       "language": language, "phrase": phrase})
                if result.get("error"):
                    raise RuntimeError(language + " staging TTS/browser "
                                       + result["error"])
                if not (result.get("played") == 1
                        and result.get("downloaded") == 1
                        and result.get("ended") == 1
                        and result.get("progressed") is True
                        and result.get("cleaned") is True):
                    raise RuntimeError(language + " browser audio contract failed")
                print("PASS: " + language + " live staging TTS streamed to real Chromium: "
                      + "first_playback_ms=" + str(result["firstAudibleMs"])
                      + " total_ms=" + str(result["totalMs"]),
                      flush=True)
            # One additional actual staging TTS response is buffered once and
            # replayed five times with independent AbortControllers. This
            # exercises real decoded MP3 cancellation without five upstream
            # synthesis requests or model-provider spending.
            interruptions = await page.evaluate("""async ({api, token}) => {
                const response = await fetch(api + '/api/v1/tts/synthesize/stream', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json',
                              'Authorization': 'Bearer ' + token},
                    body: JSON.stringify({
                        text: 'We are solving the algebra problem. Let us begin with the variable.',
                        language: 'en-US', format: 'mp3', speed: 0.98,
                    }),
                    cache: 'no-store',
                });
                if (!response.ok) return {error: 'tts-http-' + response.status};
                const samples = new Uint8Array(await response.arrayBuffer());
                if (samples.length < 4096) return {error: 'incomplete-audio'};
                const mime = response.headers.get('Content-Type') || 'audio/mpeg';
                const verdicts = [];
                for (let i = 0; i < 5; i++) {
                    const controller = new AbortController();
                    const audio = new Audio();
                    let started=0, ended=0, abortCaught=false, maxTime=0;
                    audio.addEventListener('timeupdate', () => {
                        maxTime = Math.max(maxTime, audio.currentTime);
                    });
                    audio.addEventListener('ended', () => { ended++; });
                    const clip = new Response(samples.slice(), {
                        status: 200, headers: {'Content-Type': mime}
                    });
                    try {
                        await window.__lyoQaPlayTTS(Promise.resolve(clip), {
                            signal: controller.signal, createAudio: () => audio,
                            startupTimeoutMs: 9000,
                            onStarted: () => {
                                started++;
                                setTimeout(() => controller.abort(), 240);
                            },
                        });
                    } catch (error) {
                        abortCaught = error?.name === 'AbortError';
                    }
                    await new Promise(resolve => setTimeout(resolve, 45));
                    verdicts.push({
                        started, ended, abortCaught,
                        cleaned: audio.paused && !audio.getAttribute('src'),
                    });
                }
                return {verdicts, bytes: samples.length};
            }""", {"api": API, "token": token})
            if interruptions.get("error"):
                raise RuntimeError("Live-audio interruption setup "
                                   + interruptions["error"])
            verdicts = interruptions.get("verdicts") or []
            if len(verdicts) != 5 or any(
                v.get("started") != 1 or v.get("ended") != 0
                or v.get("abortCaught") is not True
                or v.get("cleaned") is not True for v in verdicts
            ):
                raise RuntimeError("Five real decoded-voice interruptions failed")
            print("PASS: five back-to-back real-Kokoro-MP3 browser interruptions; "
                  "all stopped before ended, all cleaned, "
                  "one buffered TTS response reused", flush=True)
        passed = True
    except Exception as exc:
        # Never log bearer tokens, URLs with credentials, or synthetic PII.
        print("TTS CHROMIUM FAIL: " + type(exc).__name__ + ": "
              + str(exc).split("wss://")[0][:115], file=sys.stderr, flush=True)
    finally:
        if browser is not None:
            try:
                await browser.close()
            except Exception:
                pass
        if created:
            if not token:
                passed = False
                print("FAIL: synthetic voice learner cleanup token unavailable",
                      file=sys.stderr)
            else:
                for attempt in range(3):
                    status, deleted = qa.http("DELETE", "/auth/me", token=token)
                    if status == 200 and deleted.get("deleted") is True:
                        print("PASS: synthetic voice learner deleted", flush=True)
                        break
                    if status != 429 or attempt == 2:
                        passed = False
                        print("FAIL: synthetic voice learner cleanup", file=sys.stderr)
                        break
                    await asyncio.sleep(65)
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(asyncio.run(run()))
