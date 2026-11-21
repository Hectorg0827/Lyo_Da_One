#!/usr/bin/env python3
"""No-provider browser verification of the real deployed Web Classroom bridge UI.

Real staging login, then an isolated synthetic WebSocket that sends the exact
ungraded bridge and authoritative scene contracts. No AI or TTS network calls.
"""
import asyncio
import os
import secrets
import sys
from pathlib import Path
from urllib.parse import urlsplit
from playwright.async_api import async_playwright
from web_first_live_classroom_auth import http, API

WEB = os.environ.get("LYO_WEB_BASE_URL", "https://lyoonestagingweb-staging.up.railway.app")
assert (urlsplit(WEB).hostname or "").endswith("-staging.up.railway.app")
assert (urlsplit(API).hostname or "").endswith("-staging.up.railway.app")
ARTIFACTS = Path("artifacts/web-first-bridge-visual-fixture")
ARTIFACTS.mkdir(parents=True, exist_ok=True)

SOCKET_FIXTURE = r"""(() => {
  const Native = window.WebSocket;
  const notes = [];
  window.__lyoBridgeFixtureNotes = notes;

  class FakeClassroomSocket {
    constructor(url) {
      this.url = String(url);
      this.readyState = 0;
      this.bufferedAmount = 0;
      this.protocol = "";
      this.binaryType = "blob";
      this.listeners = {};
      this.seat = new URL(this.url).searchParams.get("session_id");
      this.closed = false;
      notes.push("classroom-socket");
      setTimeout(() => {
        if (this.closed) return;
        this.readyState = 1;
        this.emit("open", new Event("open"));
        setTimeout(() => this.message({
          event_type: "bridge_message", session_id: this.seat,
          data: {
            generation: 1, phase: "startup",
            text: "We're exploring fractions. What do you already know?",
            prompt: true, ungraded: true, ai_generated: false
          }
        }), 60);
        setTimeout(() => {
          if (this.closed) return;
          this.message({
            event_type: "scene_start", session_id: this.seat,
            scene: {scene_id: "qa-authoritative-scene", scene_type: "instruction", components: []}
          });
          this.message({
            event_type: "component_render", session_id: this.seat,
            component: {
              component_id: "qa-teacher-1", type: "TeacherMessage",
              text: "Equivalent fractions show the same value using different numerators and denominators.",
              language_code: "en-US"
            }
          });
          this.message({event_type: "scene_complete", session_id: this.seat});
        }, 7500);
      }, 20);
    }
    on(type, callback) {
      (this.listeners[type] ||= []).push(callback);
    }
    addEventListener(type, callback) { this.on(type, callback); }
    removeEventListener(type, callback) {
      this.listeners[type] = (this.listeners[type] || []).filter(x => x !== callback);
    }
    emit(type, event) {
      for (const callback of this.listeners[type] || []) callback(event);
      const handler = this["on" + type];
      if (typeof handler === "function") handler(event);
    }
    message(payload) {
      if (this.closed) return;
      notes.push(payload.event_type === "bridge_message"
        ? "bridge:" + payload.data.phase : payload.event_type);
      this.emit("message", { data: JSON.stringify(payload) });
    }
    send(raw) {
      let msg;
      try { msg = JSON.parse(raw); } catch { return; }
      if (msg.event_type !== "bridge_reply") return;
      notes.push("bridge_reply");
      setTimeout(() => this.message({
        event_type: "bridge_message", session_id: this.seat,
        data: {
          generation: 1, phase: "startup",
          text: "That is a useful observation. What makes two fractions equivalent?",
          prompt: true, ungraded: true, ai_generated: true
        }
      }), 250);
    }
    close() {
      if (this.closed) return;
      this.closed = true; this.readyState = 3;
      this.emit("close", {code: 1000, reason: "Synthetic QA socket closed"});
    }
  }

  function ClassroomWebSocket(url, ...rest) {
    const u = new URL(String(url), window.location.href);
    if (u.pathname === "/api/v1/classroom/ws/connect") {
      if (!u.hostname.endsWith("-staging.up.railway.app")) {
        throw new Error("Synthetic Classroom socket target not staging");
      }
      return new FakeClassroomSocket(url);
    }
    return new Native(url, ...rest);
  }
  Object.assign(ClassroomWebSocket, {
    CONNECTING: 0, OPEN: 1, CLOSING: 2, CLOSED: 3
  });
  window.WebSocket = ClassroomWebSocket;
})();"""


