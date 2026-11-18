#!/usr/bin/env python3
"""LYO Continuous Teaching preview bench: only explicitly named Railway preview hosts.

Records first local teacher bridge text, first AI follow-up, first scene frame,
scene_complete (when emitted), transition bridge and next scene; optional TTS
first audio bytes measured separately. No real learner accounts, tokens, URLs
with credentials, question bodies or scene text in artifacts.
"""
import asyncio
import json
import os
import secrets
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

import websockets

API = "https://lyo-continuousteaching-preview-backend-staging.up.railway.app"
WEB = "https://lyo-continuousteaching-preview-web-staging.up.railway.app"
assert urllib.parse.urlparse(API).hostname == "lyo-continuousteaching-preview-backend-staging.up.railway.app"
assert urllib.parse.urlparse(WEB).hostname == "lyo-continuousteaching-preview-web-staging.up.railway.app"
ARTIFACT = Path("artifacts/teacher-quality/continuous-teaching-preview.json")
ARTIFACT.parent.mkdir(parents=True, exist_ok=True)


class StrictRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if urllib.parse.urlparse(newurl).hostname != urllib.parse.urlparse(API).hostname:
            raise RuntimeError("Preview API request attempted non-preview redirect")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


OPENER = urllib.request.build_opener(StrictRedirect)


def http(method, path, body=None, token=None, timeout=30):
    if not path.startswith("/") or "//" in path:
        raise RuntimeError("Invalid preview-only request path")
    data = json.dumps(body).encode("utf-8") if body is not None else None
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(API + path, data=data, headers=headers, method=method)
    try:
        with OPENER.open(req, timeout=timeout) as response:
            raw = response.read(100_000)
            return response.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        return exc.code, {}


def session_url(sid, token):
    query = urllib.parse.urlencode({
        "session_id": sid, "topic": "Fractions", "mode": "solo",
        "duration_minutes": "5", "language": "en-US",
        "client_contract_version": "2", "continuous_teaching": "1",
        "bridge_language": "en-US", "token": token,
    })
    return "wss://" + urllib.parse.urlparse(API).hostname + "/api/v1/classroom/ws/connect?" + query


async def benchmark_ws(sid, token):
    metrics = {
        "first_teacher_text_ms": None,
        "first_ai_bridge_reply_ms": None,
        "first_scene_frame_ms": None,
        "scene_complete_ms": None,
        "transition_bridge_text_ms": None,
        "transition_next_scene_ms": None,
        "handoff_correct": False,
        "bridge_reply_ungraded": False,
        "first_scene_kind": None,
        "first_scene_component_count": None,
        "transition_scene_component_count": None,
        "transition_bridge_ai_reply_ms": None,
        "first_scene_id_seen": False,
        "transport_errors": 0,
        "teacher_text_origin": "local immediate ungraded bridge",
        "timing_origin": "direct authenticated preview backend WebSocket",
    }
    start = time.monotonic()
    initial_sid = None
    transition_at = None
    start_bridged = False
    transition_bridged = False
    first_ai_sent = None
    transition_ai_sent = None
    sent_continue = False
    async with websockets.connect(
        session_url(sid, token), open_timeout=20, close_timeout=5,
        max_size=5_000_000, ping_interval=20, ping_timeout=20,
    ) as socket:
        deadline = start + 135
        while time.monotonic() < deadline:
            try:
                raw = await asyncio.wait_for(socket.recv(), timeout=min(15, max(0.5, deadline - time.monotonic())))
            except asyncio.TimeoutError:
                continue
            except websockets.exceptions.ConnectionClosed:
                metrics["transport_errors"] += 1
                break
            if not isinstance(raw, str):
                continue
            try:
                event = json.loads(raw)
            except ValueError:
                continue
            if not isinstance(event, dict):
                continue
            info = event.get("data") or {}
            if not isinstance(info, dict):
                info = {}
            kind = str(info.get("event_type") or event.get("event_type") or event.get("type") or "").lower()
            now = time.monotonic()
            if kind == "bridge_message":
                if info.get("ungraded") is not True:
                    raise RuntimeError("Bridge response is not explicitly ungraded")
                phase = info.get("phase")
                generation = info.get("generation")
                if phase == "startup" and metrics["first_teacher_text_ms"] is None:
                    metrics["first_teacher_text_ms"] = round((now-start)*1000)
                    metrics["bridge_reply_ungraded"] = True
                    if info.get("prompt") is True and not start_bridged:
                        start_bridged = True
                        first_ai_sent = time.monotonic()
                        await socket.send(json.dumps({
                            "event_type": "bridge_reply", "session_id": sid,
                            "generation": generation,
                            "text": "I notice that two quarters equal one half.",
                        }))
                elif phase == "startup" and info.get("ai_generated") is True and first_ai_sent is not None:
                    metrics["first_ai_bridge_reply_ms"] = round((now-first_ai_sent)*1000)
                elif phase == "transition" and metrics["transition_bridge_text_ms"] is None and transition_at is not None:
                    metrics["transition_bridge_text_ms"] = round((now-transition_at)*1000)
                    transition_bridged = True
                    if info.get("prompt") is True:
                        transition_ai_sent = time.monotonic()
                        await socket.send(json.dumps({
                            "event_type": "bridge_reply", "session_id": sid,
                            "generation": generation,
                            "text": "I want to see how this pattern works with thirds.",
                        }))
                elif phase == "transition" and info.get("ai_generated") is True and transition_ai_sent is not None:
                    metrics["transition_bridge_ai_reply_ms"] = round((now-transition_ai_sent)*1000)
            if kind in {"error", "ERROR"}:
                metrics["transport_errors"] += 1
            scene = info.get("scene") or event.get("scene") or {}
            if isinstance(scene, dict) and scene.get("scene_id") and kind in {
                "scene_start", "scene_stream", "scene_update"
            }:
                scene_id = str(scene["scene_id"])
                if initial_sid is None:
                    initial_sid = scene_id
                    metrics["first_scene_frame_ms"] = round((now-start)*1000)
                    metrics["first_scene_id_seen"] = True
                    metrics["first_scene_kind"] = kind
                    metrics["first_scene_component_count"] = len(scene.get("components") or [])
                elif transition_at is not None and scene_id != initial_sid:
                    metrics["transition_next_scene_ms"] = round((now-transition_at)*1000)
                    metrics["transition_scene_component_count"] = len(scene.get("components") or [])
                    metrics["handoff_correct"] = transition_bridged
                    break
            if kind in {"scene_complete", "scene_end"} and initial_sid is not None:
                if metrics["scene_complete_ms"] is None:
                    metrics["scene_complete_ms"] = round((now-start)*1000)
                    if not sent_continue:
                        sent_continue = True
                        # Do not race Continue ahead of completion of the
                        # prior authoritative scene; simulate the user moving on.
                        await asyncio.sleep(0.2)
                        transition_at = time.monotonic()
                        await socket.send(json.dumps({
                            "event_type": "user_action", "session_id": sid,
                            "action_intent": "continue",
                        }))
    return metrics


