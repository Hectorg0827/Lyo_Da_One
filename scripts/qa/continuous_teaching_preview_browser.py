#!/usr/bin/env python3
"""Synthetic Chromium Web preview: measure first bridge UI, scene and actual
HTMLAudioElement/WebSpeech playback-start signals (not subjective listening).

No production requests, learner PII, signed WebSocket URLs or content is written
to artifacts. This is a dedicated preview, not a release acceptance test.
"""
import asyncio
import json
import secrets
import sys
from pathlib import Path
from urllib.parse import urlsplit

from playwright.async_api import async_playwright
from continuous_teaching_preview_metrics import API, WEB, http

OUTPUT = Path("artifacts/teacher-quality/continuous-teaching-preview-browser.json")
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
INSTRUMENT = """(() => {
  const current = performance.now();
  const metrics = {
    first_bridge_frame_ms: null,
    bridge_dom_ms: null,
    first_scene_frame_ms: null,
    first_audio_playing_ms: null,
    scene_complete_event_ms: null,
    bridge_frames: 0,
    scene_frames: 0,
    audio_error_count: 0,
  };
  const now = () => Math.round(performance.now() - current);
  window.__ctPreviewMetrics = metrics;

  // Observe the actual Classroom frames only, never log their topic/contents
  // and never retain a signed URL or token.
  const Native = window.WebSocket;
  window.WebSocket = class extends Native {
    constructor(url, protocols) {
      super(url, protocols);
      try {
        const u = new URL(url);
        if (u.pathname === '/api/v1/classroom/ws/connect') {
          this.addEventListener('message', event => {
            try {
              const payload = JSON.parse(event.data);
              const nested = payload.data || {};
              const kind = String(nested.event_type || payload.event_type || payload.type || '').toLowerCase();
              if (kind === 'bridge_message' && nested.ungraded === true) {
                metrics.bridge_frames++;
                if (metrics.first_bridge_frame_ms === null) metrics.first_bridge_frame_ms = now();
              }
              if (kind === 'scene_start' || kind === 'scene_stream' || kind === 'scene_update') {
                const scene = nested.scene || payload.scene;
                if (scene && scene.scene_id) {
                  metrics.scene_frames++;
                  if (metrics.first_scene_frame_ms === null) metrics.first_scene_frame_ms = now();
                }
              }
              if (kind === 'scene_complete' && metrics.scene_complete_event_ms === null)
                metrics.scene_complete_event_ms = now();
            } catch {}
          });
        }
      } catch {}
    }
  };
  window.addEventListener('classroom:spoken-segment', () => {
    if (metrics.first_audio_playing_ms === null)
      metrics.first_audio_playing_ms = now();
  });
  window.addEventListener('classroom:voice-error', () => { metrics.audio_error_count++; });
  const watchDom = () => {
    if (metrics.bridge_dom_ms !== null) return;
    const el = document.querySelector('section[aria-label="Live teacher conversation before the next lesson step"]');
    if (el) metrics.bridge_dom_ms = now();
  };
  const watcher = new MutationObserver(watchDom);
  watcher.observe(document, {childList: true, subtree: true});
  document.addEventListener('DOMContentLoaded', watchDom, {once: true});
})();"""


async def measure():
    nonce = secrets.token_hex(12)
    password = "LyoQa-" + secrets.token_hex(18) + "A9!"
    learner = {
        "email": "lyo-ct-browser-" + nonce + "@example.org",
        "username": "ctbr" + nonce[:20],
        "password": password, "confirm_password": password,
        "first_name": "Preview", "last_name": "QA",
    }
    result = {
        "preview_only": True,
        "metric_origin": "Chromium WebSocket DOM + classroom:spoken-segment on real playback start",
        "audible_quality_human_verified": False,
        "synthetic_account_deleted": False,
    }
    token = None
    created = False
    success = False
    try:
        status, response = http("POST", "/api/v1/auth/register", learner)
        if status not in (200, 201):
            raise RuntimeError("browser preview registration failed")
        created = True
        token = response.get("access_token")
        if not token:
            status, response = http("POST", "/api/v1/auth/login", {
                "email": learner["email"], "password": password
            })
            if status != 200:
                raise RuntimeError("browser preview login failed")
            token = response.get("access_token")
        if not token:
            raise RuntimeError("browser preview login returned no token")

        async with async_playwright() as playwright:
            browser = await playwright.chromium.launch(headless=True, args=[
                "--no-sandbox", "--autoplay-policy=no-user-gesture-required",
                "--use-fake-ui-for-media-stream",
            ])
            try:
                context = await browser.new_context(
                    viewport={"width": 412, "height": 915},
                    storage_state={"cookies": [], "origins": [{
                        "origin": WEB,
                        "localStorage": [{"name": "lyo_token", "value": token}],
                    }]},
                )
                async def guard(route):
                    request = route.request
                    parsed = urlsplit(request.url)
                    host = parsed.hostname or ""
                    allowed = {urlsplit(API).hostname, urlsplit(WEB).hostname}
                    has_token = "authorization" in {key.lower() for key in request.headers}
                    unsafe = (host not in allowed and (request.method.upper() not in ("GET","HEAD") or has_token))
                    if host in {"api.lyoai.app", "lyoai.app"} or unsafe:
                        await route.abort(error_code="blockedbyclient")
                    else:
                        await route.continue_()
                await context.route("**/*", guard)
                await context.add_init_script(INSTRUMENT)
                page = await context.new_page()
                await page.goto(WEB+"/classroom?topic=Fractions&duration=3&language=en-US",
                                wait_until="domcontentloaded", timeout=30000)
                await page.get_by_role("button", name="Leave classroom").wait_for(timeout=30000)
                deadline = asyncio.get_running_loop().time() + 115
                while asyncio.get_running_loop().time() < deadline:
                    data = await page.evaluate("() => window.__ctPreviewMetrics || null")
                    if data and data["first_scene_frame_ms"] is not None and data["first_audio_playing_ms"] is not None:
                        break
                    await asyncio.sleep(1)
                result["browser"] = await page.evaluate("() => window.__ctPreviewMetrics || null")
                result["ui_live"] = await page.get_by_role("button", name="Leave classroom").is_visible()
                # Capture only a synthetic classroom, with no real credentials/PII.
                await page.screenshot(path="artifacts/teacher-quality/continuous-teaching-preview.png")
                success = bool(result["browser"] and result["browser"].get("first_bridge_frame_ms") is not None
                               and result["browser"].get("first_scene_frame_ms") is not None)
            finally:
                await browser.close()
    except Exception as exc:
        result["error_type"] = type(exc).__name__
        print("Chromium preview QA incomplete: " + result["error_type"], file=sys.stderr)
    finally:
        if created and token:
            try:
                status, body = http("DELETE", "/auth/me", token=token)
                result["synthetic_account_deleted"] = status == 200 and body.get("deleted") is True
            except Exception:
                pass
        if not result["synthetic_account_deleted"]:
            success = False
        OUTPUT.write_text(json.dumps(result, indent=2, sort_keys=True))
        print("Chromium preview metrics: " + json.dumps(result, sort_keys=True), flush=True)
    return 0 if success else 1


if __name__ == "__main__":
    raise SystemExit(asyncio.run(measure()))
