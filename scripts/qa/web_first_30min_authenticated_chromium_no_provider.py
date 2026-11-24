#!/usr/bin/env python3
"""30-minute AUTHENTICATED Web Classroom browser endurance with a fixed synthetic tutor.

The UI is the actually deployed Railway staging Web and genuine learner login.
Only Classroom WebSocket teaching events are synthetic (NO paid AI / grading).
This is **not** 30 minutes of genuinely graded AI teaching or audible voice.
It tests responsive UI continuity, transcript controls, reconnect/reload and
synthetic-account cleanup, not complete pedagogical acceptance.
"""
import ast
import asyncio
import json
import os
import secrets
import sys
import time
from pathlib import Path
from urllib.parse import urlsplit
from urllib.request import urlopen

from playwright.async_api import async_playwright
from web_first_live_classroom_auth import API, http

WEB = "https://lyoonestagingweb-staging.up.railway.app"
EXPECTED = os.environ["EXPECTED_WEB_SHA"]
DURATION = 1800
STEP = 20


def fixture():
    source = Path(__file__).with_name("web_first_bridge_visual_fixture.py").read_text(
        encoding="utf-8"
    )
    for node in ast.parse(source).body:
        if isinstance(node, ast.Assign) and any(
            isinstance(n, ast.Name) and n.id == "SOCKET_FIXTURE" for n in node.targets
        ):
            return ast.literal_eval(node.value)
    raise RuntimeError("Missing known no-provider QA teacher fixture")


def require_deployment():
    if urlsplit(WEB).hostname != "lyoonestagingweb-staging.up.railway.app":
        raise RuntimeError("Non-staging Web URL refused")
    if urlsplit(API).hostname != "lyojourneystagingbackend-staging.up.railway.app":
        raise RuntimeError("Non-staging API URL refused")
    with urlopen(WEB + "/api/health", timeout=20) as response:
        health = json.load(response)
    if health.get("status") != "healthy" or health.get("commit") != EXPECTED:
        raise RuntimeError("Exact deployed staging Web SHA mismatch")
    print("PASS: Web staging exact deployed SHA verified", flush=True)


