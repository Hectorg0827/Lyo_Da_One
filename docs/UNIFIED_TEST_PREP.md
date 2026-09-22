# Unified Test Prep clients

The web Home button now opens `/test-prep`. Typed Chat uses the server's same
saved intake. iOS Chat no longer intercepts exam requests with the separate
device-local orchestrator. Android has a native Test Prep destination on Home
and Chat, using the same authenticated endpoints as web and iOS.

All three dedicated screens load the account-owned profile, restore its
conversation, show the full schedule, accept photos/PDFs/text files, and edit
test details with revision checks. Today/readiness continue to distinguish a
failed load from missing evidence. Completion sends no client score.

Backend must deploy first: clients require `GET /me/study_plans/state` and
`PATCH /me/study_plans/profiles/{id}`. There is deliberately no silent fallback
to the old device-local flow if the shared API is unavailable.

Web validation: TypeScript, production build, the 86 existing Test Prep tests,
and product-trust/Classroom/chat parity checks. Native compilation and unit
tests run in the repository's existing iOS/Android CI jobs; this workspace has
no Xcode or Android SDK. Physical-device notification delivery remains a
release prerequisite, along with provider credentials described in the backend
`docs/UNIFIED_TEST_PREP.md`.

Release smoke test: begin intake in Chat, switch to Test Prep, finish intake,
reopen on a second device, edit the exam date, complete a lesson, and confirm
the same schedule and measured readiness on all devices. Retry one intake
request and one plan-generation request; neither may create duplicates.
