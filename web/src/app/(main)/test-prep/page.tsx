'use client';

import { useCallback, useEffect, useReducer, useRef, useState } from 'react';
import Link from 'next/link';
import { CalendarClock, GraduationCap, Loader2, Play, Send, Target } from 'lucide-react';

import { api } from '@/lib/api';
import { useApi } from '@/hooks/use-api';
import { cn } from '@/lib/utils';
import { useAuthStore } from '@/stores/auth-store';
import { streakFrom } from '@/lib/learner-stats.mjs';
import { buildKpis } from '@/lib/test-prep-view.mjs';
import { WorkspaceHeader } from '@/components/test-prep/WorkspaceHeader';
import { CoachHero } from '@/components/test-prep/CoachHero';
import { ScheduleCard } from '@/components/test-prep/ScheduleCard';
import { MaterialsCard } from '@/components/test-prep/MaterialsCard';
import {
  completionSummary,
  daysLabel,
  intakeIsComplete,
  openSessions,
  readinessHeadline,
  sessionEntryHref,
  topicStanding,
} from '@/lib/test-prep.mjs';
import {
  canStartIntake,
  initialState,
  readinessNote,
  staleWarning,
  testPrepReducer,
  todayCopy,
} from '@/lib/test-prep-state.mjs';
import type { ReadinessPayload, StudySessionRow } from '@/types';
import { PrepManagement } from '@/components/test-prep/PrepManagement';
import type { PrepMaterial, PrepProfile, PrepSnapshot } from '@/lib/test-prep-api';
import type { CoachToday } from '@/lib/coach-api';
import { goalForTestProfile } from '@/lib/coach.mjs';
import CoachMissionEntry from '@/components/coach/CoachMissionEntry';

/**
 * Test Prep — the face on a learner loop that had none.
 *
 * The server has been able to answer "how ready am I for Friday, and what
 * should I do first" since Phase E, and no client asked. Worse, no client
 * could create the plan it reports on: the only writers of TestProfile,
 * StudyPlan and StudySession are `intake_turn` and `plans/generate`, and
 * nothing called either, so those tables were empty for every learner on
 * every platform.
 *
 * So this page is both halves. A learner with no plan is asked about their
 * test — the server's own intake coach, one question at a time — and the
 * answers become a real plan with scheduled sessions. A learner with a plan
 * sees where they actually stand and can step from a session straight into
 * the Classroom.
 *
 * What it will not do is show a number nobody measured. A plan with nothing
 * assessed yet carries a readiness of 0, and "0% ready" is a claim about a
 * person that no evidence supports. The rules for that live in
 * `test-prep.mjs`, tested, because they are exactly the rules this codebase
 * keeps getting wrong.
 *
 * See docs/CLASSROOM_ARCHITECTURE.md §7.5.
 */

type Turn = { role: 'coach' | 'learner'; text: string };

