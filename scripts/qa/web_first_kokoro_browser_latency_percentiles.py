#!/usr/bin/env python3
"""Measure staged Kokoro first-byte and browser playback-start latencies.

20 bounded samples (10 EN, 10 ES), one synthetic JWT learner, paid fallback
strictly disabled. Uses LYO's actual streaming playback helper, Chromium's
media clock and audio events. This cannot establish physical audibility,
end-to-end Classroom first-utterance latency or microphone behavior.
"""
import asyncio
import json
import math
import secrets
import statistics
import sys
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.parse import urlsplit
from playwright.async_api import async_playwright
from web_first_live_classroom_auth import API, http

WEB = "https://lyoonestagingweb-staging.up.railway.app"
SAMPLES_PER_LANGUAGE = 10


def preflight():
    if urlsplit(API).hostname != "lyojourneystagingbackend-staging.up.railway.app":
        raise RuntimeError("Non-staging API refused")
    if urlsplit(WEB).hostname != "lyoonestagingweb-staging.up.railway.app":
        raise RuntimeError("Non-staging Web refused")
    req = Request(API + "/api/v1/tts/health", headers={"Accept": "application/json"})
    with urlopen(req, timeout=25) as res:
        data = json.load(res)
    if data.get("paid_fallback_enabled") is not False:
        raise RuntimeError("Paid TTS fallback must be explicitly disabled")
    if data.get("provider_configured") is not True or data.get("status") != "healthy":
        raise RuntimeError("Local staged TTS is not healthy")
    print("PASS: local staging TTS configured, paid fallback disabled", flush=True)


def nearest_rank(values, fraction):
    ordered = sorted(values)
    index = max(0, math.ceil(fraction * len(ordered)) - 1)
    return ordered[index]


def report(rows, key):
    values = [row[key] for row in rows]
    return dict(
        samples=len(values), p50_ms=nearest_rank(values, .50),
        p95_ms=nearest_rank(values, .95),
        min_ms=min(values), max_ms=max(values),
        arithmetic_mean_ms=round(statistics.mean(values)),
    )


