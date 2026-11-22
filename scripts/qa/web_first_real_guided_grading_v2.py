#!/usr/bin/env python3
"""Real staging learner: diagnostic feedback THEN graded practice feedback.

The opening diagnostic is deliberately ungraded for mastery. Do not confuse it
with the later supported-practice checkpoint; test both separately. Use one
learner, one diagnostic answer, at most six learner-paced Continue actions and
one practice answer. No provider text, grades, PII or bearer URLs logged.
"""
import asyncio
import json
import secrets
import sys
import time
from urllib.parse import urlencode, urlsplit

import websockets
import web_first_live_classroom_auth as qa


def parse_event(raw):
    obj = json.loads(raw)
    if not isinstance(obj, dict):
        return "", {}, {}
    payload = obj.get("data") if isinstance(obj.get("data"), dict) else {}
    kind = str(obj.get("event_type") or obj.get("type")
               or payload.get("event_type") or "").lower()
    return kind, payload, obj


def choose_wrong(quiz):
    options = quiz.get("options") or []
    wrong = next((v for v in options if isinstance(v, dict)
                  and v.get("id") and v.get("is_correct") is False), None)
    selected = wrong or next((v for v in options
                              if isinstance(v, dict) and v.get("id")), None)
    if not selected or not quiz.get("component_id"):
        raise RuntimeError("No usable authenticated QuizCard option")
    return str(quiz["component_id"]), str(selected["id"]), str(selected.get("label") or "")


