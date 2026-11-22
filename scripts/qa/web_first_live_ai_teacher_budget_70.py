#!/usr/bin/env python3
"""Single bounded real provider-authored AI Teacher acceptance on Railway staging.

One disposable algebra learner, <=2 authoritative actions, no production, no
text/prompts/tokens/credentials in stdout, no simulated provider responses.
Budget guard is maintained by the backend's *existing* cumulative Redis key.
"""
import asyncio
import json
import secrets
import sys
import time
from urllib.parse import urlencode, urlsplit

import websockets
import web_first_live_classroom_auth as qa


API = qa.API
assert (urlsplit(API).hostname or "").endswith("-staging.up.railway.app")


def event_parts(raw):
    obj = json.loads(raw)
    if not isinstance(obj, dict):
        return "", {}, {}
    data = obj.get("data") if isinstance(obj.get("data"), dict) else {}
    event_type = str(obj.get("event_type") or obj.get("type")
                     or data.get("event_type") or "").lower()
    return event_type, data, obj


def take_scene(payload, obj):
    scene = payload.get("scene") or obj.get("scene") or {}
    if not isinstance(scene, dict) or not scene.get("scene_id"):
        return None
    metadata = scene.get("metadata") or {}
    source = metadata.get("scene_source") if isinstance(metadata, dict) else None
    components = scene.get("components")
    types = [str(c.get("type", "")) for c in components if isinstance(c, dict)] if isinstance(components, list) else []
    return {
        "id": str(scene["scene_id"]),
        "source": str(source or "unattributed"),
        "components": types,
    }


async def main():
    nonce = secrets.token_hex(11)
    password = "LyoQA-" + secrets.token_hex(16) + "aA9!"
    person = {
        "email": "lyo-live-teacher-" + nonce + "@example.org",
        "username": "liveteacher" + nonce[:15],
        "password": password, "confirm_password": password,
        "first_name": "Staging", "last_name": "Teacher",
    }
    created = False
    token = None
    success = False
    try:
        for attempt in range(3):
            code, registration = qa.http("POST", "/api/v1/auth/register", person)
            if code in (200, 201):
                created = True
                break
            if code != 429 or attempt == 2:
                raise RuntimeError("synthetic registration failed HTTP " + str(code))
            print("Staging registration throttled; respecting 65s backoff", flush=True)
            await asyncio.sleep(65)
        token = registration.get("access_token")
        if not token:
            code, login = qa.http("POST", "/api/v1/auth/login",
                {"email": person["email"], "password": password})
            if code != 200 or not login.get("access_token"):
                raise RuntimeError("staging login failed")
            token = login["access_token"]
        code, me = qa.http("GET", "/api/v1/auth/me", token=token)
        if code != 200 or not me.get("id"):
            raise RuntimeError("staging learner identity failed")
        code, session = qa.http("POST", "/api/v1/classroom/session",
            {"preferences": {"language": "en-US", "difficulty": "intermediate"}},
            token=token)
        if code != 200 or not session.get("session_id"):
            raise RuntimeError("staging Classroom session creation failed")
        seat = str(session["session_id"])
        params = {
            "token": token, "session_id": seat,
            "topic": "Intermediate algebra: solve 3x + 5 = 20",
            "mode": "solo", "duration_minutes": "5",
            "language": "en-US", "client_contract_version": "2",
            "continuous_teaching": "1",
        }
        url = API.replace("https://", "wss://") + "/api/v1/classroom/ws/connect?" + urlencode(params)
        assert urlsplit(url).hostname.endswith("-staging.up.railway.app")
        async with websockets.connect(url, open_timeout=20, close_timeout=6,
                                      ping_interval=20, ping_timeout=30,
                                      max_size=5_000_000) as socket:
            started = time.monotonic()
            scenes = []
            bridge_prompt = False
            bridge_ai = False
            provider_authored = False
            next_sent = False
            deadline = started + 110
            while time.monotonic() < deadline:
                raw = await asyncio.wait_for(socket.recv(),
                                              timeout=min(25, max(0.1, deadline-time.monotonic())))
                kind, data, obj = event_parts(raw)
                if kind == "error":
                    raise RuntimeError("Classroom returned error event")
                if kind == "bridge_message":
                    bridge_prompt = True
                    bridge_ai = bridge_ai or data.get("ai_generated") is True
                if kind in {"scene_start", "scene_stream"}:
                    scene = take_scene(data, obj)
                    if scene and (not scenes or scene["id"] != scenes[-1]["id"]):
                        scenes.append(scene)
                        source = scene["source"]
                        if source == "ai_generated":
                            provider_authored = True
                        print("SCENE: source=" + source
                              + " components=" + ",".join(scene["components"])
                              + " first_ms=" + str(round((time.monotonic()-started)*1000)),
                              flush=True)
                        if not next_sent and source == "ai_generated":
                            # One bounded authoritative action only; never
                            # submit student answers or fabricated grades.
                            await socket.send(json.dumps({
                                "event_type": "user_action", "session_id": seat,
                                "action_intent": "continue",
                            }))
                            next_sent = True
                        if provider_authored and len(scenes) >= 2:
                            break
                if kind in {"scene_complete","scene_end"} and provider_authored and next_sent:
                    # Observe a bounded follow-up window for another scene.
                    if len(scenes) >= 2:
                        break
            print("TEACHER RESULT: scene_count=" + str(len(scenes))
                  + " authentic_model_scene=" + str(provider_authored)
                  + " quick_bridge=" + str(bridge_prompt)
                  + " bridge_ai_generated=" + str(bridge_ai), flush=True)
            if not provider_authored:
                raise RuntimeError("no genuinely provider-authored teaching scene")
            if not next_sent or len(scenes) < 2:
                raise RuntimeError("no authoritative follow-up scene after one Continue")
        print("PASS: provider-authored algebra teaching and one controlled transition",
              flush=True)
        success = True
    except Exception as exc:
        # Never print URLs or response bodies; they may contain bearer tokens.
        print("LIVE TEACHER FAIL: " + type(exc).__name__
              + ": " + str(exc).split("wss://")[0][:130],
              file=sys.stderr, flush=True)
    finally:
        if created:
            if not token:
                success = False
                print("FAIL: synthetic learner cleanup token unavailable", file=sys.stderr)
            else:
                # A fresh token may be required after a slow provider attempt.
                code, login = qa.http("POST", "/api/v1/auth/login",
                    {"email": person["email"], "password": password})
                cleanup_token = login.get("access_token") if code == 200 else token
                for retry in range(3):
                    code, deleted = qa.http("DELETE", "/auth/me", token=cleanup_token)
                    if code == 200 and deleted.get("deleted") is True:
                        print("PASS: synthetic teacher learner deleted", flush=True)
                        break
                    if code != 429 or retry == 2:
                        success = False
                        print("FAIL: synthetic teacher learner cleanup requires reconciliation",
                              file=sys.stderr, flush=True)
                        break
                    await asyncio.sleep(65)
    return 0 if success else 1


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