async def run():
    nonce = secrets.token_hex(12)
    password = "LyoQA-" + secrets.token_hex(16) + "aA9!"
    person = {
        "email": "lyo-fixture-" + nonce + "@example.org",
        "username": "bridgefixture" + nonce[:18],
        "password": password, "confirm_password": password,
        "first_name": "Staging", "last_name": "QA",
    }
    token, created, success = None, False, False
    browser = None
    stage = "registration"
    try:
        status, registered = http("POST", "/api/v1/auth/register", person)
        if status not in (200, 201):
            raise RuntimeError("Registration failed")
        created = True
        token = registered.get("access_token")
        if not token:
            code, data = http("POST", "/api/v1/auth/login",
                {"email": person["email"], "password": password})
            if code != 200 or not data.get("access_token"):
                raise RuntimeError("Synthetic cleanup token unavailable")
            token = data["access_token"]

        stage = "visible login"
        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True, args=["--no-sandbox"])
            context = await browser.new_context(viewport={"width": 412, "height": 915})
            # The fixture suppresses Classroom network requests, not real login.
            safe_hosts = {(urlsplit(WEB).hostname or ""), (urlsplit(API).hostname or "")}
            async def safe_route(route):
                req = route.request
                host = urlsplit(req.url).hostname or ""
                path = urlsplit(req.url).path
                if path.startswith("/api/v1/tts/"):
                    await route.abort(error_code="blockedbyclient")
                    return
                if req.method.upper() in {"POST", "PUT", "PATCH", "DELETE"} and host not in safe_hosts:
                    await route.abort(error_code="blockedbyclient")
                    return
                await route.continue_()
            await context.route("**/*", safe_route)
            page = await context.new_page()
            await page.goto(WEB + "/auth/login", wait_until="domcontentloaded", timeout=25000)
            await page.get_by_role("button", name="Log In", exact=True).wait_for(timeout=30000)
            await page.get_by_label("Email", exact=True).fill(person["email"])
            await page.get_by_label("Password", exact=True).fill(password)
            await page.get_by_role("button", name="Log In", exact=True).click()
            await page.wait_for_function(
                "() => Boolean(localStorage.getItem('lyo_token'))", timeout=35000)
            print("PASS: genuine staging Web login", flush=True)

            stage = "synthetic bridge startup and visible ungraded conversation"
            await context.add_init_script(SOCKET_FIXTURE)
            await page.goto(WEB + "/classroom?topic=Fractions&duration=5&language=en-US",
                            wait_until="domcontentloaded", timeout=25000)
            region = page.get_by_role(
                "region", name="Live teacher conversation before the next lesson step")
            await region.wait_for(state="visible", timeout=8500)
            if not await region.get_by_text("Start learning now", exact=False).is_visible():
                raise RuntimeError("Visible quick-teacher heading missing")
            if not await region.get_by_text("Conversation · not graded", exact=False).is_visible():
                raise RuntimeError("Quick teacher incorrectly appears graded")
            await page.screenshot(path=str(ARTIFACTS / "bridge_visible.png"), full_page=True)
            print("PASS: real deployed Web rendered ungraded quick teacher", flush=True)

            stage = "synthetic learner bridge reply"
            await region.get_by_role("textbox", name="Your ungraded reply to the teacher").fill(
                "Fractions describe parts of a whole.")
            await region.get_by_role("button", name="Reply", exact=True).click()
            await region.get_by_text("That is a useful observation", exact=False).wait_for(
                state="visible", timeout=2500)
            print("PASS: Web rendered a quick teacher reply while scene remained pending",
                  flush=True)

            stage = "authoritative teaching handoff"
            await page.get_by_text("Equivalent fractions show the same value",
                                   exact=False).first.wait_for(state="visible", timeout=14000)
            if await region.count():
                raise RuntimeError("Ungraded bridge persisted after authoritative scene")
            events = await page.evaluate("window.__lyoBridgeFixtureNotes || []")
            if not events or events[0] != "classroom-socket" or "bridge:startup" not in events:
                raise RuntimeError("Synthetic WebSocket event ordering invalid")
            if events.index("bridge:startup") >= events.index("scene_start"):
                raise RuntimeError("Bridge did not precede authoritative lesson")
            await page.screenshot(path=str(ARTIFACTS / "real_scene_handoff.png"), full_page=True)
            print("PASS: real deployed Web cleared bridge at authoritative scene",
                  flush=True)
            success = True
    except Exception as exc:
        print("VISUAL FIXTURE FAIL at " + stage + ": " + type(exc).__name__
              + ": " + str(exc)[:170], file=sys.stderr, flush=True)
    finally:
        if browser:
            try: await browser.close()
            except Exception: pass
        if created and token:
            try:
                code, data = http("DELETE", "/auth/me", token=token)
                if code == 200 and data.get("deleted") is True:
                    print("PASS: synthetic visual learner deleted", flush=True)
                else:
                    print("VISUAL FIXTURE CLEANUP FAILED", file=sys.stderr)
                    success = False
            except Exception:
                success = False
        elif created:
            success = False
    return 0 if success else 1


if __name__ == "__main__":
    raise SystemExit(asyncio.run(run()))
