#!/usr/bin/env python3
"""Measured first programmatic media playback from entering real staging Classroom.

Real authenticated Web UI, real staging local Kokoro TTS, deterministic
synthetic teaching scene. Paid TTS fallback must be OFF, no text-model calls.
Play and media-time events come from actual HTMLAudioElement; they are not
proof of human-heard speaker output or real AI authoring latency.
"""
import asyncio
import json
import secrets
import sys
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

from playwright.async_api import async_playwright
from web_first_live_classroom_auth import API, http

WEB = "https://lyoonestagingweb-staging.up.railway.app"
QA_SCENE = r"""(() => {
  const Real = window.WebSocket;
  window.__qaAudioClock = { plays: 0, playing_ms: null, progress_ms: null };
  const originalPlay = HTMLMediaElement.prototype.play;
  HTMLMediaElement.prototype.play = function(...args) {
    const clock = window.__qaAudioClock;
    clock.plays++;
    this.addEventListener('playing', () => {
      if (clock.playing_ms === null) clock.playing_ms = Math.round(performance.now());
    }, {once:true});
    this.addEventListener('timeupdate', () => {
      if (clock.progress_ms === null && this.currentTime >= 0.10)
        clock.progress_ms = Math.round(performance.now());
    });
    return originalPlay.apply(this, args);
  };
  class SyntheticSceneSocket {
    constructor(url) {
      this.url = String(url); this.readyState = 0;
      this.listeners = {}; this.closed = false;
      this.seat = new URL(this.url).searchParams.get('session_id');
      setTimeout(() => {
        if (this.closed) return;
        this.readyState = 1;
        this.fire('open', new Event('open'));
        const language = new URL(this.url).searchParams.get('language') || 'en-US';
        const spanish = language.toLowerCase().startsWith('es');
        setTimeout(() => {
          if (this.closed) return;
          this.message({
            event_type:'scene_start', session_id:this.seat,
            scene:{scene_id:'qa-scene-no-provider', scene_type:'instruction', components:[]}
          });
          this.message({
            event_type:'component_render', session_id:this.seat,
            component:{
              component_id:'qa-first-voice',
              type:'TeacherMessage', language_code:language,
              text:spanish
                ? 'Vamos a comparar fracciones equivalentes y resolver un ejemplo sencillo.'
                : 'Let us compare equivalent fractions and solve a simple example together.'
            }
          });
          this.message({event_type:'scene_complete', session_id:this.seat});
        }, 50);
      }, 25);
    }
    on(name, fn) {(this.listeners[name] ||= []).push(fn);}
    addEventListener(name,fn){this.on(name,fn);}
    removeEventListener(name,fn){this.listeners[name]=(this.listeners[name]||[]).filter(x=>x!==fn);}
    fire(name,event){
      for (const fn of this.listeners[name] || []) fn(event);
      const handler = this['on'+name];
      if (typeof handler === 'function') handler(event);
    }
    message(obj){this.fire('message',{data:JSON.stringify(obj)});}
    send(raw){ /* no graded/AI action */ }
    close(){
      if(this.closed)return;
      this.closed=true;this.readyState=3;
      this.fire('close',{code:1000,reason:'Synthetic QA disconnected'});
    }
  }
  function SafeSocket(url,...args){
    const target = new URL(String(url),location.href);
    if(target.pathname==='/api/v1/classroom/ws/connect'){
      if(target.hostname !== 'lyojourneystagingbackend-staging.up.railway.app')
        throw Error('Refuse unsafe classroom socket');
      return new SyntheticSceneSocket(url);
    }
    return new Real(url,...args);
  }
  Object.assign(SafeSocket,{CONNECTING:0,OPEN:1,CLOSING:2,CLOSED:3});
  window.WebSocket=SafeSocket;
})();"""


def preflight():
    if urlsplit(API).hostname != "lyojourneystagingbackend-staging.up.railway.app":
        raise RuntimeError("Non-staging API refused")
    with urlopen(Request(API + "/api/v1/tts/health"), timeout=25) as res:
        d = json.load(res)
    if d.get("paid_fallback_enabled") is not False or not d.get("provider_configured"):
        raise RuntimeError("Strict local-TTS-only preflight failed")
    print("PASS: strict local TTS-only staging preflight", flush=True)


