#!/usr/bin/env python3
"""Authenticated deployed-Web course reader QA without AI/provider spending.

Intercept only GET /api/v1/learning/courses/{synthetic-id}; never send
a fake course to staging storage or call Classroom/AI generation.
"""
import asyncio
import json
import os
import secrets
from pathlib import Path
from urllib.parse import urlsplit

from playwright.async_api import async_playwright
from web_first_live_classroom_auth import API, http

WEB = os.getenv("LYO_WEB_BASE_URL", "https://lyoonestagingweb-staging.up.railway.app").rstrip("/")
EXPECTED_SHA = os.environ["EXPECTED_WEB_SHA"]
assert (urlsplit(WEB).hostname or "").endswith("-staging.up.railway.app")
assert (urlsplit(API).hostname or "").endswith("-staging.up.railway.app")

async def run():
    marker = secrets.token_hex(12)
    password = "LyoQA-" + secrets.token_hex(18) + "aA9!"
    person = {
        "email": "lyo-qa-" + marker + "@example.org",
        "username": "qa" + marker,
        "password": password,
        "confirm_password": password,
        "first_name": "Staging",
        "last_name": "QA",
    }
    artifact_dir = Path("artifacts/web-first-course-reader")
    artifact_dir.mkdir(parents=True, exist_ok=True)
    token = None
    created = False
    try:
        from urllib.request import urlopen
        with urlopen(WEB + "/api/health", timeout=20) as response:
            status = json.loads(response.read())
        if status.get("status") != "healthy" or status.get("commit") != EXPECTED_SHA:
            raise RuntimeError("Deployed Web SHA/health does not match test contract")
        print("PASS: deployed Web exact SHA and health", flush=True)

        code, registration = http("POST", "/api/v1/auth/register", person)
        if code not in (200, 201):
            raise RuntimeError(f"Synthetic registration failed HTTP {code}")
        created = True
        token = registration.get("access_token")
        if not token:
            code, login = http("POST", "/api/v1/auth/login", {
                "email": person["email"], "password": password,
            })
            if code != 200 or not login.get("access_token"):
                raise RuntimeError("Synthetic cleanup token unavailable")
            token = login["access_token"]

        course_id = "11111111-1111-4111-8111-" + marker[:12]
        empty_id = "22222222-2222-4222-8222-" + marker[:12]
        base_response = {
            "title": "Saved Algebra Course", "description": "Two real lessons",
            "subject": "Mathematics", "difficulty_level": "intermediate",
            "estimated_duration_hours": 1,
            "created_at": "2026-11-21T00:00:00Z",
        }
        full = {
            **base_response, "id": course_id, "lessons_count": 2,
            "lessons": [
                {
                    "id": "lesson-saved-1", "title": "Balancing Equations",
                    "content": "Saved lesson body: add the same amount to both sides.",
                    "order_index": 0, "estimated_duration_minutes": 20,
                },
                {
                    "id": "lesson-saved-2", "title": "Quadratic Expressions",
                    "content": "Second saved lesson body: factor carefully.",
                    "order_index": 1, "estimated_duration_minutes": 25,
                },
            ],
        }
        empty = {
            **base_response, "id": empty_id, "lessons_count": 0, "lessons": [],
        }
        requested = []

        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True, args=["--no-sandbox"])
            try:
                context = await browser.new_context(viewport={"width": 412, "height": 915})
                allowed = {urlsplit(WEB).hostname, urlsplit(API).hostname}

                async def safe_route(route):
                    request = route.request
                    parsed = urlsplit(request.url)
                    host = parsed.hostname or ""
                    method = request.method.upper()
                    if host in {"api.lyoai.app", "lyoai.app"} or (
                        method in {"POST", "PUT", "PATCH", "DELETE"} and host not in allowed
                    ):
                        raise RuntimeError("Refusing production or non-staging mutation")
                    if host == urlsplit(API).hostname and (
                        "/classroom/" in parsed.path or "/ai/" in parsed.path
                    ):
                        raise RuntimeError("Unexpected model/Classroom request in zero-provider QA")
                    await route.continue_()

                await context.route("**/*", safe_route)
                page = await context.new_page()
                await page.goto(WEB + "/auth/login", wait_until="domcontentloaded", timeout=30000)
                await page.get_by_role("button", name="Log In", exact=True).wait_for(
                    state="visible", timeout=30000
                )
                await page.get_by_label("Email", exact=True).fill(person["email"])
                await page.get_by_label("Password", exact=True).fill(password)
                await page.get_by_role("button", name="Log In", exact=True).click()
                await page.wait_for_function(
                    "() => Boolean(window.localStorage.getItem('lyo_token'))",
                    timeout=35000,
                )
                print("PASS: real visible Web login", flush=True)

                async def only_course_fixture(route):
                    parsed = urlsplit(route.request.url)
                    if route.request.method != "GET":
                        raise RuntimeError("Course fixture cannot accept mutations")
                    requested.append(parsed.path)
                    if parsed.path.endswith("/" + course_id):
                        body = full
                    elif parsed.path.endswith("/" + empty_id):
                        body = empty
                    else:
                        raise RuntimeError("Unexpected fixture course id")
                    await route.fulfill(status=200, content_type="application/json",
                                        body=json.dumps(body))

                await page.route("**/api/v1/learning/courses/*", only_course_fixture)
                await page.goto(WEB + "/courses/" + course_id,
                                wait_until="domcontentloaded", timeout=30000)
                await page.get_by_text("Saved lesson body:", exact=False).wait_for(
                    state="visible", timeout=35000
                )
                assert await page.get_by_text("Balancing Equations", exact=False).count() > 0
                assert await page.get_by_role("button", name="Mark as Complete").is_enabled()
                await page.screenshot(path=str(artifact_dir / "saved_lessons.png"))
                print("PASS: top-level string lessons rendered and complete action enabled", flush=True)

                await page.goto(WEB + "/courses/" + empty_id,
                                wait_until="domcontentloaded", timeout=30000)
                await page.get_by_text("Lessons are not available yet", exact=True).wait_for(
                    state="visible", timeout=35000
                )
                assert await page.get_by_role("button", name="Retry loading").is_enabled()
                assert await page.get_by_role("button", name="Mark as Complete").count() == 0
                await page.screenshot(path=str(artifact_dir / "empty_course.png"))
                print("PASS: missing lessons display retry without false progress", flush=True)
                assert len(requested) >= 2
            finally:
                await browser.close()
    finally:
        if created:
            if not token:
                raise RuntimeError("Cannot remove synthetic account without token")
            # Shared GitHub runner IPs can hit the staging auth limit
            # (Retry-After: 60). Respect the documented window rather than
            # skipping deletion or treating a 429 as successful cleanup.
            for attempt in range(3):
                code, _ = http("DELETE", "/api/v1/auth/me", token=token)
                if code in (200, 204):
                    print("PASS: synthetic learner deleted", flush=True)
                    break
                if code != 429 or attempt == 2:
                    raise RuntimeError(
                        f"Synthetic account cleanup failed HTTP {code}; "
                        "manual staging QA-account reconciliation required"
                    )
                print("Rate-limited cleanup; respecting 65s backoff", flush=True)
                await asyncio.sleep(65)

if __name__ == "__main__":
    asyncio.run(run())
