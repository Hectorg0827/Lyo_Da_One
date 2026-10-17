'use client';

import { useId, useState } from 'react';
import { useRouter } from 'next/navigation';
import { motion, AnimatePresence, useReducedMotion } from 'framer-motion';
import {
  GraduationCap, CalendarClock, ArrowRight, SlidersHorizontal, ChevronDown,
  Check, Gauge, Timer, Languages, Target, MessageCircle, Sparkles,
} from 'lucide-react';
import {
  classroomEntryHref,
  testPrepEntryHref,
  CLASSROOM_LEVELS,
  SESSION_LENGTHS,
  CLASSROOM_LANGUAGES,
} from '@/lib/entry-contract.mjs';
import { routeLearningRequest, directLearningHref } from '@/lib/unified-entry.mjs';

/**
 * LYO's front door.
 *
 * What a first-time visitor used to get was a dashboard of their own
 * nothing: Level 1, 0 XP, 0 hours, 0 courses, empty recommendations, and a
 * greeting addressed to "Learner". A zero dashboard asks someone to admire an
 * empty account before it has given them anything.
 *
 * What they get instead is the one question the product is actually built to
 * answer, and a door into the Classroom. The Classroom is the demonstration:
 * nothing written here argues that LYO is more than a chatbot as well as
 * ninety seconds inside one does.
 *
 * Both CTAs land on real runtime paths:
 *  - "Enter Classroom" opens the live classroom on the typed topic. The
 *    classroom WebSocket accepts a null token, so a guest can be taught
 *    before being asked to register.
 *  - "I have a test" opens Chat with that opening turn, which the backend
 *    router resolves to its real TEST_PREP intent and which then asks for
 *    subject, date and materials.
 *
 * ── On the optional questions ────────────────────────────────────────────
 *
 * A topic alone does not say what kind of lesson to teach. "Teach me
 * fractions" is a different lesson for someone who has never seen a
 * denominator than for someone revising before an exam, and the backend has
 * always been able to tell the difference — `preferred_difficulty`,
 * `target_duration_minutes` and `language_code` all reach the teaching
 * prompt. Nothing was asking.
 *
 * They stay optional, and collapsed by default, because the fastest path to
 * being taught is still to type a topic and press Enter. A form that demands
 * four answers before it teaches anything is how a product stops being tried.
 *
 * See docs/CLASSROOM_ARCHITECTURE.md section 5.
 */

const EXAMPLES = [
  'AP Chemistry',
  'Spanish for my trip',
  'SQL for a job interview',
  'Teach me fractions',
];

/**
 * What the teacher is told to do, when the learner says why they are here.
 *
 * The objective is the Director's intent, so "pass a test" and "use it at
 * work" produce genuinely different lessons on the same topic. "Just learn it"
 * carries no objective, leaving the entry contract's own default in place.
 */
type Goal = { value: string; label: string; objective?: (topic: string) => string };

const GOALS: Goal[] = [
  { value: '', label: 'Just learn it' },
  { value: 'exam', label: 'Pass a test', objective: (t) => `Prepare for an exam on ${t}` },
  { value: 'apply', label: 'Use it at work', objective: (t) => `Apply ${t} to real work` },
  { value: 'basics', label: 'Understand the idea', objective: (t) => `Understand why ${t} works` },
];