async def main():
    preflight()
    marker = secrets.token_hex(12)
    pw = "LYO-FIRSTAUDIO-"+secrets.token_hex(20)+"aA9!"
    person = {
        "email":"lyo-page-audio-"+marker+"@example.org",
        "username":"pageaudio"+marker[:16],
        "password":pw,"confirm_password":pw,
        "first_name":"Synthetic","last_name":"PageAudio",
    }
    token=None
    created=False
    success=False
    browser=None
    try:
        for i in range(3):
            code, payload = http("POST","/api/v1/auth/register",person)
            if code in (200,201):
                created=True
                break
            if code!=429 or i==2:raise RuntimeError("Registration denied")
            await asyncio.sleep(65)
        token = payload.get("access_token")
        if not token:
            code, login = http("POST","/api/v1/auth/login",{
                "email":person["email"],"password":pw
            })
            if code!=200 or not login.get("access_token"):
                raise RuntimeError("Cleanup JWT unavailable")
            token=login["access_token"]
        async with async_playwright() as playwright:
            browser=await playwright.chromium.launch(headless=True,args=[
                "--no-sandbox","--autoplay-policy=no-user-gesture-required"])
            context=await browser.new_context(viewport={"width":412,"height":915},
                                              bypass_csp=True)
            allowed={urlsplit(WEB).hostname,urlsplit(API).hostname}
            async def guard(route):
                req=route.request
                parsed=urlsplit(req.url)
                path=parsed.path
                if parsed.hostname in {"lyoai.app","api.lyoai.app"}:
                    await route.abort(error_code="blockedbyclient")
                    return
                if req.method.upper() not in ("GET","HEAD","OPTIONS") and (
                    parsed.hostname not in allowed or (
                        path not in ("/auth/login","/api/v1/auth/login",
                                     "/api/v1/tts/synthesize/stream")
                    )
                ):
                    await route.abort(error_code="blockedbyclient")
                    return
                await route.continue_()
            await context.route("**/*",guard)
            page=await context.new_page()
            await page.goto(WEB+"/auth/login",wait_until="domcontentloaded",timeout=30000)
            await page.get_by_role("button",name="Log In",exact=True).wait_for(
                state="visible",timeout=30000)
            await page.get_by_label("Email",exact=True).fill(person["email"])
            await page.get_by_label("Password",exact=True).fill(pw)
            await page.get_by_role("button",name="Log In",exact=True).click()
            await page.wait_for_function(
                "() => Boolean(localStorage.getItem('lyo_token'))",timeout=35000)
            print("PASS: real synthetic staging Web UI login",flush=True)
            await context.add_init_script(QA_SCENE)
            for language in ("en-US","es-US"):
                await page.goto(WEB+"/classroom?topic=Fractions&duration=3&language="+language,
                                wait_until="domcontentloaded",timeout=30000)
                await page.get_by_role("button",name="Leave classroom").wait_for(timeout=30000)
                await page.wait_for_function(
                    "() => window.__qaAudioClock?.playing_ms !== null"
                    " && window.__qaAudioClock?.progress_ms !== null",
                    timeout=65000)
                clock=await page.evaluate("window.__qaAudioClock")
                print("CLASSROOM_PAGE_FIRST_MEDIA language="+language+
                      " playing_ms="+str(clock["playing_ms"])+
                      " media_progress_100ms="+str(clock["progress_ms"])+
                      " audio_play_calls="+str(clock["plays"]),flush=True)
                if clock["plays"]<1 or clock["progress_ms"]<clock["playing_ms"]:
                    raise RuntimeError("Real Classroom speaker did not progress")
            success=True
            print("LIMIT: synthetic instant teacher scene; not real AI authoring"
                  " or physical listener first-audible measurement",flush=True)
    except Exception as exc:
        print("PAGE-AUDIO FAIL: "+type(exc).__name__+" (sensitive details suppressed)",
              file=sys.stderr,flush=True)
    finally:
        if browser:
            try:await browser.close()
            except Exception:pass
        if created:
            code,fresh=http("POST","/api/v1/auth/login",{
                "email":person["email"],"password":pw})
            cleanup=fresh.get("access_token") if code==200 else token
            if not cleanup:
                success=False
                print("CLEANUP BLOCKED",file=sys.stderr)
            else:
                code,resp=http("DELETE","/auth/me",token=cleanup)
                if code==200 and resp.get("deleted") is True:
                    print("PASS: synthetic page-audio learner deleted",flush=True)
                else:
                    success=False
                    print("CLEANUP FAILED",file=sys.stderr)
    return 0 if success else 1


if __name__=="__main__":
    raise SystemExit(asyncio.run(main()))