async def run():
    preflight()
    marker = secrets.token_hex(12)
    password = "LYO-VOICE-" + secrets.token_hex(20) + "aA9!"
    user = {
        "email": "lyo-voice-latency-" + marker + "@example.org",
        "username": "voicelatency" + marker[:15],
        "password": password, "confirm_password": password,
        "first_name": "Staging", "last_name": "VoiceQA",
    }
    created = False
    token = None
    browser = None
    success = False
    samples = []
    try:
        for attempt in range(3):
            code, result = http("POST", "/api/v1/auth/register", user)
            if code in (200, 201):
                created = True
                break
            if code != 429 or attempt == 2:
                raise RuntimeError("Synthetic registration refused")
            await asyncio.sleep(65)
        token = result.get("access_token")
        if not token:
            code, auth = http("POST", "/api/v1/auth/login", {
                "email": user["email"], "password": password,
            })
            if code != 200 or not auth.get("access_token"):
                raise RuntimeError("Registered learner has no cleanup token")
            token = auth["access_token"]
        code, profile = http("GET", "/api/v1/auth/me", token=token)
        if code != 200 or not profile.get("id"):
            raise RuntimeError("Synthetic identity not verified")

        source = Path("web/src/lib/classroom-audio.mjs").read_text(encoding="utf-8")
        async with async_playwright() as playwright:
            browser = await playwright.chromium.launch(headless=True, args=[
                "--no-sandbox", "--autoplay-policy=no-user-gesture-required",
            ])
            context = await browser.new_context(viewport={"width": 412, "height": 915},
                                                bypass_csp=True)
            async def safe_route(route):
                request = route.request
                target = urlsplit(request.url)
                if target.hostname in {"lyoai.app", "api.lyoai.app"} or (
                    request.method.upper() not in {"GET", "HEAD", "OPTIONS"}
                    and target.hostname not in {urlsplit(API).hostname,
                                                urlsplit(WEB).hostname}
                ):
                    await route.abort(error_code="blockedbyclient")
                    return
                await route.continue_()
            await context.route("**/*", safe_route)
            page = await context.new_page()
            await page.goto(WEB + "/auth/login", wait_until="domcontentloaded",
                            timeout=35000)
            await page.add_script_tag(
                type="module", content=source +
                "\nwindow.__lyoLatencyPlay = playSpeechResponse;\n"
            )
            await page.wait_for_function(
                "() => typeof window.__lyoLatencyPlay === 'function'", timeout=18000
            )
            for language, line in [
                ("en-US", "Let's practice a fraction together."),
                ("es-US", "Vamos a practicar una fracción juntos."),
            ]:
                for index in range(SAMPLES_PER_LANGUAGE):
                    result = await page.evaluate("""async ({api, token, language, line}) => {
                        const started = performance.now();
                        const response = await fetch(api + '/api/v1/tts/synthesize/stream', {
                            method: 'POST', cache: 'no-store',
                            headers: {'Content-Type':'application/json',
                                      'Authorization':'Bearer '+token},
                            body: JSON.stringify({
                                text:line, language, format:'mp3', speed:0.98
                            })
                        });
                        if (!response.ok) return {error:'HTTP'+response.status};
                        const headersMs = Math.round(performance.now()-started);
                        let firstByteMs = null;
                        const streamCopy = response.clone();
                        const reader = streamCopy.body?.getReader();
                        const firstByteJob = reader ? (async () => {
                            const first = await reader.read();
                            if (!first.done && first.value?.byteLength > 0) {
                                firstByteMs = Math.round(performance.now()-started);
                            }
                            await reader.cancel();
                        })() : Promise.resolve();
                        const audio = new Audio();
                        let startedMs=null, playingMs=null, progressedMs=null;
                        let ended=0, maxCurrent=0, errors=[];
                        audio.addEventListener('playing', () => {
                            if (playingMs === null) playingMs = Math.round(performance.now()-started);
                        });
                        audio.addEventListener('timeupdate', () => {
                            maxCurrent = Math.max(maxCurrent, audio.currentTime);
                            if (progressedMs === null && maxCurrent >= 0.10) {
                                progressedMs = Math.round(performance.now()-started);
                            }
                        });
                        audio.addEventListener('ended', () => ended++);
                        audio.addEventListener('error', () => errors.push('media-decode-error'));
                        try {
                            await window.__lyoLatencyPlay(Promise.resolve(response), {
                                createAudio:()=>audio, startupTimeoutMs:60000,
                                onStarted:()=>{
                                    if (startedMs === null) {
                                        startedMs = Math.round(performance.now()-started);
                                    }
                                },
                            });
                            await firstByteJob;
                        } catch (error) {
                            return {error:error?.name||'playback-failed'};
                        }
                        return {
                            headers_ms:headersMs, first_byte_ms:firstByteMs,
                            player_started_ms:startedMs, playing_event_ms:playingMs,
                            media_progress_ms:progressedMs,
                            total_ms:Math.round(performance.now()-started),
                            ended, maxCurrent, errors,
                            cleaned:audio.paused && !audio.getAttribute('src'),
                        };
                    }""", {"api": API, "token": token, "language": language,
                           "line": line})
                    if result.get("error"):
                        raise RuntimeError("Local TTS browser failed " + language
                                           + " " + str(result["error"])[:24])
                    keys = ("headers_ms", "first_byte_ms", "player_started_ms",
                            "playing_event_ms", "media_progress_ms")
                    if any(not isinstance(result.get(k), int) for k in keys):
                        raise RuntimeError("Missing actual browser timing event")
                    if (result.get("ended") != 1 or result.get("maxCurrent", 0) <= 0.1
                            or result.get("errors") or not result.get("cleaned")):
                        raise RuntimeError("Browser audio did not play and clean properly")
                    row = {"language": language, "sample": index + 1}
                    row.update({k: result[k] for k in keys})
                    row["total_ms"] = result["total_ms"]
                    samples.append(row)
                    print("sample=" + str(index+1) + " language=" + language
                          + " first_byte_ms=" + str(result["first_byte_ms"])
                          + " browser_playing_event_ms=" + str(result["playing_event_ms"])
                          + " progress_100ms_at=" + str(result["media_progress_ms"]),
                          flush=True)
            for language in ("en-US", "es-US"):
                subset = [s for s in samples if s["language"] == language]
                for key in ("first_byte_ms", "player_started_ms",
                            "playing_event_ms", "media_progress_ms"):
                    stats = report(subset, key)
                    print("STAGING_KOKORO_" + language + "_" + key +
                          "=" + json.dumps(stats, sort_keys=True), flush=True)
            success = len(samples) == SAMPLES_PER_LANGUAGE * 2
            print("LIMIT: browser media playback events are NOT human-heard sound or"
                  " end-to-end first voice after Classroom click", flush=True)
    except Exception as exc:
        print("LATENCY FAIL: " + type(exc).__name__ + " (sensitive details suppressed)",
              file=sys.stderr, flush=True)
    finally:
        if browser:
            try:
                await browser.close()
            except Exception:
                pass
        if created:
            code, auth = http("POST", "/api/v1/auth/login", {
                "email": user["email"], "password": password,
            })
            fresh = auth.get("access_token") if code == 200 else token
            if not fresh:
                success = False
                print("CLEANUP FAILED no fresh token", file=sys.stderr)
            else:
                code, deletion = http("DELETE", "/auth/me", token=fresh)
                if code == 200 and deletion.get("deleted") is True:
                    print("PASS: synthetic latency learner permanently deleted",
                          flush=True)
                else:
                    success = False
                    print("CLEANUP FAILED", file=sys.stderr)
    return 0 if success else 1


if __name__ == "__main__":
    raise SystemExit(asyncio.run(run()))
