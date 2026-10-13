#!/usr/bin/env python3
"""Live browser gate for the isolated Lyo One web and backend staging services.

No production accounts, documents, APIs or provider tokens. Uses synthetic
registration and Chromium to prove that the actual Next.js interface saves
and restores learning navigation using the authenticated staging backend.
"""
import json
import os
import secrets
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

from playwright.sync_api import expect, sync_playwright

WEB = "https://lyoonestagingweb-staging.up.railway.app"
API = "https://lyojourneystagingbackend-staging.up.railway.app"
ARTIFACTS = Path(os.environ.get("LYO_STAGING_SCREENSHOT_DIR", "/tmp/lyo-one-browser-evidence"))


def request(path, *, method="GET", data=None, token=None, expected=200):
    assert path.startswith("/") and not path.startswith("//")
    headers = {"Accept": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    if data is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(
        API + path,
        headers=headers,
        data=json.dumps(data).encode() if data is not None else None,
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=40) as res:
            status = res.status
            payload = json.load(res)
    except urllib.error.HTTPError as exc:
        status = exc.code
        try:
            payload = json.load(exc)
        except Exception:
            payload = {}
    if status != expected:
        # Do not print tokens or sensitive request payloads.
        raise AssertionError(f"{method} {path.split('?')[0]}: wanted HTTP {expected}, received {status}; response fields={sorted(payload.keys()) if isinstance(payload, dict) else 'non-json'}")
    return payload


def new_learner():
    suffix = uuid.uuid4().hex[:12]
    email = f"lyo-browser-{suffix}@example.com"
    password = "Lyo1!" + secrets.token_urlsafe(18)
    created = request("/api/v1/auth/register", method="POST", data={
        "email": email, "password": password, "full_name": "Staging Browser",
    })
    assert created.get("user_id"), "Registration did not create an account"
    login = request("/api/v1/auth/login", method="POST",
                    data={"email": email, "password": password})
    token = login.get("access_token")
    assert isinstance(token, str) and len(token) > 30, "No bearer token"
    return token


def run():
    if os.environ.get("LYO_ONE_STAGING_BROWSER") != "1":
        raise RuntimeError("Browser test may only run with LYO_ONE_STAGING_BROWSER=1")
    assert urllib.parse.urlparse(WEB).hostname == "lyoonestagingweb-staging.up.railway.app"
    assert urllib.parse.urlparse(API).hostname == "lyojourneystagingbackend-staging.up.railway.app"
    request("/health")
    token = new_learner()

    goal = request("/api/v1/me/coach/goals", method="POST", token=token,
                   data={"goal_type": "mastery", "title": "Synthetic music harmony",
                         "subject": "Music",
                         "skills": [{"name": "Harmonic intervals", "concept_id": "harmonic-intervals"}]}, expected=201)
    goal_id = goal["goal"]["id"]
    print("PASS synthetic learner, authenticated goal and isolated API", flush=True)

    # Use an actual Chromium browser with the real Next.js JS bundle.
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        context = browser.new_context(viewport={"width": 1280, "height": 860},
                                      device_scale_factor=1)
        context.add_init_script(f"window.localStorage.setItem('lyo_token', {json.dumps(token)});")
        page = context.new_page()
        failures = []
        page.on("pageerror", lambda exc: failures.append(str(exc)[:250]))
        try:
            page.goto(WEB + "/", wait_until="domcontentloaded", timeout=60000)
            expect(page.get_by_role("heading", name="What would you like to explore today?")).to_be_visible(timeout=35000)
            expect(page.get_by_role("button", name="AI Chat Ask anything")).to_be_visible(timeout=15000)
            print("PASS unified Home loads with direct capability shortcuts", flush=True)

            coach = page.get_by_role("region", name="Lyo Coach next learning step")
            expect(coach).to_be_visible(timeout=45000)
            start = coach.get_by_text("Start this step")
            tag = start.evaluate("(node) => node.closest('button,a')?.tagName || 'unknown'")
            if tag != "BUTTON":
                fallback = start.evaluate("(node) => node.closest('a')?.getAttribute('data-journey-fallback') || 'not-specified'")
                print(f"DIAGNOSTIC Coach entry rendered as {tag} fallback={fallback}", flush=True)
            start.click()
            page.wait_for_url("**/classroom?*", timeout=35000)
            first_url = urllib.parse.urlparse(page.url)
            journey_id = urllib.parse.parse_qs(first_url.query).get("journeyId", [None])[0]
            assert journey_id and len(journey_id) > 10, "No persisted journey ID in Classroom"
            jpath = "/api/v1/me/coach/journeys/" + urllib.parse.quote(journey_id, safe="")
            live = request(jpath, token=token)
            assert live["goal_id"] == goal_id and live["active_surface"] == "classroom"
            assert live["revision"] == 1
            print("PASS Home Coach mission -> authenticated Classroom with saved journey", flush=True)

            # In provider-less staging the lesson itself may be unable to
            # generate; the navigation layer must remain independent.
            page.get_by_role("button", name="Leave classroom").click(timeout=20000)
            page.wait_for_url(WEB + "/", timeout=35000)
            restored = request(jpath, token=token)
            assert restored["active_surface"] == "coach" and restored["revision"] == 2
            print("PASS Classroom -> original Coach destination and durable revision", flush=True)

            # Two distinct Test Prep exam identities should remain selectable
            # by URL, including after refresh (not silently newest exam).
            exam1 = request("/api/v1/me/study_plans/profiles/start", method="POST", token=token,
                            data={"request_id": "browser-exam-" + uuid.uuid4().hex}, expected=201)["profile_id"]
            exam2 = request("/api/v1/me/study_plans/profiles/start", method="POST", token=token,
                            data={"request_id": "browser-exam-" + uuid.uuid4().hex}, expected=201)["profile_id"]
            assert exam1 != exam2
            page.goto(WEB + "/test-prep?profileId=" + urllib.parse.quote(exam1, safe=""),
                      wait_until="domcontentloaded", timeout=60000)
            chooser = page.get_by_role("combobox", name="Choose a test")
            expect(chooser).to_have_value(exam1, timeout=35000)
            page.reload(wait_until="domcontentloaded")
            expect(page.get_by_role("combobox", name="Choose a test")).to_have_value(exam1, timeout=35000)
            print("PASS Test Prep selects and reloads exact exam without replacing it", flush=True)

            # Transient verifier errors must never destroy the learner token or
            # replace an explicitly selected exam with a default stale exam.
            for transient in (429, 503):
                def fail_verification(route, code=transient):
                    route.fulfill(status=code, content_type="application/json",
                                  body='{"detail":"Synthetic temporary verification error"}')
                page.route("**/api/v1/auth/me", fail_verification)
                page.reload(wait_until="domcontentloaded")
                expect(page.get_by_role("heading", name="Session verification unavailable")).to_be_visible(timeout=30000)
                assert page.evaluate("window.localStorage.getItem('lyo_token')") == token, (
                    "Transient auth error discarded an existing access token"
                )
                assert urllib.parse.parse_qs(urllib.parse.urlparse(page.url).query).get("profileId") == [exam1], (
                    "Transient auth error replaced the selected exam URL"
                )
                page.unroute("**/api/v1/auth/me", fail_verification)
                page.get_by_role("button", name="Retry verification").click()
                expect(page.get_by_role("combobox", name="Choose a test")).to_have_value(exam1, timeout=30000)
                print(f"PASS transient HTTP {transient} preserves token, exam and retry", flush=True)

            # A Chat Coach turn is generated deterministically from the same
            # learning goal (without an external model provider in staging).
            page.goto(WEB + "/chat", wait_until="domcontentloaded", timeout=60000)
            composer = page.get_by_placeholder("Message Lyo...")
            expect(composer).to_be_visible(timeout=30000)
            composer.fill("What should I study today?")
            composer.press("Enter")
            expect(page.get_by_label("Lyo Coach mission")).to_be_visible(timeout=45000)
            print("PASS Chat displays live structured Coach mission", flush=True)

            assert not [x for x in failures if "TypeError" in x or "ReferenceError" in x], f"JS errors: {failures[:5]}"
            print("PASS isolated browser learning workspace integration", flush=True)
        except Exception:
            ARTIFACTS.mkdir(parents=True, exist_ok=True)
            try:
                page.screenshot(path=str(ARTIFACTS / "failure.png"), full_page=True, timeout=10000)
                (ARTIFACTS / "page.txt").write_text(
                    f"URL: {page.url}\nTitle: {page.title()}\nBrowser errors: {failures[:10]}\n"
                )
            except Exception:
                pass
            raise
        finally:
            browser.close()


if __name__ == "__main__":
    try:
        run()
    except Exception as exc:
        print(f"FAIL isolated browser gate: {str(exc)[:1000]}", file=sys.stderr)
        sys.exit(1)
