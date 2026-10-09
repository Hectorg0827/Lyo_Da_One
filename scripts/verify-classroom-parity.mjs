import { existsSync, readFileSync } from 'node:fs';

const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
const failures = [];

function requireText(source, expected, label) {
  if (!source.includes(expected)) failures.push(`${label}: missing ${JSON.stringify(expected)}`);
}

function rejectText(source, forbidden, label) {
  if (source.includes(forbidden)) failures.push(`${label}: forbidden ${JSON.stringify(forbidden)}`);
}

const web = read('web/src/stores/classroom-store.ts');
const webContract = read('web/src/lib/classroom-contract.mjs');
const webSpeech = read('web/src/lib/browser-speech.ts');
const webPage = read('web/src/app/(main)/classroom/page.tsx');
const webCaption = read('web/src/components/classroom/ClassroomCaptionSync.tsx');
const webDueReviews = read('web/src/components/chat/DueReviewsNudge.tsx');
const iosClassroom = read('Sources/Services/LivingClassroomService.swift');
const iosTts = read('Sources/Core/Networking/Endpoint.swift');
const iosModels = read('Sources/Models/SDUIModels.swift');
const iosView = read('Sources/Views/Classroom/ActiveLessonView.swift');
const iosClassroomView = read('Sources/Views/Main/Classroom/LivingClassroomView.swift');
const iosPersonalization = read('Sources/Services/PersonalizationService.swift');
const iosPersonalizationModels = read('Sources/Models/PersonalizationModels.swift');
const iosLegacyModel = read('Sources/Models/Classroom.swift');
const iosLegacyViewModel = read('Sources/ViewModels/ClassroomViewModel.swift');
const iosLegacyOverlay = read('Sources/Components/Classroom/QuickCheckOverlay.swift');
const androidClassroom = read(
  'android/app/src/main/java/com/lyo/app/ui/screens/classroom/ClassroomScreen.kt',
);
const androidVoice = read(
  'android/app/src/main/java/com/lyo/app/ui/screens/classroom/ClassroomVoicePlayer.kt',
);
const androidNavigation = read(
  'android/app/src/main/java/com/lyo/app/ui/navigation/LyoNavHost.kt',
);
const androidChrome = read(
  'android/app/src/main/java/com/lyo/app/ui/classroom/ClassroomChrome.kt',
);
const androidLivingClassroom = read(
  'android/app/src/main/java/com/lyo/app/ui/classroom/ClassroomScreen.kt',
);
const androidLivingEngine = read(
  'android/app/src/main/java/com/lyo/app/ui/classroom/ClassroomEngine.kt',
);
const androidSocket = read(
  'android/app/src/main/java/com/lyo/app/data/classroom/ClassroomSocketClient.kt',
);
const androidBridge = read(
  'android/app/src/main/java/com/lyo/app/ui/classroom/ClassroomBridge.kt',
);
const androidWire = read(
  'android/app/src/main/java/com/lyo/app/data/classroom/ClassroomWireModels.kt',
);
const androidHome = read(
  'android/app/src/main/java/com/lyo/app/ui/screens/home/HomeScreen.kt',
);
const androidApi = read(
  'android/app/src/main/java/com/lyo/app/data/api/LyoApiService.kt',
);

for (const [source, label] of [
  [web, 'Web classroom'],
  [iosTts, 'iOS classroom'],
  [androidVoice, 'Android classroom'],
]) {
  requireText(source, '/api/v1/tts/synthesize', `${label} shared voice endpoint`);
}

requireText(webContract, 'language:', 'Web locale contract');
requireText(webContract, "client_contract_version: '2'", 'Web contract version');
requireText(webContract, "params.set('course_id'", 'Web course identity');
requireText(web, 'comp.language_code', 'Web component locale');
requireText(iosClassroom, 'component.languageCode ?? "auto"', 'iOS component locale');
requireText(androidWire, 'val language_code: String?', 'Android component locale');
requireText(androidLivingEngine, 'component.language_code', 'Android locale reaches teacher voice');

requireText(web, 'learnerTakesFloor()', 'Web interruption contract');
requireText(iosClassroom, 'bargeIn()', 'iOS interruption contract');
requireText(androidLivingEngine, 'voicePlayer?.stop()', 'Android learner barge-in stops teacher voice');
requireText(androidLivingEngine, 'ClassroomBridge.askQuestionAction', 'Android interruption contract');
requireText(web, "if (!sendAction('skip_question'", 'Web offline-safe skip');
requireText(iosClassroom, 'guard isConnected, let task = webSocketTask', 'iOS offline-safe action');
requireText(iosView, 'guard onSkip(component) else { return false }', 'iOS offline-safe skip');
requireText(androidSocket, 'fun send(envelope: UserActionEnvelope): Boolean', 'Android socket reports failed sends');
requireText(androidLivingEngine, 'if (!sent) return', 'Android failed answer cannot advance locally');

