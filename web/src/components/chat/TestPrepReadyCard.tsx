'use client';

import Link from 'next/link';
import { CalendarClock, ArrowRight, Play } from 'lucide-react';
import type { TestPrepHandoff } from '@/types';
import { sessionEntryHref } from '@/lib/test-prep.mjs';

/**
 * The handoff from Chat into Test Prep.
 *
 * The intake gathers the test details correctly and then the reply said "Open
 * Test Prep" with nothing to open — the words were body text, the link was
 * invisible, and the sentence appeared twice. This is the affordance that
 * sentence was promising.
 *
 * Two actions, because they are different intentions. **Open Test Prep** is
 * for seeing the schedule and what it is built on. **Start now** is for the
 * learner who wants to begin, and goes straight into the Classroom on the
 * soonest unfinished session — through the same `sessionEntryHref` the Test
 * Prep page uses, so a session opened from Chat teaches exactly what it would
 * have taught opened from there.
 *
 * WHAT IT MAY NOT DO
 *
 * It renders only from the server's handoff, which is sent only once a plan
 * exists. It never reads the reply text: matching on a sentence is how a
 * client ends up offering to start a plan that was never built.
 *
 * "Start now" is shown only when the server named a session with a topic. A
 * session with nothing to teach cannot open a Classroom, so offering it would
 * be a button that goes nowhere — the plan is still shown, and only the start
 * is withheld.
 */
export default function TestPrepReadyCard({ handoff }: { handoff: TestPrepHandoff }) {
  const startHref = handoff.next_session ? sessionEntryHref(handoff.next_session) : null;
  const testPrepHref = handoff.path || '/test-prep';

  return (
    <section
      className="mt-3 rounded-2xl border border-accent-teal/25 bg-accent-teal/[0.07] p-4"
      aria-label={`${handoff.subject} study plan`}
    >
      <div className="flex items-start gap-2.5">
        <CalendarClock size={16} className="mt-0.5 shrink-0 text-accent-teal" />
        <div className="min-w-0">
          <h3 className="text-[14px] font-bold text-white">
            {handoff.subject} study plan
          </h3>
          <p className="mt-0.5 text-[12.5px] leading-relaxed text-white/60">
            {handoff.next_session
              ? <>Next up: <span className="text-white/85">{handoff.next_session.topic}</span></>
              : 'Your schedule is saved.'}
          </p>
        </div>
      </div>

      <div className="mt-3.5 flex flex-wrap gap-2">
        {startHref && (
          <Link
            href={startHref}
            className="inline-flex min-h-[40px] items-center gap-1.5 rounded-xl bg-white px-4
              text-[13px] font-bold text-[#1b1035] transition-transform
              hover:scale-[1.02] active:scale-95"
          >
            <Play size={13} fill="currentColor" />
            Start now
          </Link>
        )}
        <Link
          href={testPrepHref}
          className="inline-flex min-h-[40px] items-center gap-1.5 rounded-xl border border-white/20
            bg-white/5 px-4 text-[13px] font-semibold text-white/85
            transition-colors hover:bg-white/15 hover:text-white"
        >
          Open Test Prep
          <ArrowRight size={13} className="opacity-70" />
        </Link>
      </div>
    </section>
  );
}
