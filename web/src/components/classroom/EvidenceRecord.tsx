'use client';

import { useEffect, useState } from 'react';
import { AlertTriangle, Check, HelpCircle, Lock } from 'lucide-react';
import { api } from '@/lib/api';
import type { ConceptRecord, LearnerRecord, RungRecord } from '@/types';
import {
  EVIDENCE_KINDS,
  conceptLabel,
  nextStepLabel,
  partitionRecordBySubject,
  rungClaim,
  stateHeadline,
} from '@/lib/learner-model.mjs';

/**
 * The learner's own record: what they have shown, on what, and what is left.
 *
 * WHY THIS EXISTS
 *
 * The backend has recorded, for every graded answer, which rung of the
 * evidence ladder the demonstration reached, a confidence damped by how much
 * help was needed, and the misconception the grader named. The learner was
 * shown none of it. They did the work and could not see what they had proven.
 *
 * WHAT IT MAY NOT DO
 *
 * Every line here is a claim about a person, made back to that person, so the
 * rules are strict:
 *
 *  - Nothing is computed from local state. Not answers counted this session,
 *    not lessons marked finished, not sliders moved. The only source is
 *    `/concepts/record`, which reads committed evidence.
 *  - A rung the server did not report is not drawn as reached. The ladder is
 *    shown in full so the learner can see the shape of what is ahead, but an
 *    unreached rung is explicitly locked, never dimmed in a way that could
 *    read as "done".
 *  - "Recognised" and "applied" never share a word. The distance between them
 *    is the product's central claim.
 *  - A failed read says so. An empty record means "you have not shown
 *    anything yet", which is a statement about the learner; a request that
 *    failed is not evidence for it, and `unavailable` keeps the two apart.
 *
 * WHY IT TAKES A SUBJECT
 *
 * `/concepts/record` is the learner's whole record, across every subject they
 * have ever worked on. Rendered unfiltered inside a marketing class it listed
 * long division beside customer segmentation, which reads as the teacher
 * having lost track of which lesson this is.
 *
 * So this class's own evidence leads, and the rest stays reachable one tap
 * away. Reachable, not removed: the other work is still the learner's, the
 * match is a rule about slugs rather than a fact the server asserted, and
 * anything it cannot place belongs where the learner can still see it. The
 * grouping is presentation only — no claim about a learner is computed here.
 */
export default function EvidenceRecord({ subjects = [] }: { subjects?: (string | null | undefined)[] }) {
  const [record, setRecord] = useState<LearnerRecord | null>(null);
  const [failed, setFailed] = useState(false);
  const [loading, setLoading] = useState(true);
  const [showingOthers, setShowingOthers] = useState(false);

  useEffect(() => {
    let live = true;
    (async () => {
      try {
        const result = await api.personalization.learnerRecord();
        if (live) setRecord(result);
      } catch {
        // A network failure is the same kind of not-knowing as the server's
        // own `unavailable`, and must not render as an empty record.
        if (live) setFailed(true);
      } finally {
        if (live) setLoading(false);
      }
    })();
    return () => { live = false; };
  }, []);

  if (loading) {
    return <p className="px-1 py-3 text-sm text-white/45">Reading your record…</p>;
  }

  if (failed || record?.unavailable) {
    return (
      <div className="flex items-start gap-2 rounded-xl border border-amber-400/25 bg-amber-400/10 px-3 py-2.5">
        <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0 text-amber-300" />
        <p className="text-[13px] leading-relaxed text-amber-100/90">
          Your record could not be loaded just now. This is not a reading of your
          work — nothing you have done has been lost.
        </p>
      </div>
    );
  }

  const concepts = record?.concepts ?? [];

  if (concepts.length === 0) {
    return (
      <p className="px-1 py-3 text-[13px] leading-relaxed text-white/45">
        Nothing recorded yet. Answering a checkpoint is what puts something here —
        this fills in from what you show, not from time spent.
      </p>
    );
  }

  const { inClass, elsewhere } = partitionRecordBySubject(concepts, ...subjects);
  // Without a subject to scope by there is one list, which is what this was
  // before. Never a silent empty panel because the scoping found nothing to
  // compare against.
  const scoped = subjects.some((subject) => (subject ?? '').trim().length > 0);

  return (
    <div className="space-y-3">
      <p className="text-[12px] leading-relaxed text-white/45">
        Read from what you actually demonstrated. Being taught something does not
        appear here; showing it does.
      </p>

      {!scoped && concepts.map((concept) => (
        <ConceptCard key={concept.concept_id} concept={concept} />
      ))}

      {scoped && (
        <>
          {inClass.length > 0 ? (
            inClass.map((concept) => (
              <ConceptCard key={concept.concept_id} concept={concept} />
            ))
          ) : (
            <p className="px-1 py-1 text-[13px] leading-relaxed text-white/45">
              Nothing from this class yet. Answering a checkpoint here is what
              puts something in this part of your record.
            </p>
          )}

          {elsewhere.length > 0 && (
            <div className="border-t border-white/10 pt-2.5">
              <button
                type="button"
                onClick={() => setShowingOthers((open) => !open)}
                aria-expanded={showingOthers}
                className="w-full text-left text-[12px] font-semibold text-white/50 hover:text-white/75"
              >
                {showingOthers ? 'Hide' : 'Show'} {elsewhere.length} from other subjects
              </button>
              {showingOthers && (
                <div className="mt-2.5 space-y-3">
                  {elsewhere.map((concept) => (
                    <ConceptCard key={concept.concept_id} concept={concept} />
                  ))}
                </div>
              )}
            </div>
          )}
        </>
      )}
    </div>
  );
}

