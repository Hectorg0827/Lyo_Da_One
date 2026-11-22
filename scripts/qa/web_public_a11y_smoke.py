#!/usr/bin/env python3
"""Read-only WCAG and responsive smoke against PUBLIC staging pages.

Uses axe-core in real Chromium. No auth, learner accounts, model calls,
third-party actions, or production endpoints. Full authenticated Classroom,
device screen-reader and keyboard accessibility are separate release gates.
"""
import asyncio
import os
from pathlib import Path
from urllib.parse import urlsplit

from playwright.async_api import async_playwright

WEB_BASE = os.environ.get("LYO_WEB_BASE_URL", "https://lyoonestagingweb-staging.up.railway.app")
ROUTES = ("/auth/login", "/auth/signup", "/privacy", "/terms", "/support")
VIEWPORTS = (320, 390, 768)
AXE_SCRIPT = Path(os.environ.get(
    "AXE_SCRIPT_PATH", "/tmp/lyo-axe/node_modules/axe-core/axe.min.js",
))


async def main():
    parsed = urlsplit(WEB_BASE)
    if not ((parsed.scheme == "https" and parsed.hostname == "lyoonestagingweb-staging.up.railway.app")
            or (parsed.scheme == "http" and parsed.hostname == "127.0.0.1" and parsed.port == 3000)):
        raise RuntimeError("Only deployed staging or isolated local candidate is allowed")
    if not AXE_SCRIPT.is_file():
        raise RuntimeError("axe-core was not installed at the approved CI path")
    failures = []
    checked = 0
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True, args=["--no-sandbox"])
        try:
            for width in VIEWPORTS:
                context = await browser.new_context(viewport={"width": width, "height": 850})
                try:
                    page = await context.new_page()
                    for route in ROUTES:
                        response = await page.goto(WEB_BASE + route, wait_until="domcontentloaded", timeout=25000)
                        if not response or response.status != 200:
                            failures.append(f"{route}@{width}: HTTP {response.status if response else 'none'}")
                            continue
                        await page.wait_for_selector("body", timeout=5000)
                        await page.add_script_tag(path=str(AXE_SCRIPT))
                        audit = await page.evaluate("""async () => {
                            const result = await axe.run(document, {
                              runOnly: {type:'tag', values:[
                                'wcag2a','wcag2aa','wcag21a','wcag21aa','wcag22aa'
                              ]},
                            });
                            const severe = result.violations
                              .filter(v => v.impact === 'serious' || v.impact === 'critical')
                              .map(v => ({id:v.id, impact:v.impact, nodes:v.nodes.length}));
                            const horizontal = document.documentElement.scrollWidth -
                              document.documentElement.clientWidth;
                            return {severe, horizontal};
                        }""")
                        if audit["severe"]:
                            failures.append(f"{route}@{width}: axe {audit['severe']}")
                        if audit["horizontal"] > 2:
                            failures.append(f"{route}@{width}: horizontal overflow {audit['horizontal']}px")
                        if route.startswith("/auth/"):
                            await page.keyboard.press("Tab")
                            focusable = await page.evaluate("""() => {
                                const node = document.activeElement;
                                return node !== document.body && !!node &&
                                  ['INPUT','BUTTON','A','SELECT','TEXTAREA'].includes(node.tagName);
                            }""")
                            if not focusable:
                                failures.append(f"{route}@{width}: Tab did not focus interactive element")
                        checked += 1
                    await page.close()
                finally:
                    await context.close()
        finally:
            await browser.close()
    print(f"Read-only accessibility smoke completed: {checked} route/viewport pairs", flush=True)
    if failures:
        for item in failures:
            print("FAIL " + item, flush=True)
        raise SystemExit(1)
    assert checked == len(ROUTES) * len(VIEWPORTS), checked
    print("PASS: no serious/critical axe WCAG findings, horizontal overflow "
          "or auth keyboard focus failures on surveyed public staging pages", flush=True)
    print("LIMIT: This does not certify authenticated Classroom, screen reader,"
          " full WCAG compliance, or production", flush=True)


if __name__ == "__main__":
    asyncio.run(main())
