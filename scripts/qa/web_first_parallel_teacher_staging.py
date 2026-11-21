#!/usr/bin/env python3
"""Authenticated staging-only parallel Classroom bridge/scene smoke.

One disposable learner; never writes real grades. Reports only latency and
event shape, never tokens, learner text, model output or provider credentials.
"""
import asyncio
import json
import os
import secrets
import sys
import time
from urllib.parse import urlencode, urlsplit
import websockets

import web_first_live_classroom_auth as qa

API = os.environ.get("LYO_BRIDGE_STAGING_API", qa.API).rstrip("/")
assert (urlsplit(API).hostname or "").endswith("-staging.up.railway.app")
qa.API = API  # Reuse existing synthetic-registration/cleanup helper at target.
http = qa.http


def envelope(event):
    if not isinstance(event, dict):
        return "", {}
    payload = event.get("data") if isinstance(event.get("data"), dict) else {}
    kind = str(event.get("event_type") or event.get("type")
               or payload.get("event_type") or "").lower()
    return kind, payload


async def run():
    nonce = secrets.token_hex(11)
    password = "LyoQA-" + secrets.token_hex(16) + "aA9!"
    user = {
        "email": "lyo-bridge-qa-" + nonce + "@example.org",
        "username": "bridgeqa" + nonce[:19],
        "password": password,
        "confirm_password": password,
        "first_name": "Staging",
        "last_name": "Bridge",
    }
    token, created, success = None, False, False
    try:
        status, registered = http("POST", "/api/v1/auth/register", user)
        if status not in (200, 201):
            raise RuntimeError("synthetic registration failed: " + str(status))
        created = True
        token = registered.get("access_token")
        if not token:
            code, data = http("POST", "/api/v1/auth/login",
                              {"email": user["email"], "password": password})
            if code != 200 or not data.get("access_token"):
                raise RuntimeError("synthetic login failed")
            token = data["access_token"]
        code, me = http("GET", "/api/v1/auth/me", token=token)
        if code != 200 or not me.get("id"):
            raise RuntimeError("synthetic learner identity invalid")
        code, data = http("POST", "/api/v1/classroom/session", {
            "preferences": {"language": "en-US", "difficulty": "intermediate"}
        }, token=token)
        if code != 200 or not data.get("session_id"):
            raise RuntimeError("Classroom synthetic session failed")
        seat = str(data["session_id"])
        params = {
            "token": token,
            "session_id": seat,
            "topic": "Fractions and equivalent rational expressions",
            "mode": "solo",
            "duration_minutes": "5",
            "language": "en-US",
            "client_contract_version": "2",
            "continuous_teaching": "1",
            "bridge_language": "en-US",
        }
        url = API.replace("https://", "wss://") + "/api/v1/classroom/ws/connect?" + urlencode(params)
        assert (urlsplit(url).hostname or "").endswith("-staging.up.railway.app")
        async with websockets.connect(url, open_timeout=20, close_timeout=5,
                                      max_size=5_000_000, ping_interval=20) as ws:
            connected = time.monotonic()
            startup_ms, scene_ms, generation = None, None, None
            followup = False
            first_scene = None
            # The quick teacher should open before authoritative lesson generation.
            async def receive_until_scene():
                nonlocal startup_ms, scene_ms, generation, followup, first_scene
                async for raw in ws:
                    kind, payload = envelope(json.loads(raw))
                    if kind == "bridge_message":
                        if payload.get("phase") == "startup" and startup_ms is None:
                            assert payload.get("ungraded") is True
                            assert payload.get("ai_generated") is False
                            assert payload.get("prompt") is True
                            generation = payload.get("generation")
                            startup_ms = round((time.monotonic() - connected) * 1000)
                            await ws.send(json.dumps({
                                "event_type": "bridge_reply", "session_id": seat,
                                "generation": generation,
                                "text": "Fractions represent parts of a whole.",
                            }))
                        elif payload.get("phase") == "startup":
                            assert payload.get("ungraded") is True
                            followup = True
                    elif kind in {"scene_start", "scene_stream"}:
                        scene = payload.get("scene") or {}
                        if not scene and kind == "scene_start":
                            scene = (json.loads(raw)).get("scene") or {}
                        if isinstance(scene, dict) and scene.get("scene_id"):
                            first_scene = str(scene["scene_id"])
                            scene_ms = round((time.monotonic() - connected) * 1000)
                            return
                    elif kind == "error":
                        raise RuntimeError("Classroom returned startup error")
            await asyncio.wait_for(receive_until_scene(), timeout=120)
            if startup_ms is None:
                raise RuntimeError("Parallel startup bridge absent despite client opt-in")
            if scene_ms is None or startup_ms >= scene_ms:
                raise RuntimeError("Parallel bridge did not precede authoritative scene")
            if startup_ms > 4000:
                raise RuntimeError("Bridge startup first prompt exceeded 4000ms: "
                                   + str(startup_ms))
            print("PASS: ungraded parallel startup prompt in " + str(startup_ms)
                  + "ms; first scene in " + str(scene_ms)
                  + "ms; optional followup_observed=" + str(followup), flush=True)

            # Continue is a single authoritative lesson action; bridge transport
            # must stay open for replies while it is prepared asynchronously.
            await ws.send(json.dumps({
                "event_type": "user_action", "session_id": seat,
                "action_intent": "continue",
            }))
            sent = time.monotonic()
            async def await_transition():
                async for raw in ws:
                    kind, payload = envelope(json.loads(raw))
                    if kind == "bridge_message" and payload.get("phase") == "transition":
                        if payload.get("ungraded") is not True:
                            raise RuntimeError("Transition bridge was not ungraded")
                        return round((time.monotonic() - sent) * 1000)
                    if kind == "error":
                        raise RuntimeError("Classroom returned transition error")
                raise RuntimeError("Socket closed before transition prompt")
            transition_ms = await asyncio.wait_for(await_transition(), timeout=15)
            if transition_ms > 4000:
                raise RuntimeError("Transition quick prompt exceeded 4000ms: "
                                   + str(transition_ms))
            print("PASS: ungraded transition prompt in " + str(transition_ms)
                  + "ms; no duplicate learner action submitted", flush=True)
        success = True
    except Exception as exc:
        print("BRIDGE QA FAIL: " + type(exc).__name__ + ": "
              + str(exc).split("wss://")[0][:170], file=sys.stderr, flush=True)
    finally:
        if created and token:
            try:
                code, deleted = http("DELETE", "/auth/me", token=token)
                if code == 200 and deleted.get("deleted") is True:
                    print("PASS: disposable bridge learner deleted", flush=True)
                else:
                    success = False
                    print("BRIDGE QA CLEANUP FAILED", file=sys.stderr)
            except Exception:
                success = False
                print("BRIDGE QA CLEANUP FAILED", file=sys.stderr)
        elif created:
            success = False
            print("BRIDGE QA CLEANUP BLOCKED", file=sys.stderr)
    return 0 if success else 1


if __name__ == "__main__":
    raise SystemExit(asyncio.run(run()))