function ConceptCard({ concept }: { concept: ConceptRecord }) {
  const reached = new Map<string, RungRecord>(
    concept.rungs.map((rung) => [rung.kind, rung]),
  );
  const nextStep = nextStepLabel(concept.next_rung);

  return (
    <section className="rounded-xl border border-white/10 bg-white/[0.03] p-3">
      <h4 className="text-[13.5px] font-bold text-white">
        {conceptLabel(concept.concept_id)}
      </h4>
      <p className="mt-0.5 text-[11.5px] font-semibold uppercase tracking-[0.08em] text-teal-300/90">
        {stateHeadline(concept.state)}
      </p>

      {/* The ladder ahead, so what is left is visible — with reached and
          unreached told apart by an icon and a word, never by opacity alone.
          `exposure` is shown only when it was actually recorded: drawing it
          as a locked row invites the reading that being taught something is
          an achievement to unlock, when it is the one rung on this ladder
          that proves nothing. It is never a target either — the server's
          `next_rung` skips it for the same reason. */}
      <ul className="mt-2.5 space-y-1">
        {EVIDENCE_KINDS.map((kind: string) => {
          const rung = reached.get(kind);
          if (!rung && kind === 'exposure') return null;
          const claim = rungClaim(kind);
          if (!claim) return null;
          return (
            <li key={kind} className="flex items-start gap-2 text-[12.5px]">
              {rung ? (
                <Check className="mt-[3px] h-3.5 w-3.5 shrink-0 text-emerald-300" strokeWidth={3} />
              ) : (
                <Lock className="mt-[3px] h-3.5 w-3.5 shrink-0 text-white/25" />
              )}
              <span className={rung ? 'text-white/85' : 'text-white/35'}>
                <span className="font-semibold">{claim.label}</span>
                {rung ? (
                  <>
                    {' — '}{claim.claim.toLowerCase()}
                    {!rung.unaided && (
                      <span className="text-amber-200/80"> (with help)</span>
                    )}
                  </>
                ) : (
                  <span className="text-white/30"> — not shown yet</span>
                )}
              </span>
            </li>
          );
        })}
      </ul>

      {concept.misconception && (
        <p className="mt-2.5 flex items-start gap-1.5 rounded-lg bg-white/[0.04] px-2 py-1.5 text-[12px] leading-relaxed text-white/65">
          <HelpCircle className="mt-[2px] h-3.5 w-3.5 shrink-0 text-accent-gold" />
          <span>
            <span className="font-semibold text-white/80">Worth a second look: </span>
            {concept.misconception}
          </span>
        </p>
      )}

      {nextStep && (
        <p className="mt-2 text-[12px] font-semibold text-lyo-300">{nextStep}</p>
      )}
    </section>
  );
}