for (const [source, label] of [
  [web, 'Web classroom'],
  [iosClassroomView, 'iOS classroom'],
]) {
  requireText(source, 'skip_question', `${label} neutral skip`);
  requireText(source, 'request_hint', `${label} learner help`);
}
requireText(androidBridge, 'JsonPrimitive("I\'m not sure")', 'Android neutral unsure path');
requireText(androidBridge, 'action_intent = "request_hint"', 'Android learner help');

rejectText(web, 'resumePlayer(); // a classmate jumps in', 'Web unattended continuation');
rejectText(iosClassroom, 'startHesitationWatch(for: component)', 'iOS timed learner interruption');
rejectText(iosClassroom, 'self.startLocalLesson()', 'iOS platform-only classroom fallback');
rejectText(iosClassroom, 'LivingClassroomEngine()', 'iOS platform-only teaching engine');
rejectText(
  read('Sources/Views/Classroom/ActiveLessonView.swift'),
  'unlockAndAdvanceSoftly',
  'iOS answer auto-advance',
);

requireText(iosModels, 'case inputField = "InputField"', 'iOS application evidence UI');
requireText(webSpeech, 'SpeechRecognition', 'Web learner voice input');
requireText(androidBridge, '"InputField"', 'Android application evidence UI');
requireText(androidChrome, 'RecognizerIntent.ACTION_RECOGNIZE_SPEECH', 'Android learner voice input');
requireText(androidNavigation, 'ClassroomScreen(', 'Android live classroom route');
requireText(androidClassroom, 'A2UIClassroomScreen(', 'Android route delegates to canonical A2UI classroom');
rejectText(androidClassroom, 'AndroidClassroomController', 'Android duplicate classroom runtime');
requireText(androidSocket, 'addQueryParameter("course_id"', 'Android course identity');
requireText(androidSocket, 'addQueryParameter("client_contract_version", "2")', 'Android contract version');
requireText(iosClassroom, 'URLQueryItem(name: "course_id"', 'iOS course identity');
requireText(iosClassroom, 'URLQueryItem(name: "client_contract_version", value: "2")', 'iOS contract version');

// ── Learner evidence / "What you've shown" parity ───────────────────────────
// All three classrooms must read committed server evidence. A native client
// may display it differently, but it may not infer the learner's rung from
// transcript length, local answer counts, or time spent.
requireText(webPage, 'EvidenceRecord', 'Web committed learner record');
requireText(iosPersonalization, '/api/v1/personalization/concepts/record', 'iOS learner-record endpoint');
requireText(iosPersonalization, '/api/v1/lyo2/chat/reviews/due', 'iOS canonical due-review endpoint');
requireText(iosClassroom, 'URLQueryItem(name: "review_concept_id"', 'iOS review socket carries canonical concept ID');
requireText(iosClassroomView, 'reviewConceptId: reviewConceptId', 'iOS view forwards canonical review concept');
requireText(read('Sources/Services/UIStackStore.swift'), 'getDueReviews()', 'iOS Focus reads canonical due schedule');
rejectText(read('Sources/Services/UIStackStore.swift'), 'next.spacedRepetitionDue', 'iOS review cards inferred from generic next action');
requireText(iosPersonalizationModels, 'struct LearnerEvidenceRecord', 'iOS learner-record contract');
requireText(iosClassroomView, 'What you\'ve shown', 'iOS learner-record UI');
requireText(iosModels, 'targetConcepts = "target_concepts"', 'iOS scene concept identity');
requireText(androidApi, 'api/v1/personalization/concepts/record', 'Android learner-record endpoint');
requireText(androidLivingEngine, 'learnerRecord = ApiClient.api.learnerEvidenceRecord()', 'Android learner-record fetch');
requireText(androidChrome, 'What you\'ve shown', 'Android learner-record UI');
requireText(androidLivingEngine, 'event.metadata?.target_concepts', 'Android scene concept identity');

