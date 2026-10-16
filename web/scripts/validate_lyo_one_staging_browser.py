#!/usr/bin/env python3
"""Live browser gate for the isolated Lyo One web and backend staging services.

No production accounts, documents, APIs or provider tokens. Uses synthetic
registration and Chromium to prove that the actual Next.js interface saves
and restores learning navigation using the authenticated staging backend.
"""
import json
import os
import re
import secrets
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path
from datetime import date, timedelta

from playwright.sync_api import expect, sync_playwright

WEB = "https://lyoonestagingweb-staging.up.railway.app"
API = "https://lyojourneystagingbackend-staging.up.railway.app"
ARTIFACTS = Path(os.environ.get("LYO_STAGING_SCREENSHOT_DIR", "/tmp/lyo-one-browser-evidence"))


def request(path, *, method="GET", data=None, token=None, expected=200, timeout=40):
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
        with urllib.request.urlopen(req, timeout=timeout) as res:
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


def verify_deployed_pair():
    expected = {name: os.environ.get(name, "") for name in
                ("LYO_ONE_EXPECTED_BACKEND_SHA", "LYO_ONE_EXPECTED_CLIENT_SHA")}
    if any(not re.fullmatch(r"[0-9a-f]{40}", value) for value in expected.values()):
        raise ValueError("Full expected backend and client SHAs are required for browser validation")
    health = request("/health")
    with urllib.request.urlopen(WEB + "/api/health", timeout=35) as response:
        client = json.load(response)
    pair = (health.get("commit_sha"), client.get("commit"))
    if health.get("environment") != "staging" or pair != tuple(expected.values()):
        raise AssertionError(f"Staging deployment pair mismatch: received {pair}")
    if os.getenv("LYO_ONE_TEST_PREP_PROVIDER_READY") == "yes":
        models = health.get("services", {}).get("ai", {}).get("models", {})
        if not any(name.startswith("gemini-") and model.get("configured") for name, model in models.items()):
            raise RuntimeError("Real planned-session browser validation requires the separate staging Gemini key")
    return pair


def planned_exam(token, topic, days):
    prep = "/api/v1/me/study_plans"
    profile = request(prep + "/profiles/start", method="POST", token=token,
                      data={"request_id": "planned-exam-" + uuid.uuid4().hex}, expected=201)["profile_id"]
    path = prep + "/profiles/" + urllib.parse.quote(profile, safe="")
    test_date = (date.today() + timedelta(days=days)).isoformat()
    request(path, method="PATCH", token=token, data={
        "expected_revision": 0, "subject": "Algebra", "test_date": test_date,
        "topics": [{"name": topic, "confidence": 3, "weight": 1}],
        "daily_minutes_available": 20, "study_days_per_week": 5, "timezone": "America/New_York",
    })
    intake = request(prep + "/intake/turn", method="POST", token=token, timeout=80, data={
        "test_profile_id": profile, "request_id": "intake-" + uuid.uuid4().hex,
        "timezone": "America/New_York",
        "user_message": f"My Algebra exam is {test_date}, covering {topic}. I have 20 minutes per day, five days per week. Mixed test format, confidence 3/10, stress 3/10. Those are my complete test details. Please build my study plan.",
    })
    if intake.get("test_profile_id") != profile or not intake.get("intake_complete"):
        raise AssertionError("Real Test Prep intake did not complete for the selected synthetic exam")
    generated = request(prep + "/plans/generate?test_profile_id=" + urllib.parse.quote(profile, safe=""),
                        method="POST", token=token, timeout=90)
    state = request(prep + "/state?profile_id=" + urllib.parse.quote(profile, safe=""), token=token)
    if state.get("profile", {}).get("id") != profile or state.get("plan", {}).get("id") != generated.get("plan_id"):
        raise AssertionError("Generated study plan belongs to a different exam")
    session = next((s for s in state.get("sessions", []) if s.get("status") == "scheduled"), None)
    if not session:
        raise AssertionError("The real plan contains no scheduled study session")
    return profile, session


