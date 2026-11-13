#!/usr/bin/env python3
"""Actual Chromium staging UI smoke: authenticated Classroom -> WebSocket -> resume.

Uses one synthetic QA learner and deletes it via DELETE /auth/me. No production
hosts, real credentials, bearer tokens or user content in logs/artifacts.
"""
import asyncio
import json
import secrets
import sys
import time
from pathlib import Path
from urllib.parse import parse_qs, urlsplit
from playwright.async_api import async_playwright
from live_classroom_auth import http

WEB = "https://lyoonestagingweb-staging.up.railway.app"
assert urlsplit(WEB).hostname.endswith("-staging.up.railway.app")
ARTIFACTS = Path("artifacts/browser-classroom-staging")
ARTIFACTS.mkdir(parents=True, exist_ok=True)

async def until(predicate, seconds):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        if predicate(): return True
        await asyncio.sleep(0.5)
    return False

async def run():
    marker = secrets.token_hex(12)
    password = "LyoQA-" + secrets.token_hex(18) + "aA9!"
    person = {
        "email": "lyo-qa-" + marker + "@example.org",
        "username": "qa" + marker[:22],
        "password": password,
        "confirm_password": password,
        "first_name": "Staging", "last_name": "QA",
    }
    token = None
    created = False
    success = False
    browser = None
    stage = "registration"
    try:
        code, response = http("POST", "/api/v1/auth/register", person)
        if code not in (200, 201): raise RuntimeError("registration")
        created = True
        token = response.get("access_token")
        if not token:
            code, login = http("POST", "/api/v1/auth/login",
                               {"email": person["email"], "password": password})
            if code != 200 or not login.get("access_token"): raise RuntimeError("cleanup token")
            token = login["access_token"]
        print("PASS: isolated test registration and cleanup token", flush=True)

        async with async_playwright() as playwright:
            browser = await playwright.chromium.launch(headless=True, args=["--no-sandbox"])
            context = await browser.new_context(viewport={"width": 412, "height": 915},
                                                device_scale_factor=1)
            page = await context.new_page()
            # The visible login form has already passed once in run
            # #43508877955. Use the verified synthetic API token directly for
            # subsequent reconnect runs to avoid auth rate-limit interference.
            stage = "Web auth hydration"
            await page.goto(WEB + "/auth/login", wait_until="domcontentloaded", timeout=25000)
            await page.evaluate("(token) => localStorage.setItem('lyo_token', token)", token)
            print("PASS: staging browser hydrated with disposable authenticated token", flush=True)

            # Install before the next navigation: expose a QA-only handle to
            # forcibly terminate one live WebSocket if Chromium's offline
            # emulation does not actually close an already-open socket.
            await context.add_init_script("""(() => {
              const Native = window.WebSocket;
              window.__lyoQaSockets = [];
              window.WebSocket = class extends Native {
                constructor(url, protocols) {
                  super(url, protocols);
                  this.__qaSceneIds = [];
                  this.addEventListener('message', ev => {
                    try {
                      const event = JSON.parse(ev.data);
                      const scene = event.data?.scene ?? event.scene;
                      if (scene?.scene_id) this.__qaSceneIds.push(String(scene.scene_id));
                    } catch {}
                  });
                  window.__lyoQaSockets.push(this);
                }
              };
            })();""")
            sockets = []
            def on_socket(ws):
                u = urlsplit(ws.url)
                if u.path != "/api/v1/classroom/ws/connect":
                    return
                qs = parse_qs(u.query)
                info = {
                    "session": qs.get("session_id", [""])[0],
                    "resume": qs.get("resume", [""])[0],
                    "scenes": [],
                    "closed": False,
                }
                sockets.append(info)
                def on_close():
                    info["closed"] = True
                ws.on("close", on_close)
                def on_frame(frame):
                    try:
                        event = json.loads(frame if isinstance(frame, str) else frame.decode())
                        if not isinstance(event, dict): return
                        nested = event.get("data") or {}
                        if not isinstance(nested, dict): nested = {}
                        scene = nested.get("scene") or event.get("scene") or {}
                        if isinstance(scene, dict) and scene.get("scene_id"):
                            info["scenes"].append(str(scene["scene_id"]))
                    except Exception:
                        pass
                ws.on("framereceived", on_frame)
            page.on("websocket", on_socket)
            # Record only structural, non-secret diagnostics. No socket URLs,
            # request bodies, tokens, scene text or browser content in logs.
            page_errors = []
            api_responses = []
            observed_socket_paths = []
            page.on("pageerror", lambda _: page_errors.append("pageerror"))
            page.on("websocket", lambda sock: observed_socket_paths.append(
                urlsplit(sock.url).path[:100]))
            def on_api_response(response):
                parsed = urlsplit(response.url)
                if parsed.path in ("/auth/me", "/api/v1/auth/me") or parsed.path.startswith("/api/v1/classroom"):
                    host_kind = "staging" if (parsed.hostname or "").endswith("-staging.up.railway.app") else "non-staging"
                    api_responses.append([host_kind, parsed.path[:80], response.status])
            page.on("response", on_api_response)

            summary_js = """() => (window.__lyoQaSockets || []).map(s => {
              const u = new URL(s.url);
              return {
                path: u.pathname,
                session: u.searchParams.get('session_id'),
                resume: u.searchParams.get('resume'),
                state: s.readyState,
                scenes: s.__qaSceneIds || [],
              };
            })"""
            stage = "Classroom initial scene"
            await page.goto(WEB + "/classroom?topic=Fractions&duration=3&language=en-US",
                            wait_until="domcontentloaded", timeout=25000)
            await page.get_by_role("button", name="Leave classroom").wait_for(timeout=25000)
            # Prefer what actual in-page WebSockets received. The external
            # Playwright event observer can miss frames, especially after
            # Next.js hydration and WebSocket replacement.

            first = None
            deadline = time.monotonic() + 95
            while time.monotonic() < deadline:
                entries = await page.evaluate(summary_js)
                matches = [entry for entry in entries
                           if entry["path"] == "/api/v1/classroom/ws/connect"
                           and entry["scenes"]]
                if matches:
                    first = matches[0]
                    break
                await asyncio.sleep(0.5)
            if first is None:
                entries = await page.evaluate(summary_js)
                state_summary = [(entry["state"], len(entry["scenes"])) for entry in entries]
                status_signals = await page.evaluate("""() => {
                  const body = document.body.innerText || '';
                  return ['Connecting…', 'Sign in to start a secure AI classroom.',
                    'Sign in again to resume this lesson.', 'Not connected to the classroom.',
                    'The class session ended.', 'Retry to rejoin.', '● Live']
                    .filter(x => body.includes(x));
                }""")
                print("BROWSER QA safe diagnostics: native_ws=" + str(len(entries))
                      + " observed_ws_paths=" + str(observed_socket_paths[:12])
                      + " api_responses=" + str(api_responses[-12:])
                      + " page_errors=" + str(len(page_errors))
                      + " status_signals=" + str(status_signals), flush=True)
                try:
                    await page.screenshot(path=str(ARTIFACTS / "classroom_failed_initial.png"), full_page=True)
                except Exception:
                    pass
                raise RuntimeError("No Classroom scene in actual browser sockets; states=" + str(state_summary))
            if first["resume"]:
                raise RuntimeError("Fresh Web lesson incorrectly requested resume")
            initial_scene = first["scenes"][0]
            if not first["session"]:
                raise RuntimeError("Web Classroom did not send session identity")
            await page.screenshot(path=str(ARTIFACTS / "classroom_initial.png"), full_page=True)
            print("PASS: live Classroom scene reached Chromium UI", flush=True)

            stage = "Classroom forced disconnect and resumed scene"
            # Browser offline emulation left an existing socket half-open in
            # CI. Instead, deterministically close an otherwise healthy socket
            # to exercise the same onclose/reconnect path without a TCP hang.
            await page.evaluate("""() => {
              const sockets = window.__lyoQaSockets || [];
              const active = [...sockets].reverse().find(s =>
                new URL(s.url).pathname === '/api/v1/classroom/ws/connect'
                && s.readyState === WebSocket.OPEN);
              if (!active) throw new Error('No open Classroom WebSocket to interrupt');
              active.close(4000, 'QA simulated transport interruption');
            }""")

            # Read sanitized contract fields and scene IDs from the
            # native browser WebSocket objects, never the signed URLs.
            resumed = None
            deadline = time.monotonic() + 55
            while time.monotonic() < deadline:
                entries = await page.evaluate(summary_js)
                matches = [item for item in entries
                           if item["path"] == "/api/v1/classroom/ws/connect"
                           and item["session"] == first["session"]
                           and item["resume"] == "1"]
                if matches:
                    resumed = matches[-1]
                    if initial_scene in resumed["scenes"]:
                        break
                await asyncio.sleep(0.5)
            if not resumed:
                entries = await page.evaluate(summary_js)
                states = [item["state"] for item in entries]
                raise RuntimeError("Browser did not open same-session resume=1 socket; states=" + str(states))
            if initial_scene not in resumed["scenes"]:
                raise RuntimeError("Browser resumed socket did not receive the persisted scene")
            if not await page.get_by_role("button", name="Leave classroom").is_visible():
                raise RuntimeError("Classroom UI was lost after reconnection")
            await page.screenshot(path=str(ARTIFACTS / "classroom_resumed.png"), full_page=True)
            print("PASS: real Chromium Web UI rejoined identical server scene with resume=1", flush=True)
            success = True
    except Exception as exc:
        # The first exception line may contain the public page URL; redact
        # everything that could be a test credential or signed socket URL.
        first_line = str(exc).splitlines()[0][:240]
        first_line = first_line.replace(person["email"], "[synthetic-email]")
        first_line = first_line.replace(password, "[secret]")
        if token:
            first_line = first_line.replace(token, "[token]")
        if "wss://" in first_line:
            first_line = first_line.split("wss://")[0] + "[signed-socket]"
        print("BROWSER QA FAIL at stage: " + stage + " [" + type(exc).__name__ +
              "] " + first_line, file=sys.stderr)
    finally:
        if browser is not None:
            try: await browser.close()
            except Exception: pass
        if created and token:
            try:
                code, result = http("DELETE", "/auth/me", token=token)
                if code == 200 and result.get("deleted") is True:
                    print("BROWSER QA cleanup: synthetic learner deleted")
                else:
                    print("BROWSER QA cleanup failed, HTTP " + str(code), file=sys.stderr)
                    success = False
            except Exception:
                print("BROWSER QA cleanup exception", file=sys.stderr)
                success = False
        elif created:
            print("BROWSER QA cleanup blocked: created without token", file=sys.stderr)
            success = False
    return 0 if success else 1

if __name__ == "__main__":
    raise SystemExit(asyncio.run(run()))