// Android longitudinal return loop uses the same server schedule as web/iOS.
requireText(androidApi, 'api/v1/lyo2/chat/reviews/due', 'Android canonical due-review endpoint');
requireText(androidHome, 'ApiClient.api.dueReviews()', 'Android Focus reads due reviews');
requireText(androidHome, 'Routes.reviewClassroom(', 'Android due review enters shared classroom');
requireText(androidNavigation, 'const val REVIEW_CLASSROOM', 'Android has a dedicated review classroom route');
requireText(androidNavigation, 'teachingMode = "review"', 'Android review destination preserves retrieval mode');
requireText(androidNavigation, 'reviewConceptId = entry.arguments?.getString("reviewConceptId")', 'Android review route carries canonical concept identity');
requireText(androidSocket, 'addQueryParameter("review_concept_id"', 'Android review socket sends canonical concept identity');
requireText(webContract, "params.set('review_concept_id'", 'Web review socket sends canonical concept identity');
requireText(webDueReviews, 'reviewEntryHref(label, item.skill_id)', 'Chat due review preserves canonical concept identity');
rejectText(webDueReviews, 'sendMessage(', 'Chat due review must not create a second unscoped review implementation');
for (const [source, label] of [
  [iosClassroomView, 'iOS learner record'],
  [androidChrome, 'Android learner record'],
]) {
  requireText(source, 'not shown yet', `${label} unreached-rung honesty`);
  rejectText(source, 'time spent means', `${label} fabricated mastery`);
}

// ── Classroom presentation contract ─────────────────────────────────────────
// These literals intentionally make accidental visual regressions fail CI.
// Mutation checks: remove the caption target, restore revealedWords, reduce a
// touch target below 44/48, or reintroduce a false web-parity comment and this
// gate must fail.
requireText(webPage, 'data-classroom-caption-target', 'Web single caption mount');
rejectText(webPage, 'revealedWords', 'Web duplicate caption renderer');
// The caption window is two lines with audio and three without. It used to be
// pinned here as `line-clamp-2` / `line-clamp-3`, which fixed the height by
// fixing the *mechanism* — and that mechanism was the bug: a clamp keeps the
// first lines that fit, so everything the teacher said past line two was
// painted out of sight and the strip froze on its opening words.
//
// So these pin the sizes, which are the parity contract, and leave how the
// window holds them to the implementation. The heights are the line-height
// multiplied by the number of lines: 2x20 / 2x22 with audio, 3x24 / 3x28
// without.
requireText(webCaption, 'max-h-10', 'Web two-line audio caption');
requireText(webCaption, 'sm:max-h-[44px]', 'Web two-line audio caption at sm');
requireText(webCaption, 'max-h-[72px]', 'Web silent-mode teaching caption');
requireText(webCaption, 'sm:max-h-[84px]', 'Web silent-mode teaching caption at sm');
rejectText(webCaption, 'line-clamp-', 'Web caption must not hide later words');
requireText(webPage, 'min-h-11 min-w-11', 'Web permanent exit touch target');
requireText(webPage, '> Challenge', 'Web Challenge action');
requireText(webPage, '> Raise hand', 'Web Raise hand action');
rejectText(webPage, 'Harder case', 'Web obsolete action label');
requireText(androidChrome, 'heightIn(min = 48.dp)', 'Android action touch targets');
requireText(androidChrome, 'Text("Challenge")', 'Android Challenge action');
requireText(androidChrome, 'maxLines = 2', 'Android two-line caption');

for (const [source, label] of [
  [iosView, 'iOS active lesson'],
  [iosClassroomView, 'iOS living classroom'],
  [androidChrome, 'Android chrome'],
  [androidLivingClassroom, 'Android living classroom'],
]) {
  rejectText(source, "matching the web classroom's", `${label} false parity claim`);
}

rejectText(iosLegacyViewModel, 'createMockQuickCheck', 'iOS hardcoded quick check');
rejectText(iosLegacyViewModel, 'Which part of y = mx + b', 'iOS algebra-only quick check');
requireText(iosLegacyModel, 'let quickCheck: QuickCheck?', 'iOS authored quick check contract');
rejectText(iosLegacyOverlay, 'Simplified for now', 'iOS tap-to-order stub');
rejectText(iosLegacyOverlay, 'Interactive Diagram', 'iOS diagram stub');

// ── iOS teaches through exactly one classroom ────────────────────────────────
//
// iOS carried four classroom entry points. LivingClassroomView is the only one
// MainTabView, EnhancedLyoHomeView or DiscoverView ever routed to; the other
// three were unreachable code that would drift out of step with the shared
// contract precisely because nothing exercised them.
//
// LivingClassroomEngine is the important one to keep out. It was an on-device
// teaching loop added because the server-pushed classroom could dead-end. That
// is a real failure worth fixing, but fixing it on the client makes iOS a
// pedagogically different product from web and Android — the safe fallback
// belongs server-side.
const REMOVED_IOS_CLASSROOMS = [
  'Sources/Services/LivingClassroomEngine.swift',
  'Sources/Services/LyoClassroomService.swift',
  'Sources/ViewModels/AgenticClassroomViewModel.swift',
  'Sources/Views/Main/Classroom/AgenticClassroomView.swift',
];

