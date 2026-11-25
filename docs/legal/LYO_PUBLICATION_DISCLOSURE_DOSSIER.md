# LYO public Web legal disclosures — release verification dossier

**State:** NOT APPROVED FOR PUBLIC PRODUCTION RELEASE.
**Release control:** [Web issue #244](https://github.com/Hectorg0827/Lyo_Da_One/issues/244) and [legal issue #258](https://github.com/Hectorg0827/Lyo_Da_One/issues/258).

This is an owner/counsel evidence collection file, not a legal opinion or final privacy notice. Do not assume the owner's city equals the operating entity's registered address or that a proposed company name has been incorporated.

## Current source audit

| Public page | Unresolved issue | Owner/counsel evidence required |
|---|---|---|
| /privacy | [COMPANY LEGAL NAME], [ADDRESS], effective date | Actual contracting/legal data controller, entity status, contact, publication date |
| /privacy | [ANALYTICS / CRASH REPORTING PROVIDERS], [LIST AI PROVIDERS], [HOSTING PROVIDER] | Inventory every active SDK/API and processor by environment; purposes, retention, onward sharing and contract/training commitments |
| /privacy | [30] account deletion and [35] backup days | Backed-up data, object storage, logs, analytics, AI provider retention and deletion tests across every medium; remove unsupported time promises |
| /privacy | Claims of no sale or advertising, children's data, voice, locations, international transfers | Audit actual data flow, consent, advertising SDKs, age gate, children/minor eligibility, region-by-region legal review |
| /terms | Company identity, [STATE / COUNTRY], dispute process | Actual operator, jurisdiction and counsel-selected enforceable dispute text |
| /terms | [US $50] limitation, no subscription terms | Counsel-approved limitation, paid features/terms/refunds if applicable |
| /support | [2 business days] unsupported | Remove fabricated SLA until staffing and mailbox coverage are verified; show a real monitored contact |
| All | Contact support@lyoai.app hardcoded in LegalPage.tsx | Verify mailbox delivery, ownership, response routing and internal escalation; reconcile any historical support domains |

## Evidence and sign-off

The machine-readable lyo_publication_approval.json starts **all** fields as pending. Each required field must include an evidence reference and approval identity. The Privacy, Terms and Support source must contain no bracketed template markers. Counsel and owner must independently approve a specific effective date and exact public text after jurisdiction-specific review.

Before approval, confirm actual DELETE /auth/me behavior against: (1) user/profile row, (2) courses and lesson completions, (3) messages/community/media, (4) uploaded files/object storage, (5) third-party processors and analytics, (6) access/refresh tokens, (7) backups and logs. A successful API response or deleted synthetic login does not establish deletion of backups or third-party data. Confirm verified practices before inserting a retention duration into public disclosures.

Run python3 scripts/qa/lyo_legal_publication_gate.py on the exact legal source and sign-off manifest. The gate is deliberately red while legal approval remains outstanding. A passing technical gate is **not** a substitute for the owner's consent or a qualified lawyer's review.

## Unverified and prohibited shortcuts

- Do not substitute "LYO" or an intended future corporation name for an actually registered legal entity without proof.
- Do not assert 30/35 days, third-party data deletion, data never sold, zero advertising tracking, US-only data location, or AI provider no-training terms without verification.
- Do not quietly strip required privacy information solely to turn CI green.
- Do not deploy to production while any approval remains pending.
