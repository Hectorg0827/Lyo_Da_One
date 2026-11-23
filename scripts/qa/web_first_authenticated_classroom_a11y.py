#!/usr/bin/env python3
"""Authenticated deployed-staging Classroom and Chat accessibility preflight.

One disposable learner; login via visible form. Actual Web UI; Classroom
socket replaced with no-provider synthetic bridge/authoritative scene.
All AI/TTS requests and non-auth browser mutations are blocked. Axe scans
mobile/desktop layouts. No real teacher, microphone, grading or production.
"""
import asyncio
import json
import os
import secrets
import sys
from pathlib import Path
from urllib.parse import urlsplit
from urllib.request import urlopen

from playwright.async_api import async_playwright
from web_first_live_classroom_auth import API, http
from web_first_bridge_visual_fixture import SOCKET_FIXTURE

WEB = "https://lyoonestagingweb-staging.up.railway.app"
EXPECTED_SHA = os.environ["EXPECTED_WEB_SHA"]
AXE_SCRIPT = Path("/tmp/lyo-axe/node_modules/axe-core/axe.min.js")
ROUTES = ("/chat", "/classroom?topic=Fractions&duration=5&language=en-US")
WIDTHS = (320, 390, 768)


async def main():
    if urlsplit(WEB).hostname != "lyoonestagingweb-staging.up.railway.app":
        raise RuntimeError("Refusing nonstaging Web")
    if urlsplit(API).hostname != "lyojourneystagingbackend-staging.up.railway.app":
        raise RuntimeError("Refusing nonstaging backend")
    if not AXE_SCRIPT.is_file():
        raise RuntimeError("axe-core not installed at approved CI location")

    with urlopen(WEB + "/api/health", timeout=15) as reply:
        health = json.loads(reply.read(8192))
    if health.get("status") != "healthy" or health.get("commit") != EXPECTED_SHA:
        raise RuntimeError("Deployed Web revision does not match exact source")
    with urlopen(API + "/openapi.json", timeout=20) as reply:
        schema = json.loads(reply.read(8_000_000))
    if "delete" not in schema.get("paths", {}).get("/auth/me", {}):
        raise RuntimeError("No synthetic account cleanup endpoint")
    print("PASS: exact live staging Web revision and cleanup contract", flush=True)

    marker = secrets.token_hex(12)
    password = "LYO-a11y-" + secrets.token_hex(18) + "aA9!"
    user = {
        "email": "lyo-a11y-" + marker + "@example.org",
        "username": "a11y" + marker[:20],
        "password": password, "confirm_password": password,
        "first_name": "Synthetic", "last_name": "A11Y",
    }
    token, created, valid = None, False, False
    issues = []
    try:
        for attempt in range(3):
            code, registered = http("POST", "/api/v1/auth/register", user)
            if code in (200, 201):
                break
            if code != 429 or attempt == 2:
                raise RuntimeError("Synthetic staging registration refused")
            await asyncio.sleep(65)
        created = True
        token = registered.get("access_token")
        if not token:
            code, result = http("POST", "/api/v1/auth/login", {
                "email": user["email"], "password": password,
            })
            if code != 200 or not result.get("access_token"):
                raise RuntimeError("Created learner but cleanup token unavailable")
            token = result["access_token"]

        async with async_playwright() as playwright:
            browser = await playwright.chromium.launch(headless=True, args=["--no-sandbox"])
            try:
                context = await browser.new_context(viewport={"width": 390, "height": 860})
                await context.add_init_script(SOCKET_FIXTURE)
                blocked_provider = []
                allowed_hosts = {urlsplit(WEB).hostname, urlsplit(API).hostname}

                async def protect_request(route):
                    request = route.request
                    parsed = urlsplit(request.url)
                    host, path, method = parsed.hostname or "", parsed.path, request.method.upper()
                    if host in {"lyoai.app", "api.lyoai.app"}:
                        await route.abort(error_code="blockedbyclient")
                        raise RuntimeError("Production request attempted by staging Web")
                    if host not in allowed_hosts and method != "GET":
                        await route.abort(error_code="blockedbyclient")
                        return
                    if (path.startswith("/api/v1/tts/") or "/ai/" in path
                            or "/classroom/" in path and method != "GET"):
                        blocked_provider.append(path.split("?")[0])
                        await route.abort(error_code="blockedbyclient")
                        return
                    if method in {"POST", "PUT", "PATCH", "DELETE"} and path not in (
                        "/api/v1/auth/login", "/auth/login",
                    ):
                        await route.abort(error_code="blockedbyclient")
                        return
                    await route.continue_()

                await context.route("**/*", protect_request)
                page = await context.new_page()
                await page.goto(WEB + "/auth/login", wait_until="domcontentloaded", timeout=30000)
                await page.get_by_role("button", name="Log In", exact=True).wait_for(
                    state="visible", timeout=30000)
                await page.get_by_label("Email", exact=True).fill(user["email"])
                await page.get_by_label("Password", exact=True).fill(password)
                await page.get_by_role("button", name="Log In", exact=True).click()
                await page.wait_for_function(
                    "() => Boolean(localStorage.getItem('lyo_token'))",
                    timeout=35000,
                )
                print("PASS: real visible synthetic Web login", flush=True)

                for route in ROUTES:
                    await page.goto(WEB + route, wait_until="domcontentloaded", timeout=30000)
                    if route.startswith("/classroom"):
                        await page.get_by_text("Start learning now", exact=False).first.wait_for(
                            state="visible", timeout=20000
                        )
                        print("PASS: real Classroom rendered synthetic ungraded teaching bridge", flush=True)
                    else:
                        await page.wait_for_selector("main", timeout=15000)

                    await page.add_script_tag(path=str(AXE_SCRIPT))
                    for width in WIDTHS:
                        await page.set_viewport_size({"width": width, "height": 860})
                        await page.wait_for_timeout(240)
                        result = await page.evaluate("""async () => {
                          const results = await axe.run(document, {
                            runOnly: {type:'tag', values:[
                              'wcag2a','wcag2aa','wcag21a','wcag21aa','wcag22aa'
                            ]}
                          });
                          return {
                            severe: results.violations.filter(v =>
                              v.impact === 'serious' || v.impact === 'critical'
                            ).map(v => ({
                              rule: v.id, severity: v.impact,
                              nodes: v.nodes.slice(0,5).map(n => n.target.join(' '))
                            })),
                            overflow: document.documentElement.scrollWidth -
                              document.documentElement.clientWidth,
                          };
                        }""")
                        if result["severe"]:
                            issues.append(f"{route}@{width}: axe {result['severe']}")
                        if result["overflow"] > 2:
                            issues.append(f"{route}@{width}: overflow {result['overflow']}px")
                        print(f"Scanned {route.split('?')[0]} @{width}px", flush=True)
                if blocked_provider:
                    print("PASS: model/TTS routes were intercepted without network requests", flush=True)
                valid = not issues
            finally:
                await browser.close()
    except Exception as exc:
        print("QA FAILURE: " + type(exc).__name__ + " (details redacted)", file=sys.stderr)
    finally:
        if created:
            if not token:
                print("CLEANUP FAILED: no token", file=sys.stderr)
                valid = False
            else:
                code, result = http("DELETE", "/auth/me", token=token)
                if code != 200 or result.get("deleted") is not True:
                    login_code, new_login = http("POST", "/api/v1/auth/login", {
                        "email": user["email"], "password": password,
                    })
                    if login_code == 200 and new_login.get("access_token"):
                        code, result = http("DELETE", "/auth/me", token=new_login["access_token"])
                if code == 200 and result.get("deleted") is True:
                    print("PASS: synthetic learner permanently deleted", flush=True)
                else:
                    print("CLEANUP FAILED: account not verifiably deleted", file=sys.stderr)
                    valid = False
        for issue in issues:
            print("FAIL: " + issue[:350], flush=True)
    if valid:
        print("PASS: authenticated Chat and Classroom serious/critical axe + viewport smoke, 6 checks", flush=True)
    print("LIMIT: synthetic bridge, no real AI/classroom grading, no physical speaker or screen reader", flush=True)
    return 0 if valid else 1


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
