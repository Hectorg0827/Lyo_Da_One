#!/usr/bin/env python3
"""Live 30-minute Classroom transport acceptance on isolated Railway staging.

One ephemeral synthetic student. Test login -> course session -> real teaching
scene -> persistence -> 60s of heartbeat -> forced network disconnect ->
rejoin the same scene -> ~29 minutes of heartbeat. Delete student afterward.
No token, email, password, or personal content ever appears in logs.
"""
import asyncio
import json
import secrets
import sys
import time
import urllib.parse

import websockets

from live_classroom_auth import http, receive_scene, ws_url

def long_ws_url(session_id, token):
    raw = ws_url(session_id, token, resume=True)
    u = urllib.parse.urlsplit(raw)
    params = urllib.parse.parse_qs(u.query)
    params["duration_minutes"] = ["30"]
    params["resume"] = ["1"]
    return urllib.parse.urlunsplit((u.scheme, u.netloc, u.path, urllib.parse.urlencode(params, doseq=True), ""))

async def segment(session_id, token, expected_scene, seconds, label):
    started = time.monotonic()
    heartbeats = 0
    seen_scene = False
    async with websockets.connect(long_ws_url(session_id, token), open_timeout=20, close_timeout=5,
                                  ping_interval=20, ping_timeout=30, max_size=5_000_000) as socket:
        deadline = started + seconds
        next_progress = started + 300
        while time.monotonic() < deadline:
            remaining = deadline - time.monotonic()
            try:
                msg = await asyncio.wait_for(socket.recv(), timeout=min(30, remaining + 1))
            except asyncio.TimeoutError:
                if time.monotonic() >= deadline:
                    break
                raise RuntimeError("Classroom heartbeat absent >30s")
            try:
                event = json.loads(msg)
            except Exception:
                continue
            if not isinstance(event, dict):
                continue
            data = event.get("data") or {}
            if not isinstance(data, dict):
                data = {}
            scene = data.get("scene") or event.get("scene")
            if isinstance(scene, dict) and scene.get("scene_id"):
                scene_id = str(scene["scene_id"])
                if scene_id != expected_scene:
                    raise RuntimeError("Classroom generated a different scene while rejoining")
                seen_scene = True
            if data.get("heartbeat") is True:
                heartbeats += 1
            event_type = str(data.get("event_type") or event.get("event_type") or "")
            if event_type.upper() == "ERROR":
                raise RuntimeError("Classroom server returned an error event")
            if time.monotonic() >= next_progress:
                print(label + ": elapsed=" + str(round(time.monotonic()-started)) +
                      "s, heartbeats=" + str(heartbeats), flush=True)
                next_progress += 300
        duration = round(time.monotonic() - started)
        if not seen_scene:
            raise RuntimeError("Scene was never restored in " + label)
        expected_min = max(1, int(seconds // 20) - 2)
        if heartbeats < expected_min:
            raise RuntimeError(label + " missing heartbeats, observed=" + str(heartbeats) +
                               ", required=" + str(expected_min))
        print("PASS " + label + ": duration_s=" + str(duration) + ", heartbeats=" + str(heartbeats))
    return heartbeats

async def main():
    random = secrets.token_hex(12)
    password = "LyoQA-" + secrets.token_hex(18) + "aA9!"
    user = {
        "email": "lyo-qa-" + random + "@example.org",
        "username": "qa" + random[:22],
        "password": password,
        "confirm_password": password,
        "first_name": "Staging",
        "last_name": "QA"
    }
    token = None
    created = False
    success = False
    try:
        code, registration = http("POST", "/api/v1/auth/register", user)
        if code not in (200, 201):
            raise RuntimeError("Registration failed with HTTP " + str(code))
        created = True
        token = registration.get("access_token")
        if not token:
            code, login = http("POST", "/api/v1/auth/login", {"email": user["email"], "password": password})
            if code != 200 or not login.get("access_token"):
                raise RuntimeError("Login after registration failed, HTTP " + str(code))
            token = login["access_token"]
        code, profile = http("GET", "/api/v1/auth/me", token=token)
        if code != 200 or not profile.get("id"):
            raise RuntimeError("Authenticated identity failed")
        code, session = http("POST", "/api/v1/classroom/session", {"preferences":{"language":"en-US"}},
                             token=token)
        if code != 200 or not session.get("session_id"):
            raise RuntimeError("Classroom session creation failed")
        session_id = str(session["session_id"])
        print("PASS staging auth and Classroom session", flush=True)
        scene_id, first_ms = await receive_scene(session_id, token, resume=False)
        print("PASS first AI Classroom scene, ms=" + str(first_ms), flush=True)
        resumed_id, recovered_ms = await receive_scene(session_id, token, resume=True)
        if resumed_id != scene_id:
            raise RuntimeError("Initial saved-scene resume failed")
        print("PASS saved-scene resume, ms=" + str(recovered_ms), flush=True)

        a = await segment(session_id, token, scene_id, 60, "before forced disconnect")
        print("QA induced transport disconnect; reconnecting same session with resume=1", flush=True)
        b = await segment(session_id, token, scene_id, 1740, "after forced disconnect")
        print("PASS 30-minute Classroom transport acceptance; total heartbeats=" + str(a+b))
        success = True
    except Exception as exc:
        # Avoid leaking WebSocket URLs and bearer tokens in error output.
        print("QA FAIL: " + type(exc).__name__ + " (details redacted)", file=sys.stderr)
    finally:
        if created and token:
            try:
                # Reauthenticate before cleanup; the original JWT may have expired.
                login_code, login = http("POST", "/api/v1/auth/login",
                                         {"email": user["email"], "password": password})
                cleanup_token = login.get("access_token") if login_code == 200 else None
                if not cleanup_token:
                    raise RuntimeError("Synthetic learner cleanup reauthentication failed")
                code, result = http("DELETE", "/auth/me", token=cleanup_token)
                if code == 200 and result.get("deleted") is True:
                    print("QA cleanup: synthetic learner permanently deleted")
                else:
                    success = False
                    print("QA CLEANUP FAIL: HTTP " + str(code), file=sys.stderr)
            except Exception:
                success = False
                print("QA CLEANUP FAIL: exception", file=sys.stderr)
        elif created:
            success = False
            print("QA CLEANUP BLOCKED: no token", file=sys.stderr)
    return 0 if success else 1

if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
