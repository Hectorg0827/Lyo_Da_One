#!/usr/bin/env python3
"""Actual local-build Web CI: authenticated staging Classroom -> WebSocket -> resume.

Uses one synthetic QA learner and deletes it via DELETE /auth/me. No production
hosts, real credentials, bearer tokens or user content in logs/artifacts.
"""
import asyncio
import json
import os
import secrets
import sys
import time
from pathlib import Path
from urllib.parse import parse_qs, quote, urlsplit
from playwright.async_api import async_playwright
from web_first_live_classroom_auth import http, API

WEB = os.environ.get("LYO_WEB_BASE_URL", "http://127.0.0.1:3000").rstrip("/")
assert urlsplit(WEB).hostname in {"127.0.0.1", "localhost"} or (urlsplit(WEB).hostname or "").endswith("-staging.up.railway.app")
ARTIFACTS = Path("artifacts/web-first-browser-qa")
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
    expected_id = None
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
        code, profile = http("GET", "/api/v1/auth/me", token=token)
        if code != 200 or not profile.get("id"):
            raise RuntimeError("Synthetic learner identity verification failed")
        expected_id = str(profile["id"])
        print("PASS: isolated registration and verified synthetic learner", flush=True)

        async with async_playwright() as playwright:
            browser = await playwright.chromium.launch(headless=True, args=["--no-sandbox"])
            context = await browser.new_context(viewport={"width": 412, "height": 915},
                                                device_scale_factor=1)
            blocked_nonstaging = []
            allowed_hosts = {urlsplit(WEB).hostname, urlsplit(API).hostname}

            async def refuse_nonstaging_requests(route):
                request = route.request
                host = urlsplit(request.url).hostname or ""
                method = request.method.upper()
                # Never send a disposable learner's credentials to production
                # or any unrelated host if the staging Web bundle is misconfigured.
                unsafe = host in {"api.lyoai.app", "lyoai.app"} or (
                    method in {"POST", "PUT", "PATCH", "DELETE"} and host not in allowed_hosts
                )
                if unsafe:
                    blocked_nonstaging.append((method, host))
                    await route.abort(error_code="blockedbyclient")
                    return
                await route.continue_()

            await context.route("**/*", refuse_nonstaging_requests)
            page = await context.new_page()
            # Capture browser-side failures without logging credentials, headers or URLs.
            js_error_kinds = []
            page.on("pageerror", lambda error: js_error_kinds.append(
                (type(error).__name__, str(error).splitlines()[0][:140])))
            # Exercise the same visible form and /auth/login route as learners.
            # Seeding localStorage bypassed the Zustand login store and could
            # produce a false negative for Classroom auth hydration.
            stage = "visible Web sign-in"
            auth_statuses = []
            def record_auth(response):
                pathname = urlsplit(response.url).path
                if pathname in ("/auth/login", "/auth/me"):
                    auth_statuses.append((pathname, response.status))
            page.on("response", record_auth)
            await page.goto(WEB + "/auth/login", wait_until="domcontentloaded", timeout=25000)
            # Wait for React auth initialization, not merely server HTML:
            # Next 15 can hydrate after DOMContentLoaded; filling a controlled
            # form before hydration loses its values and produces a false login.
            await page.get_by_role("button", name="Log In", exact=True).wait_for(
                state="visible", timeout=30000)
            await page.get_by_label("Email", exact=True).fill(person["email"])
            await page.get_by_label("Password", exact=True).fill(password)
            await page.get_by_role("button", name="Log In", exact=True).click()
            try:
                await page.wait_for_function(
                    "() => Boolean(window.localStorage.getItem('lyo_token'))",
                    timeout=35000)
            except Exception:
                if blocked_nonstaging:
                    raise RuntimeError("Staging-only request guard blocked " + str(blocked_nonstaging))
                try:
                    await page.screenshot(path=str(ARTIFACTS / "login_failure.png"),
                                          full_page=True)
                except Exception:
                    pass
                raise RuntimeError("Visible login did not save a session; auth HTTP statuses="
                                   + str(auth_statuses)
                                   + "; browser_errors=" + str(js_error_kinds[:3]))
            browser_token = await page.evaluate(
                "() => window.localStorage.getItem('lyo_token')")
            code, web_profile = http("GET", "/auth/me", token=browser_token)
            if code != 200 or str(web_profile.get("id")) != expected_id:
                raise RuntimeError("Visible login token failed /auth/me identity verification; "
                                   "HTTP " + str(code))
            print("PASS: visible Web sign-in and /auth/me matched synthetic learner", flush=True)

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
            # Web-first launch gate: the learner's actual AI-course entry
            # must create a completed course proposal, not just load Classroom
            # using a hard-coded URL. This uses only one synthetic learner.
            stage = "AI course generation (algebra/intermediate)"
            stream_statuses = []
            def record_course_stream(response):
                if urlsplit(response.url).path == "/api/v1/lyo2/chat/stream":
                    stream_statuses.append(response.status)
            page.on("response", record_course_stream)
            prompt = "Create an intermediate course on algebra"
            await page.goto(WEB + "/chat?prompt=" + quote(prompt),
                            wait_until="domcontentloaded", timeout=25000)
            ready = page.get_by_role("button", name="Start course", exact=True)
            try:
                await ready.wait_for(state="visible", timeout=125000)
            except Exception:
                raise RuntimeError(
                    "No ready algebra course from actual chat. "
                    + "Chat stream HTTP statuses=" + str(stream_statuses)
                )
            if blocked_nonstaging:
                raise RuntimeError("Course flow attempted a non-staging request: "
                                   + str(blocked_nonstaging))
            # A ready button alone was a false positive: a failed backend
            # response once rendered a Beginner placeholder as ready for an
            # explicitly Intermediate algebra course, with zero lessons.
            # Persist a synthetic-only screenshot *before* strict assertions
            # so unexpected text/case differences are diagnosable.
            await page.screenshot(path=str(ARTIFACTS / "course_ready.png"), full_page=True)
            outline = page.get_by_text("Course outline", exact=True)
            lesson_count = page.get_by_text("4 lessons", exact=True)
            # The DOM stores lowercase "intermediate"; CSS capitalize affects
            # appearance, not Playwright's case-sensitive exact text matching.
            level = page.get_by_text("intermediate", exact=True)
            print("COURSE QA evidence: outline=" + str(await outline.count())
                  + ", four_lessons=" + str(await lesson_count.count())
                  + ", level_badge=" + str(await level.count()), flush=True)
            await outline.wait_for(state="visible", timeout=10000)
            await lesson_count.first.wait_for(state="visible", timeout=10000)
            await level.first.wait_for(state="visible", timeout=10000)
            if await page.get_by_text(
                "I'm having trouble responding right now. Please try again.",
                exact=False).count():
                raise RuntimeError("AI fallback appeared alongside a ready course")
            print("PASS: actual algebra course generated through Web chat", flush=True)
            await ready.click()
            await page.wait_for_url("**/classroom?*", timeout=20000)
            print("PASS: generated course navigated to its Classroom", flush=True)
            # Confirm the course entry survives beyond this browser's local state.
            stage = "saved algebra course lookup"
            saved = False
            for _ in range(25):
                stack_code, stack_data = http(
                    "GET", "/api/v1/stack/items?item_type=course&limit=100",
                    token=browser_token)
                if stack_code == 200 and isinstance(stack_data.get("items"), list):
                    saved = any(
                        "algebra" in str(item.get("title", "")).lower()
                        and item.get("content_id")
                        for item in stack_data["items"]
                    )
                    if saved:
                        break
                await asyncio.sleep(1)
            if not saved:
                raise RuntimeError("Course was not found in the learner's saved Stack")
            print("PASS: algebra course found in server-backed learner Stack", flush=True)
            # Verify a separate browser profile can see the saved course.
            # No localStorage or cookies are shared with the first profile.
            stage = "saved course on second browser profile"
            second_context = await browser.new_context(
                viewport={"width": 1365, "height": 900})
            await second_context.route("**/*", refuse_nonstaging_requests)
            second_page = await second_context.new_page()
            await second_page.goto(WEB + "/auth/login",
                                   wait_until="domcontentloaded", timeout=25000)
            await second_page.get_by_role("button", name="Log In", exact=True).wait_for(
                state="visible", timeout=30000)
            await second_page.get_by_label("Email", exact=True).fill(person["email"])
            await second_page.get_by_label("Password", exact=True).fill(password)
            await second_page.get_by_role("button", name="Log In", exact=True).click()
            await second_page.wait_for_function(
                "() => Boolean(localStorage.getItem('lyo_token'))", timeout=35000)
            await second_page.goto(WEB + "/", wait_until="domcontentloaded", timeout=25000)
            await second_page.get_by_text("Your courses", exact=True).wait_for(
                state="visible", timeout=35000)
            await second_page.get_by_text("algebra", exact=False).first.wait_for(
                state="visible", timeout=35000)
            print("PASS: saved algebra course visible in second browser profile", flush=True)
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
                if code == 401 and expected_id:
                    # Refresh only the disposable learner's expired credentials.
                    login_code, fresh = http("POST", "/api/v1/auth/login",
                                             {"email": person["email"], "password": password})
                    if login_code != 200 or not fresh.get("access_token"):
                        raise RuntimeError("Synthetic cleanup reauthentication failed")
                    fresh_token = fresh["access_token"]
                    identity_code, identity = http(
                        "GET", "/api/v1/auth/me", token=fresh_token)
                    if identity_code != 200 or str(identity.get("id")) != expected_id:
                        raise RuntimeError("Synthetic cleanup identity mismatch")
                    code, result = http("DELETE", "/auth/me", token=fresh_token)
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