def validate_planned_session_returns(page, token):
    # Actual intake/plan APIs create the records; no database seed or fabricated assessment.
    exams = [planned_exam(token, "Linear equations", 10), planned_exam(token, "Quadratic equations", 17)]
    assert exams[0][0] != exams[1][0]
    for profile, session in exams:
        page.goto(WEB + "/test-prep?profileId=" + profile, wait_until="domcontentloaded", timeout=60000)
        expect(page.get_by_role("combobox", name="Choose a test")).to_have_value(profile, timeout=35000)
        schedule = page.get_by_role("region", name="Full study schedule")
        expect(schedule).to_be_visible(timeout=35000)
        schedule.get_by_role("button", name=re.compile(r"^All \d+ sessions$")).click()
        entry = schedule.locator(f'button[data-study-session-id="{session["id"]}"]')
        expect(entry.last).to_be_visible(timeout=20000)
        entry.last.click()
        page.wait_for_url("**/classroom?*", timeout=35000)
        journey_id = urllib.parse.parse_qs(urllib.parse.urlparse(page.url).query).get("journeyId", [None])[0]
        assert journey_id, "Scheduled session did not save a real journey"
        journey = request("/api/v1/me/coach/journeys/" + journey_id, token=token)
        assert journey["context"]["test_profile_id"] == profile
        assert journey["context"]["study_session_id"] == session["id"]
        page.get_by_role("button", name="Leave classroom").click(timeout=20000)
        page.wait_for_url("**/test-prep?*", timeout=35000)
        query = urllib.parse.parse_qs(urllib.parse.urlparse(page.url).query)
        assert query.get("profileId") == [profile] and query.get("sessionId") == [session["id"]]
        page.reload(wait_until="domcontentloaded")
        expect(page.get_by_role("combobox", name="Choose a test")).to_have_value(profile, timeout=35000)
        expect(page.get_by_text("Returned to study session:", exact=False)).to_be_visible(timeout=20000)
        print("PASS real planned Test Prep session -> Classroom -> exact exam/session return and reload", flush=True)


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
    for attempt in range(30):
        try:
            before = verify_deployed_pair()
            break
        except (AssertionError, OSError):
            time.sleep(7)
    else:
        raise AssertionError("The intended staging pair did not settle before browser validation")
    print(f"PASS pinned staging pair backend={before[0]} client={before[1]}", flush=True)
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
                blocked = {"count": 0}
                def fail_verification(route):
                    blocked["count"] += 1
                    route.fulfill(status=transient, content_type="application/json",
                                  body='{"detail":"Synthetic temporary verification error"}')
                page.route("**/api/v1/auth/me", fail_verification)
                page.reload(wait_until="domcontentloaded")
                try:
                    expect(page.get_by_role("heading", name="Session verification unavailable")).to_be_visible(timeout=12000)
                except Exception:
                    # Synthetic staging account only; never log token values.
                    excerpt = page.locator("body").inner_text(timeout=5000)[:350]
                    has_token = page.evaluate("Boolean(window.localStorage.getItem('lyo_token'))")
                    print(f"DIAGNOSTIC auth HTTP {transient}: intercepted={blocked['count']} url={page.url} token-present={has_token} page={excerpt!r}", flush=True)
                    raise
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
            chat_responses = []
            page.on("response", lambda response: chat_responses.append(response)
                    if "/api/v1/lyo2/chat/stream" in response.url else None)
            page.goto(WEB + "/chat", wait_until="domcontentloaded", timeout=60000)
            composer = page.get_by_placeholder("Message Lyo...")
            expect(composer).to_be_visible(timeout=30000)
            composer.fill("What should I study today?")
            composer.press("Enter")
            try:
                expect(page.get_by_label("Lyo Coach mission")).to_be_visible(timeout=45000)
            except Exception:
                import re
                event_types = []
                for response in chat_responses:
                    try:
                        payload = response.body().decode("utf-8", errors="replace")
                        event_types.extend(re.findall(r'"type"\\s*:\\s*"([^"]+)"', payload))
                    except Exception:
                        event_types.append("body-unavailable")
                body = page.locator("body").inner_text(timeout=7000)[-520:]
                token_present = page.evaluate("Boolean(localStorage.getItem('lyo_token'))")
                print(
                    "DIAGNOSTIC Chat Coach card missing:"
                    f" response_statuses={[r.status for r in chat_responses]}"
                    f" SSE_types={event_types[:25]!r}"
                    f" token_present={token_present}"
                    f" url={page.url!r} visible_text={body!r}"
                    f" JS_errors={failures[-6:]!r}", flush=True
                )
                raise
            print("PASS Chat displays live structured Coach mission", flush=True)

            if os.getenv("LYO_ONE_TEST_PREP_PROVIDER_READY") == "yes":
                validate_planned_session_returns(page, token)

            assert verify_deployed_pair() == before, "The deployed pair changed during browser validation"
            print("PASS exact staging revisions remained stable through browser validation", flush=True)

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