async def run():
    require_deployment()
    marker = secrets.token_hex(12)
    password = "LYO-30m-" + secrets.token_hex(20) + "aA9!"
    person = {
        "email": "lyo-30m-" + marker + "@example.org",
        "username": "qathirty" + marker[:18],
        "password": password, "confirm_password": password,
        "first_name": "Synthetic", "last_name": "Endurance",
    }
    token = None
    created = False
    passed = False
    clicks = 0
    reloads = 0
    observed = 0
    js_errors = []
    start = None
    browser = None

    try:
        for attempt in range(3):
            code, data = http("POST", "/api/v1/auth/register", person)
            if code in (200, 201):
                created = True
                break
            if code != 429 or attempt == 2:
                raise RuntimeError("Synthetic staging registration refused")
            await asyncio.sleep(65)
        token = data.get("access_token")
        if not token:
            code, res = http("POST", "/api/v1/auth/login", {
                "email": person["email"], "password": password,
            })
            if code != 200 or not res.get("access_token"):
                raise RuntimeError("Registered learner cannot be cleaned up")
            token = res["access_token"]
        code, account = http("GET", "/api/v1/auth/me", token=token)
        if code != 200 or not account.get("id"):
            raise RuntimeError("Synthetic learner identity verification failed")

        async with async_playwright() as playwright:
            browser = await playwright.chromium.launch(
                headless=True, args=["--no-sandbox", "--autoplay-policy=no-user-gesture-required"]
            )
            context = await browser.new_context(
                viewport={"width": 412, "height": 915},
                device_scale_factor=1,
            )
            allowed_hosts = {urlsplit(WEB).hostname, urlsplit(API).hostname}
            provider_attempts = 0

            async def safe_request(route):
                nonlocal provider_attempts
                request = route.request
                parsed = urlsplit(request.url)
                path = parsed.path
                method = request.method.upper()
                if parsed.hostname in {"lyoai.app", "api.lyoai.app"}:
                    await route.abort(error_code="blockedbyclient")
                    raise RuntimeError("Production host requested")
                if ("/tts/" in path or "/ai/" in path) and method != "GET":
                    provider_attempts += 1
                    await route.abort(error_code="blockedbyclient")
                    return
                if method in {"POST", "PUT", "PATCH", "DELETE"} and (
                    parsed.hostname not in allowed_hosts
                    or path not in {"/auth/login", "/api/v1/auth/login"}
                ):
                    provider_attempts += 1
                    await route.abort(error_code="blockedbyclient")
                    return
                await route.continue_()

            await context.route("**/*", safe_request)
            page = await context.new_page()
            page.on("pageerror", lambda error: js_errors.append(type(error).__name__))
            await page.goto(WEB + "/auth/login", wait_until="domcontentloaded", timeout=35000)
            await page.get_by_role("button", name="Log In", exact=True).wait_for(
                state="visible", timeout=25000)
            await page.get_by_label("Email", exact=True).fill(person["email"])
            await page.get_by_label("Password", exact=True).fill(password)
            await page.get_by_role("button", name="Log In", exact=True).click()
            await page.wait_for_function(
                "() => Boolean(localStorage.getItem('lyo_token'))", timeout=35000
            )
            print("PASS: actual visible Web login for synthetic learner", flush=True)

            await context.add_init_script(fixture())
            start = time.monotonic()
            await page.goto(
                WEB + "/classroom?topic=Fractions&duration=30&language=en-US",
                wait_until="domcontentloaded", timeout=35000
            )
            await page.get_by_role("button", name="Leave classroom").wait_for(
                state="visible", timeout=30000
            )
            await page.get_by_text("Equivalent fractions show the same value",
                                   exact=False).first.wait_for(
                state="visible", timeout=24000
            )
            scene_ms = round((time.monotonic() - start) * 1000)
            print("PASS: initial synthetic lesson visible, startup_ms=" +
                  str(scene_ms) + " (NOT audible latency)", flush=True)

            notebook = page.get_by_role("button", name="Open full lesson transcript")
            if await notebook.count() != 1:
                raise RuntimeError("Authenticated Classroom notebook control missing")

            next_check = start + STEP
            last_report = start + 300
            # Duration is measured from first Classroom navigation.
            while time.monotonic() - start < DURATION:
                delay = max(0, min(3, next_check - time.monotonic()))
                if delay:
                    await asyncio.sleep(delay)
                if time.monotonic() < next_check:
                    continue
                observed += 1
                if not await page.get_by_role("button", name="Leave classroom").is_visible():
                    raise RuntimeError("Classroom lost its authenticated navigation")
                if await page.get_by_text("Equivalent fractions show the same value",
                                          exact=False).count() == 0:
                    raise RuntimeError("Synthetic teaching scene disappeared")
                # Genuine browser interactions throughout the time window.
                await notebook.click(timeout=12000)
                # The notebook drawer has a full-screen backdrop, so the
                # toolbar opener is not clickable until its own close control
                # is used; click the real visible drawer close button.
                tabs = page.get_by_role("tablist", name="Notebook")
                await tabs.wait_for(state="visible", timeout=5000)
                await tabs.get_by_role("tab", name="What was said").click()
                await page.locator(
                    "div.fixed.right-0.top-0.bottom-0 button"
                ).first.click(timeout=7000)
                await tabs.wait_for(state="hidden", timeout=7000)
                clicks += 3
                if observed in (36, 77):
                    await page.reload(wait_until="domcontentloaded", timeout=35000)
                    await page.get_by_role("button", name="Leave classroom").wait_for(
                        state="visible", timeout=25000
                    )
                    await page.get_by_text("Equivalent fractions show the same value",
                                           exact=False).first.wait_for(
                        state="visible", timeout=30000
                    )
                    notebook = page.get_by_role("button", name="Open full lesson transcript")
                    reloads += 1
                    print("PASS: authenticated Classroom browser refresh and lesson UI recovery",
                          flush=True)
                if time.monotonic() >= last_report:
                    print("CHECKPOINT elapsed_s=" + str(round(time.monotonic() - start)) +
                          " browser_actions=" + str(clicks) +
                          " refreshes=" + str(reloads), flush=True)
                    last_report += 300
                next_check += STEP
            actual = round(time.monotonic() - start, 1)
            if actual < 1800 or clicks < 75 or reloads != 2:
                raise RuntimeError("Required active 30-minute browser checks missing")
            if js_errors:
                raise RuntimeError("Client JavaScript error in prolonged session")
            if provider_attempts > 0:
                print("PASS: AI/TTS provider requests explicitly blocked from network", flush=True)
            print("PASS: synthetic authenticated Web endurance duration_s=" + str(actual) +
                  " browser_actions=" + str(clicks) + " reloads=" + str(reloads),
                  flush=True)
            print("LIMIT: NOT a 30-minute real AI teacher, real grades, or audible speech",
                  flush=True)
            passed = True
    except Exception as exc:
        print("FAIL: 30-minute Web endurance " + type(exc).__name__
              + " (credentials and details redacted)", file=sys.stderr, flush=True)
    finally:
        if browser:
            try:
                await browser.close()
            except Exception:
                pass
        if created:
            # Refresh token even if the 30-minute JWT expired.
            code, fresh = http("POST", "/api/v1/auth/login", {
                "email": person["email"], "password": password,
            })
            cleanup_token = fresh.get("access_token") if code == 200 else token
            if not cleanup_token:
                passed = False
                print("FAIL: staging cleanup token unavailable", file=sys.stderr)
            else:
                code, deleted = http("DELETE", "/auth/me", token=cleanup_token)
                if code != 200 or deleted.get("deleted") is not True:
                    passed = False
                    print("FAIL: synthetic staging account cleanup unverified",
                          file=sys.stderr)
                else:
                    print("PASS: synthetic learner permanently deleted", flush=True)
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(asyncio.run(run()))
