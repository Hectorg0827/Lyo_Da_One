#!/usr/bin/env python3
"""Isolated synthetic-user Classroom acceptance on the Railway STAGING API.

One random learner, HTTP auth, Classroom session, first scene, forced disconnect,
same persisted scene resume, then DELETE only that synthetic account.
No actual user data, secrets in output or production endpoints.
"""
import asyncio
import json
import secrets
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import websockets

API = "https://lyojourneystagingbackend-staging.up.railway.app"
assert urllib.parse.urlparse(API).hostname.endswith("-staging.up.railway.app")

def http(method, path, body=None, token=None, timeout=30):
    url = API + path
    if not url.startswith(API + "/"):
        raise RuntimeError("Non-staging URL forbidden")
    encoded = json.dumps(body).encode("utf-8") if body is not None else None
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    request = urllib.request.Request(url, data=encoded, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as result:
            payload = result.read()
            return result.status, json.loads(payload) if payload else {}
    except urllib.error.HTTPError as exc:
        return exc.code, {}

def ws_url(session_id, token, resume=False):
    params = {
        "session_id": session_id,
        "topic": "Fractions",
        "mode": "solo",
        "duration_minutes": "3",
        "language": "en-US",
        "client_contract_version": "2",
        "token": token,
    }
    if resume:
        params["resume"] = "1"
    result = API.replace("https://", "wss://") + "/api/v1/classroom/ws/connect?" + urllib.parse.urlencode(params)
    assert urllib.parse.urlparse(result).hostname.endswith("-staging.up.railway.app")
    return result

async def receive_scene(session_id, token, resume=False):
    # Never emit the signed WebSocket URL to a log: it includes a bearer token.
    start = time.monotonic()
    async with websockets.connect(
        ws_url(session_id, token, resume),
        open_timeout=20, close_timeout=5, max_size=5_000_000,
        ping_interval=20, ping_timeout=20,
    ) as ws:
        async def wait():
            async for raw in ws:
                try:
                    event = json.loads(raw)
                except Exception:
                    continue
                if not isinstance(event, dict):
                    continue
                nested = event.get("data") or {}
                if not isinstance(nested, dict):
                    nested = {}
                kind = str(nested.get("event_type") or event.get("event_type") or event.get("type") or "").upper()
                if kind == "ERROR":
                    raise RuntimeError("Classroom returned an error event")
                scene = nested.get("scene") or event.get("scene")
                if isinstance(scene, dict) and scene.get("scene_id"):
                    return str(scene["scene_id"])
            raise RuntimeError("WebSocket closed without a Classroom scene")
        scene_id = await asyncio.wait_for(wait(), timeout=95)
        return scene_id, round((time.monotonic() - start) * 1000)

async def main():
    nonce = secrets.token_hex(12)
    password = "LyoQA-" + secrets.token_hex(18) + "aA9!"
    payload = {
        "email": "lyo-qa-" + nonce + "@example.org",
        "username": "qa" + nonce[:22],
        "password": password,
        "confirm_password": password,
        "first_name": "Staging",
        "last_name": "QA",
    }
    token = None
    created = False
    success = False
    try:
        print("QA: registering synthetic learner on staging")
        status, registration = http("POST", "/api/v1/auth/register", payload)
        # Some staging deployments expose the lightweight registration alias:
        # 200 {user_id, message}; the enhanced auth service returns 201 + JWT.
        # Accept either contract, then authenticate with the supported login
        # endpoint instead of treating a created account as a failed signup.
        if status not in (200, 201):
            raise RuntimeError("Registration HTTP " + str(status))
        created = True
        token = registration.get("access_token")
        print("PASS: registration HTTP " + str(status))
        if not token:
            login_status, login = http("POST", "/api/v1/auth/login",
                                       {"email": payload["email"], "password": password})
            if login_status != 200:
                raise RuntimeError("Login after registration HTTP " + str(login_status))
            token = login.get("access_token")
            if not token:
                raise RuntimeError("Login returned no access token")
            print("PASS: login yielded access token (not printed)")

        status, account = http("GET", "/api/v1/auth/me", token=token)
        if status != 200 or not account.get("id"):
            raise RuntimeError("Authenticated /me HTTP " + str(status))
        print("PASS: authenticated profile 200")

        status, lesson = http("POST", "/api/v1/classroom/session",
                              {"preferences": {"language": "en-US", "difficulty": "beginner"}},
                              token=token)
        if status != 200 or not lesson.get("session_id"):
            raise RuntimeError("Classroom session HTTP " + str(status))
        session_id = str(lesson["session_id"])
        print("PASS: Classroom session created")

        initial_id, initial_ms = await receive_scene(session_id, token, False)
        print("PASS: actual Classroom scene, ms=" + str(initial_ms))
        resumed_id, resume_ms = await receive_scene(session_id, token, True)
        if resumed_id != initial_id:
            raise RuntimeError("Resume returned a different scene ID instead of persisted state")
        print("PASS: persisted Classroom scene restored, ms=" + str(resume_ms))
        success = True
    except Exception as exc:
        # Do not log the signed query string, email or password.
        print("QA FAIL: " + type(exc).__name__ + ": " + str(exc).split("wss://")[0][:180], file=sys.stderr)
    finally:
        if created and token:
            try:
                # Enhanced auth routes are mounted at /auth, distinct from
                # the legacy /api/v1/auth GET-only alias.
                status, response = http("DELETE", "/auth/me", token=token)
                if status == 200 and response.get("deleted") is True:
                    print("QA cleanup: synthetic learner deleted")
                else:
                    print("QA CLEANUP FAILURE: account deletion HTTP " + str(status), file=sys.stderr)
                    success = False
            except Exception as exc:
                print("QA CLEANUP FAILURE: " + type(exc).__name__, file=sys.stderr)
                success = False
        elif created:
            print("QA CLEANUP BLOCKED: account created but token missing", file=sys.stderr)
            success = False
    return 0 if success else 1

if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