for (const path of REMOVED_IOS_CLASSROOMS) {
  if (existsSync(new URL(`../${path}`, import.meta.url))) {
    failures.push(`iOS classroom convergence: ${path} is back — one classroom, one contract`);
  }
}

// ── iOS study plans: no pretend persistence ─────────────────────────────────
//
// StudyPlanService claimed to persist a learner's study plan and did not. It
// POSTed to /api/v1/me/study_plans, which the server registers for GET only,
// so every call was a 405 that `try?` swallowed; and StudyPlanRecord could not
// have decoded a real response anyway (`id` is a UUID string on the wire, not
// an Int, and subject/topics/daily_breakdown are not on StudyPlanRead).
//
// Code that looks like persistence and is not hides the gap it leaves. The
// server does build durable plans, through intake/turn then plans/generate,
// and iOS is now wired to exactly that — see Sources/Services/TestPrepService.swift
// and §3k of verify-product-trust.mjs, which holds the new surface to the same
// rules as the web one. These entries stay so the broken pair cannot return
// alongside it.
const REMOVED_IOS_STUDY_PLANS = [
  'Sources/Services/StudyPlanService.swift',
  'Sources/Models/StudyPlanRecord.swift',
];

for (const path of REMOVED_IOS_STUDY_PLANS) {
  if (existsSync(new URL(`../${path}`, import.meta.url))) {
    failures.push(
      `iOS study plans: ${path} is back — it never persisted anything (see docs/CLASSROOM_ARCHITECTURE.md §7.4)`
    );
  }
}

// The specific call that 405'd. A client may read the plan list from this
// path; creating one goes through the intake flow, never a POST here.
for (const [file, label] of [
  ['Sources/Core/Networking/Endpoint.swift', 'iOS endpoints'],
  ['Sources/Views/Main/Hybrid/LyoOverlayView.swift', 'iOS chat overlay'],
]) {
  const source = read(file);
  if (/case\s+\.create:\s*\n\s*return\s+"\/api\/v1\/me\/study_plans"/.test(source)) {
    failures.push(`${label}: POST /api/v1/me/study_plans is a 405 — the server registers GET only`);
  }
}

// ── iOS opens the Classroom on a scheduled session the one agreed way ──────
//
// A study session carries a human `topic` and the `concept_id` the learner's
// record uses. The topic is what travels to the Classroom: the server derives
// the concept from it with the same slug rule that produced `concept_id`, so
// the evidence lands where readiness will look for it. Sending the slug
// instead would have the Classroom announce "long_division" to a learner, and
// sending a prose objective as the identity is the bug fixed in the companion
// backend change.
//
// `GENERATE:` is this app's existing convention for a topic with no course
// behind it. Reusing it rather than inventing a second way in is Phase C.
const iosTestPrepRules = read('Sources/Models/TestPrepPresentation.swift');

if (!/GENERATE:\\\(topic\)/.test(iosTestPrepRules)) {
  failures.push(
    'iOS test prep: a scheduled session must open the Classroom through the '
      + 'existing GENERATE: topic convention'
  );
}
if (/courseId:\s*"?\bGENERATE:\\\(session\.conceptId\)/.test(iosTestPrepRules)) {
  failures.push(
    'iOS test prep: the Classroom is opened on the concept slug — a learner '
      + 'should never be shown "long_division" as their topic'
  );
}

// ── A class starts, and a stuck one can be left ───────────────────────────
//
// The live teaching session is keyed server-side by `session_id`, and the
// engine stores the learner's place inside it. Every client used to send the
// course id (or, for a free topic, the topic text), which meant the id never
// changed: opening the same topic a second time handed back the session the
// learner left, mid-unit, with no opening and no way to ask for a clean
// start. It was worst after a failed step, because the broken session was the
// one that came back every time.
//
// Three platforms disagreeing about when a class starts, when it may resume,
// or how long a step may go missing before the class admits it is three
// different products. The rules live in one file per platform; these are the
// assertions that keep the three files saying the same thing.
const webSessionContract = read('web/src/lib/classroom-contract.mjs');
const iosSessionContract = read('Sources/Models/ClassroomSessionContract.swift');
const androidSessionContract = read(
  'android/app/src/main/java/com/lyo/app/data/classroom/ClassroomSessionContract.kt',
);
const androidEngine = androidLivingEngine;

