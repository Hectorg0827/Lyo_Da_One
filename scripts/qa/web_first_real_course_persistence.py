#!/usr/bin/env python3
"""Real staging database read-after-write + ownership E2E, zero AI spend.

Creates two random QA learners, saves a structured intermediate algebra course,
re-reads it from the database through fresh HTTP calls, proves owner-only draft
access and publish denial, then permanently deletes both accounts and children.
No production hosts, no fake course GETs, no provider calls.
"""
import asyncio
import secrets
import sys
import time

import web_first_live_classroom_auth as qa


def account(prefix):
    nonce = secrets.token_hex(11)
    password = "LyoQA-" + secrets.token_hex(18) + "aA9!"
    return ({
        "email": f"lyo-{prefix}-qa-{nonce}@example.org",
        "username": prefix + "qa" + nonce[:19],
        "password": password, "confirm_password": password,
        "first_name": "Staging", "last_name": "QA",
    }, password)


async def registration(person):
    for attempt in range(3):
        code, result = qa.http("POST", "/api/v1/auth/register", person)
        if code in (200, 201):
            break
        if code != 429 or attempt == 2:
            raise RuntimeError("Staging registration rejected HTTP " + str(code))
        print("Registration rate-limited; bounded 65-second backoff", flush=True)
        await asyncio.sleep(65)
    token = result.get("access_token")
    if not token:
        code, login = qa.http("POST", "/api/v1/auth/login",
            {"email": person["email"], "password": person["password"]})
        if code != 200 or not login.get("access_token"):
            raise RuntimeError("Staging login failed")
        token = login["access_token"]
    code, me = qa.http("GET", "/api/v1/auth/me", token=token)
    if code != 200 or not me.get("id"):
        raise RuntimeError("Staging identity verification failed")
    return token, str(me["id"])


async def delete_account(token):
    for attempt in range(3):
        status, data = qa.http("DELETE", "/auth/me", token=token)
        if status == 200 and data.get("deleted") is True:
            return True
        if status != 429 or attempt == 2:
            return False
        await asyncio.sleep(65)
    return False


async def main():
    tokens = []
    cleanup_ok = True
    success = False
    try:
        first, _ = account("course")
        token, owner_id = await registration(first)
        tokens.append(token)
        print("PASS: authenticated synthetic owner", flush=True)
        title = "Staging QA Intermediate Algebra " + secrets.token_hex(5)
        request = {
            "title": title,
            "topic": "Intermediate algebra",
            "difficulty": "intermediate",
            "instructor_id": 99999999,  # must never override signed-in owner
            "modules": [{"title": "Linear equations", "lessons": [
                {"title": "Solving equations", "content":
                 [{"type": "text", "text": "Solve 2x + 4 = 12"}],
                 "duration_minutes": 8},
            ]}],
        }
        status, created = qa.http("POST", "/api/v1/learning/courses", request, token=token)
        if status != 201 or not str(created.get("id", "")).isdigit():
            raise RuntimeError("Course insert failed or returned non-durable identifier HTTP " + str(status))
        cid = str(created["id"])
        if str(created.get("instructor_id")) != owner_id or created.get("status") == "saved_locally":
            raise RuntimeError("Course creation fabricated success or accepted owner spoof")
        status, loaded = qa.http("GET", "/api/v1/learning/courses/" + cid, token=token)
        if status != 200 or loaded.get("title") != title:
            raise RuntimeError("Course read-after-write failed HTTP " + str(status))
        created_modules = created.get("modules") or []
        reloaded_modules = loaded.get("modules") or []
        first_lessons = (reloaded_modules[0].get("lessons") or []) if (
            reloaded_modules and isinstance(reloaded_modules[0], dict)) else []
        print("COURSE DIAGNOSTIC: created_modules=" + str(len(created_modules))
              + " reloaded_modules=" + str(len(reloaded_modules))
              + " reloaded_lessons=" + str(len(first_lessons))
              + " reloaded_keys=" + ",".join(sorted(loaded.keys())),
              flush=True)
        if not first_lessons or first_lessons[0].get("title") != "Solving equations":
            raise RuntimeError("Structured lesson content was not preserved")
        status, listing = qa.http("GET", "/api/v1/learning/courses?skip=0&limit=100", token=token)
        if status != 200 or not isinstance(listing, list) or not any(str(x.get("id")) == cid for x in listing):
            raise RuntimeError("Saved private course missing from owner listing")
        print("PASS: real database commit, detail reload and private-course listing", flush=True)
        other, _ = account("other")
        other_token, other_id = await registration(other)
        tokens.append(other_token)
        if owner_id == other_id:
            raise RuntimeError("Synthetic identities were not isolated")
        status, _ = qa.http("GET", "/api/v1/learning/courses/" + cid, token=other_token)
        if status != 404:
            raise RuntimeError("Different learner can read private draft: HTTP " + str(status))
        status, _ = qa.http("POST", "/api/v1/learning/courses/" + cid + "/publish",
                            token=other_token)
        if status != 404:
            raise RuntimeError("Different learner can publish draft: HTTP " + str(status))
        status, refreshed = qa.http("GET", "/api/v1/learning/courses/" + cid, token=token)
        if status != 200 or refreshed.get("title") != title:
            raise RuntimeError("Owner cannot reopen course after other-learner attempt")
        print("PASS: user isolation, denied cross-user publish, persisted reopen", flush=True)
        success = True
    except Exception as exc:
        # Never print response bodies, credentials or bearer tokens.
        print("COURSE STAGING QA FAIL: " + type(exc).__name__ + ": " +
              str(exc).split("https://")[0][:150], file=sys.stderr, flush=True)
    finally:
        for token in reversed(tokens):
            if not await delete_account(token):
                cleanup_ok = False
                print("COURSE QA CLEANUP FAILURE: reconcile synthetic account in staging",
                      file=sys.stderr, flush=True)
        if cleanup_ok:
            print("PASS: all synthetic course-test accounts deleted", flush=True)
    return 0 if success and cleanup_ok else 1


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
