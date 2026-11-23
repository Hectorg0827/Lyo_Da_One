#!/usr/bin/env python3
"""Fail-closed publication gate for owner/counsel-approved LYO legal notices.

Does not decide legal sufficiency; detects unapproved templates and missing
sign-offs. No network, no secrets, no production mutation.
"""
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "docs/legal/lyo_publication_approval.json"
PUBLIC = {
    "privacy": ROOT / "web/src/app/privacy/page.tsx",
    "terms": ROOT / "web/src/app/terms/page.tsx",
    "support": ROOT / "web/src/app/support/page.tsx",
}
UNRESOLVED_PATTERNS = [
    r"\[COMPANY LEGAL NAME\]", r"\[ADDRESS\]",
    r"\[ANALYTICS\s*/\s*CRASH REPORTING PROVIDERS",
    r"\[LIST AI PROVIDERS", r"\[HOSTING PROVIDER",
    r"\[30\]", r"\[35\]", r"\[STATE\s*/\s*COUNTRY\]",
    r"\[DISPUTE RESOLUTION PROCESS", r"\[US\s*\$50\]",
    r"\[2 business days\]",
]
CODE_DRAFT_PATTERN = r"DRAFT\s*[—\-]\s*NOT YET REVIEWED BY A LAWYER"


def check(notices, manifest):
    errors = []
    for label, source in notices.items():
        for pattern in UNRESOLVED_PATTERNS:
            if re.search(pattern, source, flags=re.IGNORECASE):
                errors.append(label + ": unresolved template " + pattern)
        if re.search(CODE_DRAFT_PATTERN, source, flags=re.IGNORECASE):
            errors.append(label + ": explicitly unreviewed legal draft")
    if manifest.get("status") != "APPROVED":
        errors.append("legal manifest NOT_APPROVED; cannot release")
    required = manifest.get("required")
    if not isinstance(required, dict) or len(required) < 16:
        errors.append("legal manifest missing required sign-off fields")
    else:
        for name, entry in required.items():
            if not isinstance(entry, dict) or (
                entry.get("status") != "approved"
                or not isinstance(entry.get("evidence_reference"), str)
                or not entry["evidence_reference"].strip()
                or not isinstance(entry.get("approved_by"), str)
                or not entry["approved_by"].strip()
            ):
                errors.append("sign-off pending: " + name)
    if "support@lyoai.app" not in (
        ROOT / "web/src/components/legal/LegalPage.tsx"
    ).read_text(encoding="utf-8"):
        errors.append("support mailbox changed: independent contact verification required")
    return errors


def test_known_failures():
    samples = {
        "privacy": "DRAFT — NOT YET REVIEWED BY A LAWYER [COMPANY LEGAL NAME] [30]",
        "terms": "The laws of [STATE / COUNTRY] apply; [US $50]",
        "support": "We answer within [2 business days]",
    }
    manifest = {"status": "NOT_APPROVED", "required": {}}
    errors = check(samples, manifest)
    assert any("COMPANY LEGAL NAME" in e for e in errors)
    assert any("legal draft" in e for e in errors)
    assert any("business days" in e for e in errors)
    assert any("legal manifest" in e for e in errors)
    print("PASS: legal publication gate detects fake templates, draft and missing approvals")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--unit", action="store_true")
    args = parser.parse_args()
    if args.unit:
        test_known_failures()
        return 0
    sources = {label: path.read_text(encoding="utf-8")
               for label, path in PUBLIC.items()}
    approval = json.loads(MANIFEST.read_text(encoding="utf-8"))
    problems = check(sources, approval)
    if problems:
        print("LEGAL PRODUCTION RELEASE BLOCKED: " + str(len(problems))
              + " unresolved source/approval checks")
        for finding in problems:
            print("BLOCK: " + finding)
        return 2
    print("PASS: template-free legal notices with evidence manifest approvals.")
    print("MANUAL GATE: counsel and owner must still independently approve publication.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
