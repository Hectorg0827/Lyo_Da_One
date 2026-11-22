#!/usr/bin/env python3
"""One real graded algebra-question probe with disposable staging credentials.

Tests authoritative model teaching -> QuizCard -> exactly one submitted answer
-> feedback scene. Never logs question, answer, learner text, bearer URL or
provider output. Never mutates production or bypasses Redis trial accounting.
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
    event = json.loads(raw)
    if not isinstance(event, dict):
        return "", {}, {}
    nested = event.get("data") if isinstance(event.get("data"), dict) else {}
    kind = str(event.get("event_type") or event.get("type")
               or nested.get("event_type") or "").lower()
    return kind, nested, event


def scene_of(nested, event):
    candidate = nested.get("scene") or event.get("scene")
    return candidate if isinstance(candidate, dict) and candidate.get("scene_id") else None


def inspect_scene(scene):
    metadata = scene.get("metadata") if isinstance(scene.get("metadata"), dict) else {}
    source = str(metadata.get("scene_source") or "unattributed")
    components = scene.get("components") if isinstance(scene.get("components"), list) else []
    quiz = next((x for x in components if isinstance(x, dict)
                 and x.get("type") == "QuizCard" and x.get("options")), None)
    has_recovery = any(isinstance(x, dict)
                       and x.get("presentation_role") == "recovery" for x in components)
    has_feedback = any(isinstance(x, dict)
                       and x.get("presentation_role") == "feedback" for x in components)
    return source, quiz, has_recovery, has_feedback, len(components)


async def run():
    nonce = secrets.token_hex(11)
    password = "LyoQA-" + secrets.token_hex(17) + "aA9!"
    user = {
        "email": "lyo-grade-qa-" + nonce + "@example.org",
        "username": "gradeqa" + nonce[:18],
        "password": password, "confirm_password": password,
        "first_name": "Staging", "last_name": "Grader",
    }
    created, token, success = False, None, False
    try:
        for attempt in range(3):
            status, registration = qa.http("POST", "/api/v1/auth/register", user)
            if status in (200, 201):
                created = True
                break
            if status != 429 or attempt == 2:
                raise RuntimeError("synthetic registration rejected HTTP " + str(status))
            print("Staging registration rate-limited; bounded 65s backoff", flush=True)
            await asyncio.sleep(65)
        token = registration.get("access_token")
        if not token:
            status, login = qa.http("POST", "/api/v1/auth/login",
                                    {"email": user["email"], "password": password})
            if status != 200 or not login.get("access_token"):
                raise RuntimeError("synthetic QA login failed")
            token = login["access_token"]
        status, identity = qa.http("GET", "/api/v1/auth/me", token=token)
        if status != 200 or not identity.get("id"):
            raise RuntimeError("synthetic QA authentication failed")
        status, seat_data = qa.http("POST", "/api/v1/classroom/session",
             {"preferences": {"language": "en-US", "difficulty": "intermediate"}},
             token=token)
        if status != 200 or not seat_data.get("session_id"):
            raise RuntimeError("staging Classroom session missing")
        seat = str(seat_data["session_id"])
        params = {
            "token": token, "session_id": seat,
            "topic": "Intermediate algebra equations and rational expressions",
            "mode": "solo", "duration_minutes": "5",
            "language": "en-US", "client_contract_version": "2",
        }
        url = API.replace("https://", "wss://") + "/api/v1/classroom/ws/connect?" + urlencode(params)
        assert urlsplit(url).hostname.endswith("-staging.up.railway.app")
        async with websockets.connect(url, open_timeout=20, close_timeout=5,
                                      max_size=5_000_000, ping_interval=20,
                                      ping_timeout=30) as ws:
            sent = False
            initial_quiz = None
            initial_id = None
            selected_certainty = "unknown"
            started = time.monotonic()
            deadline = started + 140
            graded_scene = False
            while time.monotonic() < deadline:
                try:
                    raw = await asyncio.wait_for(
                        ws.recv(), timeout=min(25, max(0.1, deadline-time.monotonic())))
                except asyncio.TimeoutError:
                    continue
                kind, nested, outer = event_parts(raw)
                if kind == "error":
                    raise RuntimeError("Classroom error event while grading")
                if kind in {"scene_start", "scene_stream"}:
                    scene = scene_of(nested, outer)
                    if not scene:
                        continue
                    source, quiz, recovery, feedback, count = inspect_scene(scene)
                    sid = str(scene["scene_id"])
                    if not sent:
                        if source != "ai_generated":
                            raise RuntimeError("initial algebra scene is not provider-authored")
                        if quiz is None:
                            raise RuntimeError("model-authored scene lacks an answerable QuizCard")
                        initial_id = sid
                        initial_quiz = quiz
                        print("PASS: provider-authored algebra QuizCard received, "
                              "components=" + str(count) +
                              " first_ms=" + str(round((time.monotonic()-started)*1000)),
                              flush=True)
                    elif sid != initial_id:
                        print("GRADING RESPONSE: source=" + source
                              + " feedback_role=" + str(feedback)
                              + " recovery_role=" + str(recovery)
                              + " component_count=" + str(count), flush=True)
                        if recovery:
                            raise RuntimeError("backend returned ungraded recovery, not graded feedback")
                        if source == "ai_generated" and feedback:
                            graded_scene = True
                            break
                if kind in {"scene_complete", "scene_end"} and initial_quiz and not sent:
                    options = initial_quiz.get("options") or []
                    wrong = next((x for x in options if isinstance(x, dict)
                                  and x.get("is_correct") is False and x.get("id")), None)
                    chosen = wrong or next((x for x in options
                                             if isinstance(x, dict) and x.get("id")), None)
                    if not chosen:
                        raise RuntimeError("QuizCard has no usable option")
                    if wrong:
                        selected_certainty = "declared_wrong"
                    await ws.send(json.dumps({
                        "event_type": "user_action",
                        "session_id": seat,
                        "action_intent": "submit_answer",
                        "component_id": str(initial_quiz.get("component_id") or ""),
                        "answer_data": {
                            "selected_option_id": chosen["id"],
                            "selected_option_label": chosen.get("label") or "",
                        },
                    }))
                    sent = True
                    print("PASS: submitted one authenticated answer; "
                          "option_certainty=" + selected_certainty, flush=True)
            if not sent:
                raise RuntimeError("no answer was submitted to the generated question")
            if not graded_scene:
                raise RuntimeError("no authoritative feedback scene after answer")
        print("PASS: real learner answer led to model-authored feedback scene", flush=True)
        success = True
    except Exception as exc:
        print("GRADING QA FAIL: " + type(exc).__name__ + ": "
              + str(exc).split("wss://")[0][:130], file=sys.stderr, flush=True)
    finally:
        if created:
            if not token:
                success = False
                print("FAIL: no synthetic grader cleanup token", file=sys.stderr)
            else:
                status, signin = qa.http("POST", "/api/v1/auth/login",
                     {"email": user["email"], "password": password})
                cleanup = signin.get("access_token") if status == 200 else token
                for attempt in range(3):
                    status, result = qa.http("DELETE", "/auth/me", token=cleanup)
                    if status == 200 and result.get("deleted") is True:
                        print("PASS: synthetic grading learner deleted", flush=True)
                        break
                    if status != 429 or attempt == 2:
                        success = False
                        print("FAIL: synthetic grading learner cleanup", file=sys.stderr)
                        break
                    await asyncio.sleep(65)
    return 0 if success else 1


if __name__ == "__main__":
    raise SystemExit(asyncio.run(run()))