def first_audio_bytes(token):
    """Transport first MP3 bytes, NOT a claim that browser playback was audible."""
    payload = {
        "text": "Let's explore fractions. What do you already know?",
        "voice": "nova", "format": "mp3", "speed": 1,
        "language": "en-US", "content_type": "explanation",
    }
    req = urllib.request.Request(
        API + "/api/v1/tts/synthesize/stream",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "Authorization": "Bearer " + token},
        method="POST",
    )
    begin = time.monotonic()
    try:
        with OPENER.open(req, timeout=80) as response:
            chunk = response.read(128)
            return {
                "status": response.status,
                "first_audio_byte_ms": round((time.monotonic()-begin)*1000) if chunk else None,
                "content_type": response.headers.get("Content-Type", "").split(";")[0][:50],
                "note": "server TTS first bytes, not first audible browser playback",
            }
    except urllib.error.HTTPError as exc:
        return {"status": exc.code, "first_audio_byte_ms": None}
    except Exception:
        return {"status": None, "first_audio_byte_ms": None, "error": "transport_timeout_or_failure"}


async def main():
    marker = secrets.token_hex(12)
    password = "LyoQa-" + secrets.token_hex(18) + "A9!"
    person = {
        "email": "lyo-ct-qa-" + marker + "@example.org",
        "username": "ctqa" + marker[:20],
        "password": password, "confirm_password": password,
        "first_name": "Preview", "last_name": "QA",
    }
    token = None
    created = False
    result = {
        "revision": "backend:d59488194d6c; web:2f20179fa5ed",
        "preview_only": True,
        "synthetic_account_deleted": False,
        "ws": {},
        "tts": {},
    }
    exit_code = 1
    try:
        print("Preview HTTP/auth and direct WebSocket benchmark", flush=True)
        status, registration = http("POST", "/api/v1/auth/register", person)
        if status not in (200, 201):
            raise RuntimeError(f"preview registration failed: HTTP {status}")
        created = True
        token = registration.get("access_token")
        if not token:
            status, data = http("POST", "/api/v1/auth/login", {
                "email": person["email"], "password": password,
            })
            if status != 200:
                raise RuntimeError(f"preview login failed: HTTP {status}")
            token = data.get("access_token")
        if not token:
            raise RuntimeError("preview login returned no token")
        status, me = http("GET", "/api/v1/auth/me", token=token)
        if status != 200 or not me.get("id"):
            raise RuntimeError(f"preview /me failed: HTTP {status}")
        status, session = http("POST", "/api/v1/classroom/session",
                              {"preferences":{"language":"en-US","difficulty":"beginner"}},
                              token=token)
        if status != 200 or not session.get("session_id"):
            raise RuntimeError(f"preview session failed: HTTP {status}")
        result["ws"] = await benchmark_ws(str(session["session_id"]), token)
        print("Preview WS metrics: " + json.dumps(result["ws"], sort_keys=True), flush=True)
        result["tts"] = await asyncio.to_thread(first_audio_bytes, token)
        print("Preview TTS transport: " + json.dumps(result["tts"], sort_keys=True), flush=True)
        exit_code = 0
    except Exception as exc:
        # Do not log token, username, email, payloads, provider bodies or URLs.
        result["error_type"] = type(exc).__name__
        result["error_category"] = str(exc).split(":")[0][:45] if isinstance(exc, RuntimeError) else "runtime"
        print("Preview QA failure category: " + result["error_type"], file=sys.stderr)
    finally:
        if created and token:
            try:
                status, reply = http("DELETE", "/auth/me", token=token, timeout=20)
                result["synthetic_account_deleted"] = status == 200 and reply.get("deleted") is True
            except Exception:
                pass
        if not result["synthetic_account_deleted"]:
            if created:
                print("Synthetic preview-account cleanup not confirmed.", file=sys.stderr)
            exit_code = 1
        ARTIFACT.write_text(json.dumps(result, indent=2, sort_keys=True))
    return exit_code


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