async def main():
    nonce = secrets.token_hex(12)
    password = "LyoQA-" + secrets.token_hex(16) + "aA9!"
    user = {
        "email": "lyo-guided-grade-" + nonce + "@example.org",
        "username": "guidedqa" + nonce[:18],
        "password": password, "confirm_password": password,
        "first_name": "Staging", "last_name": "Grading",
    }
    created = False
    token = None
    passed = False
    try:
        for attempt in range(3):
            status, registration = qa.http("POST", "/api/v1/auth/register", user)
            if status in (200, 201):
                created = True
                break
            if status != 429 or attempt == 2:
                raise RuntimeError("Staging registration rejected: HTTP " + str(status))
            await asyncio.sleep(65)
        token = registration.get("access_token")
        if not token:
            code, login = qa.http("POST", "/api/v1/auth/login",
                                  {"email": user["email"], "password": password})
            if code != 200 or not login.get("access_token"):
                raise RuntimeError("Staging sign-in rejected")
            token = login["access_token"]
        code, identity = qa.http("GET", "/api/v1/auth/me", token=token)
        if code != 200 or not identity.get("id"):
            raise RuntimeError("Staging learner identity rejected")
        code, session = qa.http("POST", "/api/v1/classroom/session",
            {"preferences": {"language": "en-US", "difficulty": "intermediate"}},
            token=token)
        if code != 200 or not session.get("session_id"):
            raise RuntimeError("Could not start Classroom session")
        sid = str(session["session_id"])
        params = {
            "token": token, "session_id": sid,
            "topic": "Intermediate algebra linear equations",
            "mode": "solo", "duration_minutes": "5",
            "language": "en-US", "client_contract_version": "2",
        }
        url = qa.API.replace("https://", "wss://") + "/api/v1/classroom/ws/connect?" + urlencode(params)
        if not urlsplit(url).hostname.endswith("-staging.up.railway.app"):
            raise RuntimeError("Nonstaging target denied")
        first_scene = None
        current_scene = None
        current_quiz = None
        diagnostic_sent = False
        diagnostic_feedback = False
        practice_sent = False
        practice_feedback = False
        continue_count = 0
        scene_count = 0
        verdict = None
        start = time.monotonic()
        async with websockets.connect(url, open_timeout=20, close_timeout=5,
                                      max_size=5_000_000, ping_interval=20,
                                      ping_timeout=30) as ws:
            deadline = start + 210
            async def answer(quiz, kind):
                component_id, option_id, option_label = choose_wrong(quiz)
                await ws.send(json.dumps({
                    "event_type": "user_action", "session_id": sid,
                    "action_intent": "submit_answer", "component_id": component_id,
                    "answer_data": {"selected_option_id": option_id,
                                    "selected_option_label": option_label},
                }))
                print("ACTION: one " + kind + " answer submitted", flush=True)

            while time.monotonic() < deadline:
                try:
                    raw = await asyncio.wait_for(ws.recv(),
                         timeout=min(25, max(0.1, deadline-time.monotonic())))
                except asyncio.TimeoutError:
                    continue
                kind, data, obj = parse_event(raw)
                if kind == "error":
                    raise RuntimeError("Classroom error event")
                if kind in ("scene_start", "scene_stream"):
                    scene = data.get("scene") or obj.get("scene")
                    if not isinstance(scene, dict) or not scene.get("scene_id"):
                        continue
                    if current_scene == str(scene["scene_id"]):
                        continue
                    current_scene = str(scene["scene_id"])
                    scene_count += 1
                    meta = scene.get("metadata") or {}
                    if meta.get("scene_source") != "ai_generated":
                        raise RuntimeError("Nonprovider scene during graded progression")
                    components = scene.get("components") or []
                    current_quiz = next((x for x in components
                        if isinstance(x, dict) and x.get("type") == "QuizCard"
                        and x.get("options")), None)
                    if first_scene is None:
                        first_scene = current_scene
                        if current_quiz is None:
                            raise RuntimeError("Initial provider diagnostic missing")
                        print("PASS: provider diagnostic available; elapsed_ms="
                              + str(round((time.monotonic()-start)*1000)), flush=True)
                    else:
                        print("SCENE: authoritative step #" + str(scene_count)
                              + ", quiz=" + str(current_quiz is not None), flush=True)
                elif kind == "answer_feedback":
                    verdict = str(data.get("verdict") or "")
                    if not diagnostic_sent:
                        raise RuntimeError("Feedback without a submitted answer")
                    if practice_sent:
                        if verdict not in {"correct", "incorrect", "partial"}:
                            raise RuntimeError("Practice answer was not graded")
                        practice_feedback = True
                        print("PASS: real practice feedback verdict=" + verdict, flush=True)
                        break
                    else:
                        diagnostic_feedback = True
                        print("PASS: diagnostic feedback received (ungraded for mastery)", flush=True)
                elif kind == "scene_complete" and current_scene:
                    if not diagnostic_sent:
                        if current_quiz is None:
                            raise RuntimeError("Diagnostic scene had no question")
                        await answer(current_quiz, "diagnostic")
                        diagnostic_sent = True
                    elif diagnostic_sent and not diagnostic_feedback:
                        # Wait for the learner's prior probe to be acknowledged.
                        continue
                    elif not practice_sent:
                        if current_quiz is not None and current_scene != first_scene:
                            await answer(current_quiz, "practice")
                            practice_sent = True
                        else:
                            if continue_count >= 6:
                                raise RuntimeError("No practice checkpoint after six lessons")
                            await ws.send(json.dumps({
                                "event_type": "user_action", "session_id": sid,
                                "action_intent": "continue",
                            }))
                            continue_count += 1
                            print("ACTION: controlled lesson Continue #"
                                  + str(continue_count), flush=True)
        if not diagnostic_feedback:
            raise RuntimeError("Initial diagnostic feedback absent")
        if not practice_sent:
            raise RuntimeError("No genuine guided practice answer submitted")
        if not practice_feedback:
            raise RuntimeError("Real guided practice feedback absent")
        print("PASS: diagnostic, lesson progression and server-graded practice; "
              "scenes=" + str(scene_count) + " continues=" + str(continue_count),
              flush=True)
        passed = True
    except Exception as exc:
        print("GUIDED GRADING FAIL: " + type(exc).__name__ + ": "
              + str(exc).split("wss://")[0][:100], file=sys.stderr, flush=True)
    finally:
        if created and token:
            code, login = qa.http("POST", "/api/v1/auth/login",
                {"email": user["email"], "password": password})
            cleanup_token = login.get("access_token") if code == 200 else token
            for attempt in range(3):
                code, deleted = qa.http("DELETE", "/auth/me", token=cleanup_token)
                if code == 200 and deleted.get("deleted") is True:
                    print("PASS: synthetic grading learner permanently deleted", flush=True)
                    break
                if code != 429 or attempt == 2:
                    passed = False
                    print("FAIL: synthetic account deletion requires investigation",
                          file=sys.stderr, flush=True)
                    break
                await asyncio.sleep(65)
        elif created:
            passed = False
            print("FAIL: synthetic cleanup token unavailable", file=sys.stderr, flush=True)
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