export default function TestPrepPage() {
  const { isAuthenticated, isLoading: authLoading, user, authVerificationError, hydrate } = useAuthStore();
  // The streak is the one KPI this page does not already fetch. It waits for
  // authentication to settle, because `/gamification/overview` is a
  // required-auth call: a signed-out visitor's 401 takes `request()`'s
  // default branch, which clears tokens and sends the browser to
  // `/auth/login` — so firing it on mount made this page's own
  // sign-in/sign-up screen unreachable for the guests it was written for.
  // Beyond that it stays supplementary: a failure leaves `gamification` null,
  // `streakFrom` reads that as no streak, and the tile says "Day 1" rather
  // than blocking or blanking the rest of the strip.
  const { data: gamification } = useApi(
    !authLoading && isAuthenticated ? () => api.gamification.overview() : null,
    [authLoading, isAuthenticated],
  );

  // One reducer rather than eighteen useStates. Four consecutive review
  // findings on this page were different combinations of that state, the last
  // of them a defect in the fix for the one before — the same shape as the
  // 401 branch, and the same remedy: put the transitions somewhere they can
  // be unit-tested. See test-prep-state.mjs.
  const [state, dispatch] = useReducer(testPrepReducer, initialState);
  const { loading, stage, planId, readiness, sessions, finishing, notice } = state;
  const failed = state.planLoadFailed;

  // Intake conversation
  const [turns, setTurns] = useState<Turn[]>([]);
  const [profileId, setProfileId] = useState<string | undefined>(undefined);
  const [draft, setDraft] = useState('');
  const [sending, setSending] = useState(false);
  const [building, setBuilding] = useState(false);
  const [snapshot, setSnapshot] = useState<PrepSnapshot | null>(null);
  const [coach, setCoach] = useState<CoachToday | null>(null);
  const [coachFailed, setCoachFailed] = useState(false);
  const [materials, setMaterials] = useState<PrepMaterial[]>([]);
  const [uploading, setUploading] = useState(false);
  const [intakeError, setIntakeError] = useState<string | null>(null);
  const [profiles, setProfiles] = useState<PrepProfile[]>([]);
  const [returnedSessionId, setReturnedSessionId] = useState<string | null>(null);
  const [startingNew, setStartingNew] = useState(false);
  const [startError, setStartError] = useState<string | null>(null);
  // The details form is revealed by the workspace header's pencil, so the
  // page owns whether it is open rather than the form owning its own toggle.
  const [editingDetails, setEditingDetails] = useState(false);
  const selectedProfileIdRef = useRef<string | null>(null);
  const selectionVersionRef = useRef(0);
  const mountedRef = useRef(true);
  // A learner can keep multiple exams open. Older asynchronous responses must
  // never paint the details of a different test over the current selection.
  const loadVersionRef = useRef(0);
  // Preserve this ID across a network timeout to make Retry idempotent.
  const pendingNewTestIdRef = useRef<string | null>(null);
  const retryTurn = useRef<{ text: string; id: string } | null>(null);
  const busy = useRef(false);

  useEffect(() => {
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
      selectionVersionRef.current++;
      loadVersionRef.current++;
    };
  }, []);

  const selectionIsCurrent = useCallback((version: number) =>
    mountedRef.current && version === selectionVersionRef.current, []);

  const selectProfile = (id: string) => {
    selectedProfileIdRef.current = id;
    setReturnedSessionId(null);
    const url = new URL(window.location.href);
    url.searchParams.delete('sessionId');
    window.history.replaceState(window.history.state, '', url.toString());
    const version = ++selectionVersionRef.current;
    loadVersionRef.current++;
    dispatch({ type: 'profile_selected' });
    setSnapshot(null);
    setProfileId(undefined);
    setTurns([]);
    setMaterials([]);
    setDraft('');
    setIntakeError(null);
    setStartError(null);
    // The form is bound to one test's revision. Leaving it open across a
    // switch would show the previous test's values over the new one.
    setEditingDetails(false);
    setCoach(null);
    setCoachFailed(false);
    retryTurn.current = null;
    return version;
  };

  const loadPlan = useCallback(async () => {
    const version = ++loadVersionRef.current;
    const selection = selectionVersionRef.current;
    const requestedProfileId = selectedProfileIdRef.current;
    dispatch({ type: 'load_started' });
    try {
      let saved = await api.testPrep.state(requestedProfileId ?? undefined);
      if (!mountedRef.current || selection !== selectionVersionRef.current || version !== loadVersionRef.current) return;
      // Legacy no-ID reads intentionally omit completed/archived plans. The
      // web entry can select that returned profile explicitly to show history.
      if (!requestedProfileId && saved.profile?.intake_complete && !saved.plan) {
        saved = await api.testPrep.state(saved.profile.id);
        if (!mountedRef.current || selection !== selectionVersionRef.current || version !== loadVersionRef.current) return;
      }
      selectedProfileIdRef.current = saved.profile?.id ?? null;
      // A URL preserves the learner's selected exam on refresh and deep link.
      if (saved.profile?.id) {
        const url = new URL(window.location.href);
        url.searchParams.set('profileId', saved.profile.id);
        window.history.replaceState(window.history.state, '', url.toString());
      }
      // A failed history request must not hide the selected exam or its lessons.
      void api.testPrep.profiles().then(list => {
        if (mountedRef.current && selection === selectionVersionRef.current && version === loadVersionRef.current) setProfiles(list);
      }).catch(() => undefined);
      setSnapshot(saved);
      setProfileId(saved.profile?.id);
      setTurns((saved.profile?.intake_transcript ?? []).map(t => ({
        role: t.role === 'user' ? 'learner' : 'coach', text: t.content,
      })));
      const plan = saved.plan;
      if (!plan) {
        dispatch({ type: 'no_plan' });
        return;
      }
      dispatch({ type: 'plan_loaded', planId: plan.id });

      // Settled rather than all: one failing must not blank the other, and
      // neither may be replaced by a placeholder.
      const [readinessResult, sessionsResult, coachResult] = await Promise.allSettled([
        api.testPrep.readiness(plan.id),
        api.testPrep.todaySessions(),
        api.coach.today(),
      ]);
      if (!mountedRef.current || selection !== selectionVersionRef.current || version !== loadVersionRef.current) return;
      if (coachResult.status === 'fulfilled') {
        setCoach(coachResult.value);
        setCoachFailed(false);
      } else {
        // Supplementary orchestration must never erase the working Test Prep
        // schedule. Keep the last valid mission and label it stale.
        setCoachFailed(true);
      }
      dispatch({
        type: 'details_loaded',
        readiness: readinessResult.status === 'fulfilled' ? readinessResult.value : undefined,
        sessions: sessionsResult.status === 'fulfilled'
          ? (sessionsResult.value ?? []).filter((session) => saved.sessions.some((s) => s.id === session.id))
          : undefined,
      });
    } catch {
      if (mountedRef.current && selection === selectionVersionRef.current && version === loadVersionRef.current) dispatch({ type: 'load_failed' });
    } finally {
      if (mountedRef.current && selection === selectionVersionRef.current && version === loadVersionRef.current) dispatch({ type: 'load_settled' });
    }
  }, []);

  useEffect(() => {
    if (authLoading) return;
    if (!isAuthenticated) {
      // A guest has nothing to load; leaving `loading` true would hold them
      // on the spinner forever.
      dispatch({ type: 'load_settled' });
      return;
    }
    // Read the selected profile before the first state request. Without this
    // deep-link restoration a refresh silently switches to the newest exam.
    const query = new URLSearchParams(window.location.search);
    selectedProfileIdRef.current = query.get('profileId');
    setReturnedSessionId(query.get('sessionId'));
    void loadPlan();
  }, [authLoading, isAuthenticated, loadPlan]);

  const sendTurn = useCallback(
    async (message: string) => {
      const text = message.trim();
      if (!text || busy.current || uploading || startingNew) return;
      const selection = selectionVersionRef.current;
      // Checked here and not only on the controls. This call ends in
      // `plans/generate`, which creates a plan unconditionally, and a plan
      // must not be created while we do not know whether one already exists.
      if (!canStartIntake(state)) return;
      setSending(true);
      busy.current = true;
      setIntakeError(null);
      if (retryTurn.current?.text !== text) {
        retryTurn.current = { text, id: crypto.randomUUID() };
        setTurns((prev) => [...prev, { role: 'learner', text }]);
      }
      setDraft('');
      try {
        const turn = await api.testPrep.intakeTurn(text, profileId, materials, retryTurn.current.id);
        if (!selectionIsCurrent(selection)) return;
        retryTurn.current = null;
        setMaterials([]);
        setProfileId(turn.test_profile_id);
        selectedProfileIdRef.current = turn.test_profile_id;
        setTurns((prev) => [...prev, { role: 'coach', text: turn.message_to_user }]);

        // The server decides when it has enough, not a turn count here.
        if (intakeIsComplete(turn)) {
          setBuilding(true);
          await api.testPrep.generatePlan(turn.test_profile_id);
          if (!selectionIsCurrent(selection)) return;
          await loadPlan();
        }
      } catch (error) {
        if (!selectionIsCurrent(selection)) return;
        setIntakeError(error instanceof Error ? error.message : 'Your message could not be sent. Please retry.');
        setDraft(text);
        // Reload server-owned state: a timeout may have occurred after saving.
        await loadPlan();
      } finally {
        if (selectionIsCurrent(selection)) {
          busy.current = false;
          setSending(false);
          setBuilding(false);
        }
      }
    },
    [loadPlan, profileId, materials, state, uploading, startingNew, selectionIsCurrent]
  );

  const finishSession = useCallback(
    async (sessionId: string) => {
      if (finishing) return;
      const selection = selectionVersionRef.current;
      dispatch({ type: 'finish_started', sessionId });
      try {
        const summary = completionSummary(await api.testPrep.completeSession(sessionId));
        if (!selectionIsCurrent(selection)) return;

        // Say what the server measured, including when it measured nothing.
        // The client sends no score and must not imply one: "done" with a
        // silent 0% would be the fabrication this endpoint was fixed to stop.
        const text =
          summary.kind === 'scored'
            ? `Scored ${summary.percent}% from ${summary.graded} graded ${
                summary.graded === 1 ? 'answer' : 'answers'
              }.`
            : summary.kind === 'unscored'
              ? 'Marked done. Nothing in this session was graded, so there is no score — answer a check in the Classroom and it will count.'
              : summary.kind === 'empty'
                ? 'Marked done. Nothing was recorded for this session.'
                : 'Marked done, but I could not read what was measured.';

        setSnapshot(saved => saved ? { ...saved, sessions: saved.sessions.map(session =>
          session.id === sessionId ? { ...session, status: 'completed' } : session) } : saved);
        dispatch({ type: 'finish_succeeded', sessionId, notice: text });
        await loadPlan();
      } catch {
        if (!selectionIsCurrent(selection)) return;
        dispatch({
          type: 'finish_failed',
          notice: 'I could not mark that done just now.',
        });
      }
    },
    [finishing, loadPlan, selectionIsCurrent]
  );

  const startNewTest = async () => {
    if (busy.current || startingNew || uploading || finishing) return;
    busy.current = true;
    let selection = selectionVersionRef.current;
    setStartingNew(true);
    setStartError(null);
    const requestId = pendingNewTestIdRef.current ?? crypto.randomUUID();
    pendingNewTestIdRef.current = requestId;
    try {
      const created = await api.testPrep.startNew(requestId);
      if (!selectionIsCurrent(selection)) return;
      pendingNewTestIdRef.current = null;
      selection = selectProfile(created.profile_id);
      await loadPlan();
    } catch {
      if (!selectionIsCurrent(selection)) return;
      setStartError('Could not create a new test. Your existing test was not changed. Try again.');
    } finally {
      if (selectionIsCurrent(selection)) {
        busy.current = false;
        setStartingNew(false);
      }
    }
  };

  // This is navigation, not modification: switching tests must never change
  // the old plan, its schedule, or its demonstrated mastery.
  const testSwitcher = (
    <div className="mb-6 flex flex-wrap items-center gap-3">
      {profiles.length > 0 && (
        <label className="flex min-w-0 flex-col gap-1 text-xs font-medium text-white/60">
          Your tests
          <select
            aria-label="Choose a test"
            value={selectedProfileIdRef.current ?? snapshot?.profile?.id ?? ''}
            disabled={startingNew || sending || building || uploading || !!finishing}
            onChange={(event) => {
              if (busy.current || uploading || finishing) return;
              selectProfile(event.target.value);
              void loadPlan();
            }}
            className="max-w-[240px] rounded-lg border border-white/20 bg-gray-900 px-3 py-2 text-sm text-white"
          >
            {profiles.map((profile) => (
              <option key={profile.id} value={profile.id}>
                {profile.subject === 'Pending Test' ? 'New test (in progress)' : profile.subject}
                {profile.test_date && profile.subject !== 'Pending Test' ? ` — ${profile.test_date}` : ''}
              </option>
            ))}
          </select>
        </label>
      )}
      <button
        type="button"
        onClick={() => void startNewTest()}
        disabled={startingNew || sending || building || uploading || !!finishing}
        className="rounded-xl border border-violet-400/40 bg-violet-500/15 px-4 py-2.5 text-sm font-semibold text-white hover:bg-violet-500/25 disabled:opacity-50"
      >
        {startingNew ? 'Starting new test…' : '+ New test'}
      </button>
      {startError && <p role="alert" className="w-full text-xs text-amber-200">{startError}</p>}
    </div>
  );

  if (authLoading || loading) {
    return (
      <main className="mx-auto max-w-2xl px-4 py-16 text-center text-white/60">
        {isAuthenticated && testSwitcher}
        <Loader2 className="mx-auto h-6 w-6 animate-spin" aria-hidden />
        <p className="mt-3 text-sm">Loading your test prep…</p>
      </main>
    );
  }

  if (!isAuthenticated && authVerificationError) {
    return (
      <main className="mx-auto max-w-2xl px-4 py-16" role="status">
        <h1 className="text-2xl font-semibold text-white">Session verification unavailable</h1>
        <p className="mt-3 text-white/70">Your session could not be verified right now. Retry to reopen your selected exam.</p>
        <button type="button" onClick={() => void hydrate()} className="mt-6 rounded-xl bg-white px-5 py-3 font-medium text-black">
          Retry verification
        </button>
      </main>
    );
  }
  if (!isAuthenticated) {
    return (
      <main className="mx-auto max-w-2xl px-4 py-16">
        <h1 className="text-2xl font-semibold text-white">Get ready for your test</h1>
        <p className="mt-3 text-white/70">
          Sign in to tell Lyo about your test, build a study plan, and pick up where you left off.
        </p>
        <div className="mt-6 flex flex-wrap gap-3">
          <Link
            href="/auth/login?next=%2Ftest-prep"
            className="rounded-xl bg-white px-5 py-3 font-medium text-black"
          >
            Sign in
          </Link>
          <Link
            href="/auth/signup?next=%2Ftest-prep"
            className="rounded-xl border border-white/15 px-5 py-3 font-medium text-white"
          >
            Create account
          </Link>
        </div>
      </main>
    );
  }

  if (stage === 'intake') {
    return (
      <main className="mx-auto max-w-2xl px-4 py-10">
        {testSwitcher}
        <h1 className="text-2xl font-semibold text-white">Tell me about your test</h1>
        <p className="mt-2 text-sm text-white/60">
          A few questions — the subject, the date, what&apos;s on it — and I&apos;ll build you a
          plan with real sessions.
        </p>
        {/* Not a warning beside a live composer. Intake ends in
            `plans/generate`, which creates a plan unconditionally — so a
            learner who already has one would come out with a second, because
            a request happened to fail. The way forward is to find out. */}
        {failed && (
          <div className="mt-4 rounded-xl border border-amber-400/30 bg-amber-400/10 px-4 py-3 text-sm text-amber-200">
            <p>
              I couldn&apos;t check whether you already have a plan. Let me try again
              before we start a new one.
            </p>
            <button
              type="button"
              onClick={() => void loadPlan()}
              className="mt-2 rounded-lg bg-amber-400/20 px-3 py-1.5 font-medium text-amber-100 hover:bg-amber-400/30"
            >
              Try again
            </button>
          </div>
        )}

        <div className="mt-6 space-y-3">
          {turns.length === 0 && !failed && <p className="rounded-2xl bg-white/[0.06] px-4 py-3 text-white/90">What subject is your test?</p>}
          {turns.map((turn, index) => (
            <div
              key={`${turn.role}-${index}`}
              className={
                turn.role === 'coach'
                  ? 'rounded-2xl bg-white/[0.06] px-4 py-3 text-white/90'
                  : 'ml-auto max-w-[85%] rounded-2xl bg-white/15 px-4 py-3 text-white'
              }
            >
              {turn.text}
            </div>
          ))}
          {sending && (
            <div className="flex items-center gap-2 text-sm text-white/50">
              <Loader2 className="h-4 w-4 animate-spin" aria-hidden />
              {building ? 'Building your plan…' : 'Thinking…'}
            </div>
          )}
        </div>

        {intakeError && <p role="alert" className="mt-4 text-amber-200">{intakeError}</p>}
        {/* Intake has no workspace header to hang the pencil off, so the
            toggle that used to live inside PrepManagement lives here. */}
        {snapshot?.profile?.intake_complete && (
          <>
            <button
              type="button"
              onClick={() => setEditingDetails(!editingDetails)}
              aria-expanded={editingDetails}
              className="mt-5 rounded-xl border border-white/20 px-4 py-2.5 text-sm text-white transition hover:bg-white/[0.07]"
            >
              {editingDetails ? 'Close details' : 'Edit test details'}
            </button>
            <div className="mt-4">
              <PrepManagement
                snapshot={snapshot}
                onSaved={loadPlan}
                open={editingDetails}
                onClose={() => setEditingDetails(false)}
              />
            </div>
          </>
        )}
        {snapshot?.profile?.intake_complete && (
          <button className="mt-4 rounded-xl bg-violet-600 px-5 py-3 text-white disabled:opacity-50"
            disabled={building} onClick={async () => {
              if (!profileId || busy.current) return;
              const selection = selectionVersionRef.current;
              busy.current = true; setBuilding(true); setIntakeError(null);
              try { await api.testPrep.generatePlan(profileId); if (selectionIsCurrent(selection)) await loadPlan(); }
              catch (e) { if (selectionIsCurrent(selection)) setIntakeError(e instanceof Error ? e.message : 'Could not build your plan.'); }
              finally { if (selectionIsCurrent(selection)) { busy.current = false; setBuilding(false); } }
            }}>{building ? 'Building your plan…' : 'Build my saved plan'}</button>
        )}
        <label className="mt-4 block text-sm text-white/70">Add notes, a photo or a PDF
          <input type="file" accept="image/png,image/jpeg,image/webp,application/pdf,text/plain" disabled={sending || uploading || building || startingNew || failed}
            className="mt-2 block w-full text-sm" onChange={async event => {
              const file = event.target.files?.[0];
              if (!file) return;
              const selection = selectionVersionRef.current;
              setUploading(true); setIntakeError(null);
              try {
                const uploaded = await api.media.upload(file, 'test-prep');
                if (!selectionIsCurrent(selection)) return;
                setMaterials(prev => [...prev, { name: file.name, uri: uploaded.url,
                  modality: file.type.startsWith('image/') ? 'IMAGE' : 'DOCUMENT', mime_type: file.type }]);
              } catch { if (selectionIsCurrent(selection)) setIntakeError('The file could not be uploaded. Please try again.'); }
              finally { if (selectionIsCurrent(selection)) setUploading(false); event.target.value = ''; }
            }} />
        </label>
        <p className="mt-2 text-sm text-white/60" aria-live="polite">{uploading ? 'Uploading…' : materials.map(m => m.name).join(', ')}</p>
        <form
          className="mt-6 flex gap-2"
          onSubmit={(event) => {
            event.preventDefault();
            void sendTurn(draft);
          }}
        >
          <input
            value={draft}
            onChange={(event) => setDraft(event.target.value)}
            placeholder="Type your answer…"
            aria-label="Your answer"
            disabled={startingNew || building || !canStartIntake(state)}
            className="flex-1 rounded-xl border border-white/10 bg-white/[0.04] px-4 py-3 text-white outline-none placeholder:text-white/40 disabled:opacity-40"
          />
          <button
            type="submit"
            disabled={sending || uploading || building || startingNew || !draft.trim() || !canStartIntake(state)}
            className="rounded-xl bg-white px-4 py-3 text-black disabled:opacity-40"
            aria-label="Send"
          >
            <Send className="h-4 w-4" aria-hidden />
          </button>
        </form>
      </main>
    );
  }

  // Every failure has somewhere to be said. `refreshFailed` was previously
  // set and rendered nowhere, which is how a failed refresh after finishing a
  // session became completely silent.
  const stale = staleWarning(state);
  const headline = readinessHeadline(readiness);
  const countdown = daysLabel(readiness?.days_remaining);
  const due = openSessions(sessions);
  // All four combinations of list and failure are decided in one place; this
  // section kept getting one branch right and another wrong.
  const today = todayCopy(state, due.length);
  // Its own sentence, on its own card. Readiness can fail while the plan, the
  // countdown and today's sessions all loaded; the page-level warning would
  // overstate one failed call, and saying nothing understates it — badly, in
  // the moment right after finishing a session.
  const readinessStale = readinessNote(state);
  const testGoal = goalForTestProfile(coach?.active_goals, profileId);
  const coachReadiness = testGoal ? coach?.readiness[testGoal.id] : undefined;
  const coachMission = testGoal
    ? (coach?.mission ?? []).filter(item => item.goal_id === testGoal.id)
    : [];

  // Four tiles, decided in one tested place. The rule they exist to hold is
  // the page's oldest one: a plan with nothing assessed reads "Not measured",
  // never "0%".
  const kpis = buildKpis({
    readiness,
    coachReadiness,
    profile: snapshot?.profile,
    streak: streakFrom(gamification, user),
    missionMinutes: coachMission.reduce((sum, item) => sum + item.estimated_minutes, 0),
    missionCount: coachMission.length,
    dueCount: due.length,
  });

  const controlsBusy = startingNew || sending || building || uploading || !!finishing;

  // The first thing a learner with a fresh plan can actually do: today's
  // session if there is one, else the next one still scheduled. A session with
  // no topic has no entry point, so it is skipped rather than linked nowhere.
  const firstSession =
    due.find((session) => sessionEntryHref(session)) ??
    (snapshot?.sessions ?? []).find(
      (session) => session.status === 'scheduled' && sessionEntryHref(session),
    );
  const firstSessionHref = firstSession ? sessionEntryHref(firstSession) : null;

  // 55/45 on a desktop, stacked on a phone. The basis values are what make it
  // wrap rather than a breakpoint: a column narrower than its basis cannot
  // share a row, so the same markup is two columns on a monitor and one on a
  // phone, with the bottom nav rather than the sidebar underneath it.
  const LEFT = 'min-w-0 flex-[55_1_600px]';
  const RIGHT = 'min-w-0 flex-[45_1_460px]';

  return (
    <div className="flex flex-col gap-[18px]">
      <WorkspaceHeader
        subject={snapshot?.profile?.subject ?? readiness?.subject ?? 'Your test'}
        profiles={profiles}
        selectedProfileId={selectedProfileIdRef.current ?? snapshot?.profile?.id ?? ''}
        onSelectProfile={(id) => {
          if (controlsBusy) return;
          selectProfile(id);
          void loadPlan();
        }}
        onNewTest={() => void startNewTest()}
        {...(snapshot?.profile ? { onEditDetails: () => setEditingDetails(!editingDetails) } : {})}
        editing={editingDetails}
        busy={controlsBusy}
        startingNew={startingNew}
        startError={startError}
        kpis={kpis}
      />

      {countdown && <p className="sr-only">{countdown}</p>}
      {returnedSessionId && snapshot?.profile?.id === profileId &&
        snapshot?.sessions.some(session => session.id === returnedSessionId) && (
        <p role="status" className="rounded-xl border border-violet-400/40 bg-violet-500/10 px-4 py-3 text-sm text-white/85">
          Returned to study session: <strong>{snapshot.sessions.find(session => session.id === returnedSessionId)?.topic}</strong>.
          {' '}Your exam and session are saved.
        </p>
      )}

      {stale && (
        <p className="rounded-2xl border border-amber-400/30 bg-amber-400/10 px-4 py-2.5 text-sm text-amber-200">
          {stale}
        </p>
      )}

      {notice && (
        <p className="rounded-2xl border border-white/10 bg-white/[0.04] px-4 py-3 text-sm text-white/80">
          {notice}
        </p>
      )}

      {snapshot && (
        <PrepManagement
          key={snapshot.profile?.id}
          snapshot={snapshot}
          onSaved={loadPlan}
          open={editingDetails}
          onClose={() => setEditingDetails(false)}
        />
      )}

      {/* ── Row 1: the coach, beside the plan ── */}
      <div className="flex flex-wrap items-start gap-[18px]">
        <div className={LEFT}>
          {coachReadiness || coachMission.length > 0 ? (
            <CoachHero
              coachReadiness={coachReadiness}
              mission={coachMission}
              goal={testGoal}
              profileId={profileId}
              sessions={snapshot?.sessions ?? []}
              coachFailed={coachFailed}
            />
          ) : (
            // No coach mission yet. This card still carries the weight of the
            // column beside it, so it says what the learner gets by starting
            // and gives them the way in — three lines of prose left a hole on
            // the left of the page the size of the schedule and materials.
            <section className="rounded-[22px] border border-lyo-400/25 bg-[linear-gradient(140deg,rgba(139,92,246,0.16)_0%,rgba(99,102,241,0.08)_45%,rgba(255,255,255,0.025)_100%)] p-6 sm:p-7">
              <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-lyo-300/85">Lyo Coach</p>
              <h2 className="mt-1.5 font-rounded text-[30px] font-extrabold leading-[1.1] text-white sm:text-4xl">
                Your plan is ready
              </h2>
              <p className="mt-3 max-w-[60ch] text-sm leading-6 text-white/75">
                You haven&apos;t been assessed on any of this yet, so there is no readiness score to
                show. Start the first session and this page fills in as you go.
              </p>

              {firstSessionHref && firstSession && (
                <CoachMissionEntry
                  session={firstSession}
                  goal={testGoal}
                  profileId={profileId}
                  origin="test_prep"
                  className="mt-5 inline-flex min-h-[44px] items-center gap-2 rounded-2xl bg-gradient-to-b from-white to-sky-50 px-5 py-3 text-sm font-bold text-violet-700 shadow-[0_5px_12px_rgba(0,0,0,0.2)] transition hover:to-white"
                >
                  <Play className="h-4 w-4 fill-current" aria-hidden />
                  Start your first session
                </CoachMissionEntry>
              )}

              <div className="mt-6 border-t border-white/10 pt-5">
                <h3 className="font-rounded text-xl font-bold text-white">What happens next</h3>
                <ol className="mt-4 flex flex-col gap-2.5">
                  {[
                    'Work through a session — Lyo watches what you actually get right.',
                    'Your topic bars and readiness start filling in from that evidence.',
                    'Each day you get a mission aimed at your weakest topics first.',
                  ].map((step, index) => (
                    <li
                      key={step}
                      className="flex items-center gap-3.5 rounded-[18px] border border-white/12 bg-black/[0.18] p-4"
                    >
                      <span
                        className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-white/12 text-[13px] font-bold text-white"
                        aria-hidden
                      >
                        {index + 1}
                      </span>
                      <span className="min-w-0 flex-1 text-sm text-white/85">{step}</span>
                    </li>
                  ))}
                </ol>
              </div>
            </section>
          )}
        </div>

        <div className={cn(RIGHT, 'flex flex-col gap-[18px]')}>
          {snapshot && <ScheduleCard snapshot={snapshot} goal={testGoal} profileId={profileId} returnedSessionId={returnedSessionId} />}
          {snapshot && <MaterialsCard snapshot={snapshot} onSaved={loadPlan} />}
        </div>
      </div>

      {/* ── Row 2: the evidence, beside today ── */}
      <div className="flex flex-wrap items-start gap-[18px]">
        <section className={cn(LEFT, 'rounded-[22px] border border-white/10 bg-gradient-to-br from-white/[0.06] to-white/[0.025] p-5 shadow-[0_6px_12px_rgba(0,0,0,0.18)] sm:p-6')}>
          <div className="flex flex-wrap items-center gap-2.5">
            <Target className="h-4 w-4 shrink-0 text-lyo-300" aria-hidden />
            <h3 className="font-rounded text-lg font-bold text-white">
              {coachReadiness ? 'Evidence by topic' : 'How ready you are'}
            </h3>
            <span className="flex-1" />
            {readiness && readiness.focus_next.length > 0 && (
              <span className="text-xs text-white/50">
                Start with <span className="font-semibold text-white">{readiness.focus_next[0]}</span>
              </span>
            )}
          </div>

          {readinessStale && <p className="mt-2 text-sm text-white/50">{readinessStale}</p>}

          {/* Each branch is a different claim. A plan with nothing assessed has
              a readiness of 0, and rendering that as "0%" would tell a learner
              they failed something nobody ever asked them. */}
          {!coachReadiness && headline.kind === 'measured' && (
            <p className="mt-2 font-rounded text-4xl font-extrabold text-white">{headline.percent}%</p>
          )}
          {!coachReadiness && headline.kind === 'unmeasured' && (
            <p className="mt-3 max-w-[80ch] text-base leading-6 text-white/80">
              You haven&apos;t been assessed on any of this yet — start a session and this will start
              filling in.
            </p>
          )}
          {!coachReadiness && headline.kind === 'unknown' && (
            <p className="mt-3 max-w-[80ch] text-base leading-6 text-white/80">
              {readiness
                ? 'This plan has no topics on it yet, so there is nothing to measure.'
                : 'I could not load your readiness just now.'}
            </p>
          )}

          {readiness && readiness.topics.length > 0 && (
            <ul className="mt-5 flex flex-col gap-3.5">
              {readiness.topics.map((topic) => {
                const standing = topicStanding(topic);
                // Narrowed to a number here rather than kept behind a boolean:
                // `standing.kind === 'measured'` stored in a variable does not
                // narrow the union for the reads further down.
                const percent = standing.kind === 'measured' ? standing.percent : null;
                const measured = percent !== null;
                return (
                  <li key={topic.concept_id}>
                    <div className="flex items-baseline gap-3">
                      <span className={cn('min-w-0 flex-1 truncate text-sm', measured ? 'text-white/90' : 'text-white/70')}>
                        {topic.topic}
                      </span>
                      {measured ? (
                        <span
                          className={cn(
                            'shrink-0 font-rounded text-sm font-bold',
                            percent >= 70
                              ? 'text-emerald-300'
                              : percent >= 50
                                ? 'text-lyo-300'
                                : 'text-amber-300',
                          )}
                        >
                          {percent}%
                        </span>
                      ) : (
                        <span className="shrink-0 text-xs text-white/50">Not started</span>
                      )}
                    </div>
                    {/* A never-assessed topic gets an empty track and no fill.
                        A 0%-wide bar and "no evidence yet" look identical and
                        are different claims. */}
                    <div className={cn('mt-1.5 h-[7px] overflow-hidden rounded-full', measured ? 'bg-white/[0.08]' : 'bg-white/[0.055]')}>
                      {measured && (
                        <div
                          className={cn(
                            'h-full rounded-full',
                            percent >= 70
                              ? 'bg-gradient-to-r from-emerald-500 to-emerald-400'
                              : percent >= 50
                                ? 'bg-gradient-to-r from-lyo-600 to-lyo-400'
                                : 'bg-gradient-to-r from-amber-600 to-amber-400',
                          )}
                          style={{ width: `${percent}%` }}
                        />
                      )}
                    </div>
                  </li>
                );
              })}
            </ul>
          )}

          <p className="mt-5 max-w-[80ch] text-xs leading-5 text-white/45">
            Measured from what you have actually demonstrated, not from sessions ticked off.
          </p>
        </section>

        <section className={cn(RIGHT, 'rounded-[22px] border border-white/10 bg-gradient-to-br from-white/[0.06] to-white/[0.025] p-5 shadow-[0_6px_12px_rgba(0,0,0,0.18)] sm:p-[22px]')}>
          <div className="flex flex-wrap items-center gap-2.5">
            <CalendarClock className="h-4 w-4 shrink-0 text-emerald-300" aria-hidden />
            <h3 className="font-rounded text-lg font-bold text-white">Today&rsquo;s sessions</h3>
          </div>

          {today.note && (
            <p className="mt-3 rounded-2xl border border-amber-400/30 bg-amber-400/10 px-4 py-2.5 text-sm text-amber-200">
              {today.note}
            </p>
          )}

          {today.emptyMessage ? (
            <p className="mt-3 text-sm text-white/60">{today.emptyMessage}</p>
          ) : (
            <ul className="mt-4 flex flex-col gap-2.5">
              {due.map((session) => {
                const href = sessionEntryHref(session);
                const body = (
                  <>
                    <GraduationCap className="h-4 w-4 shrink-0 text-white/50" aria-hidden />
                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-sm font-medium text-white">{session.topic}</span>
                      <span className="mt-0.5 block text-[11px] uppercase tracking-[0.06em] text-white/45">
                        {session.session_type.replace('_', ' ')} · {session.duration_minutes} min
                      </span>
                    </span>
                  </>
                );
                return (
                  <li key={session.id} id={`test-prep-session-${session.id}`}
                    className={cn('flex items-stretch gap-2.5', returnedSessionId === session.id && 'rounded-xl ring-2 ring-violet-400/70')}>
                    {href ? (
                      <CoachMissionEntry
                        session={session}
                        goal={testGoal}
                        origin="test_prep"
                        profileId={profileId}
                        wrapperClassName="min-w-0 flex-1"
                        className="flex min-w-0 flex-1 items-center gap-3 rounded-[15px] border border-white/10 bg-white/[0.05] p-3.5 transition hover:bg-white/[0.08]"
                      >
                        {body}
                      </CoachMissionEntry>
                    ) : (
                      // No topic means nothing to teach. A dead link into an
                      // empty Classroom is worse than a row that plainly is
                      // not one.
                      <div className="flex min-w-0 flex-1 items-center gap-3 rounded-[15px] border border-white/10 p-3.5 opacity-60">
                        {body}
                      </div>
                    )}
                    <button
                      type="button"
                      onClick={() => void finishSession(session.id)}
                      disabled={finishing === session.id}
                      className="shrink-0 rounded-[15px] border border-white/12 px-4 text-[13px] font-semibold text-white/75 transition hover:bg-white/[0.07] disabled:opacity-40"
                    >
                      {finishing === session.id ? (
                        <Loader2 className="h-4 w-4 animate-spin" aria-hidden />
                      ) : (
                        'Done'
                      )}
                    </button>
                  </li>
                );
              })}
            </ul>
          )}
        </section>
      </div>

      {planId && (
        <p className="text-xs text-white/30">
          Readiness is measured from what you have actually demonstrated, not from sessions
          ticked off.
        </p>
      )}
    </div>
  );
}