const sessionContracts = [
  ['Web session contract', webSessionContract],
  ['iOS session contract', iosSessionContract],
  ['Android session contract', androidSessionContract],
];

for (const [label, source] of sessionContracts) {
  // The storage key, so a seat saved by one surface is the seat another finds.
  requireText(source, 'lyo_classroom_session:', `${label}: shared session storage key`);
  // A second class on a topic is a second session, not the first one resumed.
  requireText(source, '~', `${label}: a repeat entry needs its own session id`);
  // The copy a learner reads when a step never arrives. Identical on purpose:
  // a stalled lesson must not feel like three different failures.
  requireText(source, 'not a wrong answer', `${label}: stall recovery wording`);
  requireText(source, 'stop Lyo at any time', `${label}: opening card wording`);
  requireText(source, 'Understand and apply ', `${label}: default objective`);
}

// The two thresholds, as numbers, on all three. A platform that waits twice
// as long as another is a platform that looks broken next to it.
requireText(webSessionContract, 'CLASSROOM_STALL_NOTICE_MS = 12000', 'Web stall notice threshold');
requireText(
  webSessionContract, 'CLASSROOM_STALL_RECOVERY_MS = 30000', 'Web stall recovery threshold',
);
requireText(iosSessionContract, 'stallNoticeSeconds: TimeInterval = 12', 'iOS stall notice threshold');
requireText(
  iosSessionContract, 'stallRecoverySeconds: TimeInterval = 30', 'iOS stall recovery threshold',
);
requireText(androidSessionContract, 'STALL_NOTICE_MS = 12_000L', 'Android stall notice threshold');
requireText(
  androidSessionContract, 'STALL_RECOVERY_MS = 30_000L', 'Android stall recovery threshold',
);

// The one thing the nudge may never be. Re-sending the learner's own answer
// because the first one was slow coming back is a second attempt on their
// record for a failure that was not theirs.
requireText(web, "sendAction('continue', get().nextActionComponentId", 'Web stall nudge is continue');
requireText(
  iosClassroom, 'sendUserAction(actionIntent: "continue", componentId: "continue")',
  'iOS stall nudge is continue',
);
requireText(
  androidEngine, 'ClassroomBridge.continueLessonAction(sessionId, "continue", "android_continue")',
  'Android stall nudge is continue',
);

// Progress belongs to the course, not to this particular class — otherwise
// starting a lesson over starts the learner's progress over with it.
requireText(web, 'updateCourseProgress(get().courseId', 'Web progress is filed under the course');
requireText(
  androidEngine, 'StackRepository.updateCourseProgress(courseId,',
  'Android progress is filed under the course',
);

// The route must not pin the session it connects with.
//
// A surface knows which *course* a learner opened; which server session they
// land in is classroomSessionStart's decision, made from that course's own
// history. The web page used to pass the course id as `sessionId`, which took
// the explicit-session branch on every entry and left the whole generation
// rule unreachable in the running app — repeat visits kept sending the
// original id, `resume=1` did nothing, and every connect reset the saved
// generation. Every store test passed throughout, because none of them sent
// the shape the page actually sent.
rejectText(webPage, 'sessionId: courseId', 'Web entry pins the session instead of resolving it');
requireText(webPage, 'courseId,', 'Web entry carries the course');

// A finished class is not an unfinished one. Without this a learner who sat a
// lesson to its dismissal and reopened the topic within the resume window was
// told they had an unfinished class, and taking the offer would have dropped
// them on its last screen.
for (const [label, source] of sessionContracts) {
  requireText(source, 'finished', `${label}: a finished class is not resumable`);
}

// Every surface offers the seat back rather than imposing it, and can walk
// away from a session that cannot produce its next step.
requireText(web, 'resumeLesson', 'Web resume offer');
requireText(web, 'restartLesson', 'Web lesson restart');
requireText(iosClassroom, 'func resumeLesson', 'iOS resume offer');
requireText(iosClassroom, 'func restartLesson', 'iOS lesson restart');
requireText(androidEngine, 'resumableSession', 'Android resume offer');
requireText(androidLivingClassroom, 'sessionAttempt += 1', 'Android lesson restart');

if (failures.length) {
  console.error('AI Classroom parity gate failed:\n');
  failures.forEach((failure) => console.error(`- ${failure}`));
  process.exit(1);
}

console.log(
  'AI Classroom voice, locale, interruption, learner-gating, session-start and '
    + 'stall-recovery parity verified.'
);