export default function FrontDoor({ knownLearner = false }: { knownLearner?: boolean }) {
  const router = useRouter();
  const reduceMotion = useReducedMotion() === true;
  const panelId = useId();

  const [topic, setTopic] = useState('');
  const [tuning, setTuning] = useState(false);
  const [level, setLevel] = useState('');
  const [minutes, setMinutes] = useState<number | ''>('');
  const [language, setLanguage] = useState('auto');
  const [goal, setGoal] = useState('');

  /**
   * Two jobs, one card.
   *
   * To a first-time visitor this card *is* the product: it leads the page and
   * has to make the case, so it keeps the full headline and the sentence that
   * explains what "live teacher" means.
   *
   * To a learner who already has courses it sits below their own work, and its
   * only job is "start another one". The pitch is already won, so the pitch is
   * dropped: smaller heading, no body copy, tighter padding. On a phone that
   * is the difference between this card owning the first screen and it being
   * one tidy block under the courses the learner actually came back for.
   */
  const compact = knownLearner;

  const trimmed = topic.trim();
  const chosenObjective = GOALS.find((g) => g.value === goal)?.objective;
  // Count only answers that change the lesson, so the badge never claims the
  // learner tuned something they left alone.
  const tunedCount = [level, minutes !== '' ? 'm' : '', language !== 'auto' ? 'l' : '', goal]
    .filter(Boolean).length;

  const enterClassroom = () => {
    const href = classroomEntryHref({
      topic: trimmed,
      recordScope: 'unit',
      level: level || undefined,
      minutes: minutes === '' ? undefined : minutes,
      language,
      objective: chosenObjective ? chosenObjective(trimmed) : undefined,
    });
    if (!href) return;
    router.push(href);
  };

  const startTestPrep = () => {
    router.push(testPrepEntryHref());
  };

  // One input, one journey. A quick question stays in Chat; explicit teaching
  // opens Classroom; exam intake preserves the learner's complete wording.
  // The authoritative server interaction contract still handles the turn.
  const startWithLyo = () => {
    const route = routeLearningRequest(trimmed, {
      goal,
      level: level || undefined,
      minutes: minutes === '' ? undefined : minutes,
      language,
      objective: chosenObjective ? chosenObjective(trimmed) : undefined,
    });
    if (route) router.push(route.href);
  };

  return (
    <motion.section
      initial={reduceMotion ? false : { opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
      className={[
        'group/door relative overflow-hidden border border-white/[0.13]',
        'shadow-[0_30px_80px_-24px_rgba(49,16,120,0.85),0_2px_0_0_rgba(255,255,255,0.06)_inset]',
        compact
          ? 'rounded-[24px] p-4 sm:rounded-[28px] sm:p-6'
          : 'rounded-[28px] p-5 sm:rounded-[32px] sm:p-10',
      ].join(' ')}
      style={{ background: '#150d2e' }}
      aria-labelledby="front-door-heading"
    >
      {/* Depth, not decoration.
          A flat purple fill is what made this read as a template: one colour,
          one plane, nothing behind it. The card is a dark surface *lit* by the
          brand purple instead — a wash from the top-right, a cooler one from
          the lower-left, and a hairline of light along the top edge where a
          real surface would catch it. The two washes drift slowly, which is
          the only motion here; under reduced motion the light stays exactly
          where it is and simply stops moving. */}
      <div
        aria-hidden
        className="absolute inset-0 pointer-events-none"
        style={{
          background:
            'radial-gradient(120% 90% at 82% -10%, rgba(139,92,246,0.85) 0%, rgba(99,102,241,0.38) 38%, transparent 72%),'
            + 'radial-gradient(90% 70% at 0% 110%, rgba(20,184,166,0.20) 0%, transparent 62%)',
        }}
      />
      <div
        aria-hidden
        className="absolute inset-x-0 top-0 h-px pointer-events-none
          bg-gradient-to-r from-transparent via-white/45 to-transparent"
      />
      <motion.div
        aria-hidden
        className="absolute -right-16 -top-24 h-72 w-72 rounded-full bg-accent-violet/35 blur-[70px] pointer-events-none"
        animate={reduceMotion ? undefined : { x: [0, 22, 0], y: [0, 16, 0], opacity: [0.6, 1, 0.6] }}
        transition={{ duration: 13, repeat: Infinity, ease: 'easeInOut' }}
      />
      <motion.div
        aria-hidden
        className="absolute -left-20 -bottom-16 h-60 w-60 rounded-full bg-accent-teal/20 blur-[70px] pointer-events-none"
        animate={reduceMotion ? undefined : { x: [0, -16, 0], y: [0, -20, 0], opacity: [0.35, 0.7, 0.35] }}
        transition={{ duration: 17, repeat: Infinity, ease: 'easeInOut' }}
      />

      <div className="relative">
        <div className="flex items-center gap-2 text-[11px] font-bold uppercase tracking-[0.16em] text-white/65">
          <span className="relative flex h-1.5 w-1.5">
            {!reduceMotion && (
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-accent-teal opacity-75" />
            )}
            <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-accent-teal" />
          </span>
          {compact ? 'Explore with Lyo' : 'Your AI learning companion'}
        </div>

        <h1
          id="front-door-heading"
          className={[
            'mt-2 font-rounded font-extrabold leading-[1.05] tracking-[-0.02em] text-white',
            compact
              ? 'text-[21px] sm:text-[26px]'
              : 'mt-3 text-[30px] sm:text-[44px]',
          ].join(' ')}
        >
          {compact ? 'What would you like to do next?' : 'What would you like to explore today?'}
        </h1>

        {!compact && (
          <p className="mt-3 max-w-xl text-sm sm:text-base font-medium text-white/75">
            Ask anything, learn any subject, or prepare for your next exam. Lyo chooses the right tools while you stay in control.
          </p>
        )}

        <form
          className={[
            'flex flex-col sm:flex-row gap-2.5 sm:gap-3',
            compact ? 'mt-3.5' : 'mt-6',
          ].join(' ')}
          onSubmit={(e) => {
            e.preventDefault();
            startWithLyo();
          }}
        >
          <label htmlFor="front-door-topic" className="sr-only">
            What would you like to ask or learn?
          </label>
          <div className="relative flex-1 min-w-0">
            <input
              id="front-door-topic"
              value={topic}
              onChange={(e) => setTopic(e.target.value)}
              placeholder={compact
                ? 'Ask, learn, or prepare for a test'
                : 'Ask anything, learn a skill, or tell Lyo about your exam'}
              autoComplete="off"
              className={[
                'peer w-full rounded-2xl bg-black/30 border border-white/20',
                'text-white placeholder-white/45 outline-none backdrop-blur-md',
                'transition-all duration-200',
                'focus:border-white/55 focus:bg-black/40 focus:shadow-[0_0_0_4px_rgba(255,255,255,0.10)]',
                compact ? 'px-4 py-3.5 text-[15px]' : 'px-5 py-4 text-base',
              ].join(' ')}
            />
            {/* A thin accent that fills on focus — the field answering back. */}
            <span
              aria-hidden
              className="pointer-events-none absolute inset-x-5 bottom-[7px] h-px origin-left scale-x-0
                bg-gradient-to-r from-accent-teal via-white/70 to-transparent
                transition-transform duration-300 peer-focus:scale-x-100"
            />
          </div>
          <button
            type="submit"
            disabled={!trimmed}
            /* Before a topic is typed this is the first thing a visitor looks
               at, so it may not read as broken. Disabled it becomes a quiet
               outline that still says what it is; it fills in the moment
               there is something to teach. */
            className={[
              'group/cta shrink-0 inline-flex items-center justify-center gap-2 rounded-2xl',
              'font-bold transition-all duration-300',
              compact ? 'px-5 py-3.5 text-[15px]' : 'px-6 py-4 text-base',
              trimmed
                ? 'bg-white text-[#1b1035] shadow-[0_10px_34px_-8px_rgba(255,255,255,0.55)] '
                  + 'hover:scale-[1.02] hover:shadow-[0_16px_44px_-8px_rgba(255,255,255,0.7)] active:scale-95'
                : 'cursor-not-allowed border border-white/25 bg-white/[0.07] text-white/55',
            ].join(' ')}
          >
            <Sparkles size={18} />
            Continue with Lyo
            {trimmed && (
              <ArrowRight
                size={16}
                className="-ml-0.5 opacity-0 -translate-x-1 transition-all duration-200
                  group-hover/cta:opacity-100 group-hover/cta:translate-x-0"
              />
            )}
          </button>
        </form>
        <p className="mt-3 text-xs leading-relaxed text-white/60">
          Questions stay conversational. Lessons open the live Classroom. Exam requests use your
          study-planning tools. You can always choose a capability directly below.
        </p>

        {/* ── Suggestions ──
            One row that scrolls sideways, not a wrapping block. Four example
            chips wrapping to three lines on a phone was most of this card's
            height, and it grew every time an example was added. A single row
            costs one line whatever is in it, and the clipped chip at the right
            edge is what tells you to push it. */}
        <div
          className={[
            'no-scrollbar flex items-center gap-2 overflow-x-auto pb-0.5',
            compact ? 'mt-3' : 'mt-4',
          ].join(' ')}
        >
          <span className="shrink-0 text-xs font-medium text-white/50">Try</span>
          {EXAMPLES.map((example) => (
            <button
              key={example}
              type="button"
              onClick={() => setTopic(example)}
              className="shrink-0 whitespace-nowrap rounded-full border border-white/20 bg-white/10
                px-3 py-1.5 text-xs font-medium text-white/80 backdrop-blur-md
                transition-all duration-200 hover:bg-white/20 hover:text-white
                hover:border-white/40 active:scale-95"
            >
              {example}
            </button>
          ))}
        </div>

        {/* ── The options control ──
            Its own row, and shaped like a control rather than a fifth chip in
            a row of examples. Sitting among the suggestions it read as one
            more thing to tap in passing; here the chevron says it opens
            something and the badge says how much of it you have answered. */}
        <button
          type="button"
          onClick={() => setTuning((open) => !open)}
          aria-expanded={tuning}
          aria-controls={panelId}
          className={[
            'mt-3 inline-flex w-full items-center gap-2 rounded-2xl border px-4 py-3',
            'text-[13px] font-semibold backdrop-blur-md transition-colors duration-200 sm:w-auto',
            tuning
              ? 'border-white/40 bg-white/[0.16] text-white'
              : 'border-white/20 bg-white/[0.08] text-white/80 hover:border-white/35 hover:bg-white/[0.14] hover:text-white',
          ].join(' ')}
        >
          <SlidersHorizontal size={14} className="shrink-0" />
          Set level &amp; length
          {tunedCount > 0 && (
            <span className="rounded-full bg-white/90 px-1.5 text-[10px] font-bold tabular-nums text-[#1b1035]">
              {tunedCount}
            </span>
          )}
          <ChevronDown
            size={14}
            className={[
              'ml-auto shrink-0 text-white/55 transition-transform duration-300',
              tuning ? 'rotate-180' : '',
            ].join(' ')}
          />
        </button>

        {/* ── The optional questions ──
            Collapsed by default. Every control here changes what the server
            teaches; nothing is asked for the form's own sake. */}
        <AnimatePresence initial={false}>
          {tuning && (
            <motion.div
              id={panelId}
              key="tuning"
              initial={reduceMotion ? { opacity: 1 } : { height: 0, opacity: 0 }}
              animate={reduceMotion ? { opacity: 1 } : { height: 'auto', opacity: 1 }}
              exit={reduceMotion ? { opacity: 0 } : { height: 0, opacity: 0 }}
              transition={{ duration: 0.28, ease: [0.22, 1, 0.36, 1] }}
              className="overflow-hidden"
            >
              <div className="mt-4 rounded-3xl border border-white/[0.14] bg-black/30 p-5 backdrop-blur-md">
                <p className="text-xs font-medium text-white/55">
                  All optional — skip any of it and LYO works the rest out as it teaches.
                </p>

                {/* Two independent columns rather than a two-column grid: a
                    grid ties each row's height to the taller cell, so one
                    wrapped row of pills opens a hole beside it. */}
                <div className="mt-4 flex flex-col gap-5 sm:flex-row sm:gap-8">
                  <div className="flex min-w-0 flex-1 flex-col gap-5">
                  <Field icon={<Gauge size={13} />} label="How much do you already know?">
                    <Choice neutral active={level === ''} onClick={() => setLevel('')} label="Not sure" />
                    {CLASSROOM_LEVELS.map((option) => (
                      <Choice
                        key={option.value}
                        active={level === option.value}
                        onClick={() => setLevel(option.value)}
                        label={option.label}
                        hint={option.hint}
                      />
                    ))}
                  </Field>

                  <Field icon={<Target size={13} />} label="What is it for?">
                    {GOALS.map((option) => (
                      <Choice
                        key={option.label}
                        neutral={!option.value}
                        active={goal === option.value}
                        onClick={() => setGoal(option.value)}
                        label={option.label}
                      />
                    ))}
                  </Field>
                  </div>

                  <div className="flex min-w-0 flex-1 flex-col gap-5">
                  <Field icon={<Timer size={13} />} label="How long have you got?">
                    <Choice neutral active={minutes === ''} onClick={() => setMinutes('')} label="No limit" />
                    {SESSION_LENGTHS.map((value) => (
                      <Choice
                        key={value}
                        active={minutes === value}
                        onClick={() => setMinutes(value)}
                        label={`${value} min`}
                      />
                    ))}
                  </Field>

                  <Field icon={<Languages size={13} />} label="Teach me in">
                    {CLASSROOM_LANGUAGES.map((option) => (
                      <Choice
                        key={option.value}
                        neutral={option.value === 'auto'}
                        active={language === option.value}
                        onClick={() => setLanguage(option.value)}
                        label={option.label}
                      />
                    ))}
                  </Field>
                  </div>
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Direct entry is a real choice, never an obligation. Avoid a second
            search/input or a second Test Prep prompt on the same screen. */}
        <div className={['border-t border-white/15', compact ? 'mt-4 pt-4' : 'mt-6 pt-5'].join(' ')}>
          <p className="mb-3 text-xs font-semibold uppercase tracking-wider text-white/60">
            Or jump directly into
          </p>
          <div className="grid grid-cols-3 gap-2 sm:gap-3">
            <button type="button"
              onClick={() => router.push(directLearningHref('chat', trimmed) || '/chat')}
              className="flex min-w-0 flex-col items-start gap-2 rounded-2xl border border-white/20 bg-white/[0.08] p-3 text-left transition hover:bg-white/[0.16] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white"
            >
              <MessageCircle size={19} className="text-violet-200" aria-hidden="true" />
              <span className="font-semibold text-sm text-white">AI Chat</span>
              <span className="text-[11px] leading-snug text-white/60">Ask anything</span>
            </button>
            <button type="button"
              onClick={() => trimmed ? enterClassroom() : router.push('/classroom')}
              className="flex min-w-0 flex-col items-start gap-2 rounded-2xl border border-white/20 bg-white/[0.08] p-3 text-left transition hover:bg-white/[0.16] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white"
            >
              <GraduationCap size={19} className="text-violet-200" aria-hidden="true" />
              <span className="font-semibold text-sm text-white">Classroom</span>
              <span className="text-[11px] leading-snug text-white/60">Learn deeply</span>
            </button>
            <button type="button"
              onClick={startTestPrep}
              className="flex min-w-0 flex-col items-start gap-2 rounded-2xl border border-[#F59E0B]/35 bg-[#F59E0B]/[0.12] p-3 text-left transition hover:bg-[#F59E0B]/[0.20] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white"
            >
              <CalendarClock size={19} className="text-[#FBBF24]" aria-hidden="true" />
              <span className="font-semibold text-sm text-white">I have a test</span>
              <span className="text-[11px] leading-snug text-white/60">Get exam-ready</span>
            </button>
          </div>
        </div>
      </div>
    </motion.section>
  );
}

/** One labelled group of choices. */
function Field({
  icon, label, children,
}: { icon: React.ReactNode; label: string; children: React.ReactNode }) {
  return (
    <fieldset>
      <legend className="mb-2 flex items-center gap-1.5 text-[12.5px] font-bold text-white/90">
        <span className="text-white/50">{icon}</span>
        {label}
      </legend>
      <div className="flex flex-wrap gap-1.5">{children}</div>
    </fieldset>
  );
}

/**
 * A selectable pill.
 *
 * Selection is carried by a check, a filled background and a border — not by
 * colour alone, so it survives a monochrome display and colour blindness.
 *
 * `neutral` marks the option that means "I did not answer this" — "Not sure",
 * "No limit", "Match my topic". Those start selected, and styling them like
 * a real answer put four bright white blocks on the panel announcing four
 * decisions the learner had not made. They are shown as current but quiet,
 * so the only loud pills are the ones somebody actually chose.
 */
function Choice({
  active, onClick, label, hint, neutral = false,
}: {
  active: boolean; onClick: () => void; label: string; hint?: string; neutral?: boolean;
}) {
  const style = !active
    ? 'border-white/[0.18] bg-white/[0.04] text-white/70 hover:bg-white/[0.12] hover:text-white hover:border-white/35'
    : neutral
      ? 'border-white/35 bg-white/[0.14] text-white'
      : 'border-white bg-white text-[#1b1035] shadow-[0_6px_18px_-6px_rgba(255,255,255,0.65)]';

  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={active}
      title={hint}
      className={[
        'inline-flex min-h-[38px] items-center gap-1.5 rounded-xl border px-3 py-1.5',
        'text-[12.5px] font-semibold transition-all duration-150 active:scale-95',
        style,
      ].join(' ')}
    >
      {active && !neutral && <Check size={12} strokeWidth={3} />}
      {label}
    </button>
  );
}
