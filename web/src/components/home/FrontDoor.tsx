'use client';

import { useId, useState } from 'react';
import { useRouter } from 'next/navigation';
import { motion, AnimatePresence, useReducedMotion } from 'framer-motion';
import {
  GraduationCap, CalendarClock, ArrowRight, SlidersHorizontal,
  Check, Gauge, Timer, Languages, Target,
} from 'lucide-react';
import {
  classroomEntryHref,
  testPrepEntryHref,
  CLASSROOM_LEVELS,
  SESSION_LENGTHS,
  CLASSROOM_LANGUAGES,
} from '@/lib/entry-contract.mjs';

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

  const trimmed = topic.trim();
  const chosenObjective = GOALS.find((g) => g.value === goal)?.objective;
  // Count only answers that change the lesson, so the badge never claims the
  // learner tuned something they left alone.
  const tunedCount = [level, minutes !== '' ? 'm' : '', language !== 'auto' ? 'l' : '', goal]
    .filter(Boolean).length;

  const enterClassroom = () => {
    const href = classroomEntryHref({
      topic: trimmed,
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

  return (
    <motion.section
      initial={reduceMotion ? false : { opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
      className="group/door relative overflow-hidden rounded-[32px]
        border border-white/[0.13] p-6 sm:p-10
        shadow-[0_30px_80px_-24px_rgba(49,16,120,0.85),0_2px_0_0_rgba(255,255,255,0.06)_inset]"
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
          A live teacher, not a playlist
        </div>

        <h1
          id="front-door-heading"
          className="mt-3 font-rounded text-[32px] sm:text-[44px] font-extrabold leading-[1.05] tracking-[-0.02em] text-white"
        >
          What do you want to learn?
        </h1>

        <p className="mt-3 max-w-xl text-sm sm:text-base font-medium text-white/75">
          LYO teaches you live, checks what you understand, adapts when you&apos;re stuck,
          and remembers what you&apos;ve mastered.
        </p>

        <form
          className="mt-6 flex flex-col sm:flex-row gap-3"
          onSubmit={(e) => {
            e.preventDefault();
            enterClassroom();
          }}
        >
          <label htmlFor="front-door-topic" className="sr-only">
            What do you want to learn?
          </label>
          <div className="relative flex-1 min-w-0">
            <input
              id="front-door-topic"
              value={topic}
              onChange={(e) => setTopic(e.target.value)}
              placeholder="Anything — a subject, a skill, a chapter you're stuck on"
              autoComplete="off"
              className="peer w-full rounded-2xl bg-black/30 border border-white/20 px-5 py-4
                text-base text-white placeholder-white/45 outline-none backdrop-blur-md
                transition-all duration-200
                focus:border-white/55 focus:bg-black/40 focus:shadow-[0_0_0_4px_rgba(255,255,255,0.10)]"
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
              'group/cta shrink-0 inline-flex items-center justify-center gap-2 rounded-2xl px-6 py-4',
              'text-base font-bold transition-all duration-300',
              trimmed
                ? 'bg-white text-[#1b1035] shadow-[0_10px_34px_-8px_rgba(255,255,255,0.55)] '
                  + 'hover:scale-[1.02] hover:shadow-[0_16px_44px_-8px_rgba(255,255,255,0.7)] active:scale-95'
                : 'cursor-not-allowed border border-white/25 bg-white/[0.07] text-white/55',
            ].join(' ')}
          >
            <GraduationCap size={18} />
            Enter Classroom
            {trimmed && (
              <ArrowRight
                size={16}
                className="-ml-0.5 opacity-0 -translate-x-1 transition-all duration-200
                  group-hover/cta:opacity-100 group-hover/cta:translate-x-0"
              />
            )}
          </button>
        </form>

        <div className="mt-4 flex flex-wrap items-center gap-2">
          <span className="text-xs font-medium text-white/50">Try</span>
          {EXAMPLES.map((example) => (
            <button
              key={example}
              type="button"
              onClick={() => setTopic(example)}
              className="rounded-full border border-white/20 bg-white/10 px-3 py-1.5
                text-xs font-medium text-white/80 backdrop-blur-md
                transition-all duration-200 hover:bg-white/20 hover:text-white
                hover:border-white/40 hover:-translate-y-0.5 active:scale-95"
            >
              {example}
            </button>
          ))}

          <button
            type="button"
            onClick={() => setTuning((open) => !open)}
            aria-expanded={tuning}
            aria-controls={panelId}
            className="inline-flex items-center gap-1.5 rounded-full border border-white/20 sm:ml-auto
              bg-white/10 px-3 py-1.5 text-xs font-semibold text-white/80 backdrop-blur-md
              transition-colors hover:bg-white/20 hover:text-white"
          >
            <SlidersHorizontal size={13} />
            {tuning ? 'Hide options' : 'Set level & length'}
            {tunedCount > 0 && !tuning && (
              <span className="rounded-full bg-white/90 px-1.5 text-[10px] font-bold text-[#1b1035]">
                {tunedCount}
              </span>
            )}
          </button>
        </div>

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

        <div className="mt-6 pt-5 border-t border-white/15">
          <button
            type="button"
            onClick={startTestPrep}
            className="group/test inline-flex items-center gap-2 rounded-2xl border border-white/25 bg-white/10
              px-5 py-3 text-sm font-semibold text-white backdrop-blur-md
              transition-all duration-200 hover:bg-white/20 hover:border-white/40 active:scale-95"
          >
            <CalendarClock size={16} />
            I have a test
            <ArrowRight
              size={15}
              className="opacity-70 transition-transform duration-200 group-hover/test:translate-x-0.5"
            />
          </button>
          <p className="mt-2 text-xs text-white/55">
            {knownLearner
              ? 'Bring the date and your notes — LYO builds the plan around what you already know.'
              : 'Bring the date and your notes. LYO finds what you already know and what you don’t.'}
          </p>
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
