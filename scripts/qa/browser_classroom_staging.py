#!/usr/bin/env python3
"""Actual Chromium staging UI smoke: login -> Classroom -> WebSocket -> resume.

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
            stage = "Web login navigation"
            await page.goto(WEB + "/auth/login", wait_until="domcontentloaded", timeout=25000)
            stage = "Web email input"
            await page.get_by_label("Email").fill(person["email"])
            stage = "Web password input"
            await page.get_by_label("Password", exact=True).fill(password)
            stage = "Web login submit"
            await page.get_by_role("button", name="Log In", exact=True).click()
            stage = "Web login redirect"
            await page.wait_for_url(
                lambda u: "/auth/login" not in urlsplit(str(u)).path,
                timeout=30000)
            print("PASS: Chromium signed in through visible Web login form", flush=True)

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
                }
                sockets.append(info)
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

            stage = "Classroom initial scene"
            await page.goto(WEB + "/classroom?topic=Fractions&duration=3&language=en-US",
                            wait_until="domcontentloaded", timeout=25000)
            await page.get_by_role("button", name="Leave classroom").wait_for(timeout=25000)
            if not await until(lambda: any(item["scenes"] for item in sockets), 90):
                raise RuntimeError("No Classroom scene received in browser")
            first = next(item for item in sockets if item["scenes"])
            if first["resume"]:
                raise RuntimeError("Fresh Web lesson incorrectly requested resume")
            initial_scene = first["scenes"][0]
            if not first["session"]:
                raise RuntimeError("Web Classroom did not send session identity")
            await page.screenshot(path=str(ARTIFACTS / "classroom_initial.png"), full_page=True)
            print("PASS: live Classroom scene reached Chromium UI", flush=True)

            stage = "Classroom forced disconnect and resumed scene"
            await context.set_offline(True)
            await asyncio.sleep(2)
            await context.set_offline(False)
            if not await until(lambda: len(sockets) >= 2, 25):
                raise RuntimeError("Classroom did not reconnect after network recovery")
            resumed = sockets[-1]
            if resumed["session"] != first["session"] or resumed["resume"] != "1":
                raise RuntimeError("Classroom Web reconnect omitted same session or resume=1")
            if not await until(lambda: bool(resumed["scenes"]), 55):
                raise RuntimeError("No server scene returned to reconnected Web UI")
            if initial_scene not in resumed["scenes"]:
                raise RuntimeError("Reconnected Web UI received wrong persisted scene")
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
