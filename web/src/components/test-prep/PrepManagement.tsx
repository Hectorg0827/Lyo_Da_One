'use client';

import { useState } from 'react';
import { Loader2 } from 'lucide-react';

import { api } from '@/lib/api';
import { cn } from '@/lib/utils';
import type { PrepSnapshot } from '@/lib/test-prep-api';

/**
 * Edit test details.
 *
 * This used to also own the full schedule and the materials list, both behind
 * collapsed `<details>` elements. They are now open cards of their own —
 * `ScheduleCard` and `MaterialsCard` — and what is left here is the one thing
 * that was always a form: the test's own facts.
 *
 * Open state belongs to the page now, so the pencil in the workspace header
 * is what reveals it; this component no longer draws its own toggle.
 *
 * Unchanged on purpose: the write still carries `expected_revision`, and a
 * save the server answers with `needs_plan` still regenerates the plan before
 * reloading. Those are the concurrency rules, not presentation.
 */

const inputClass =
  'mt-1 w-full rounded-xl border border-white/20 bg-slate-950 px-3 py-2.5 text-white outline-none transition focus-visible:border-lyo-400';

export function PrepManagement({
  snapshot,
  onSaved,
  open,
  onClose,
}: {
  snapshot: PrepSnapshot;
  onSaved: () => Promise<void>;
  open: boolean;
  onClose: () => void;
}) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const profile = snapshot.profile;

  if (!profile || !open) return null;

  return (
    <section className="rounded-[22px] border border-white/10 bg-gradient-to-br from-white/[0.06] to-white/[0.025] p-5 shadow-[0_6px_12px_rgba(0,0,0,0.18)] sm:p-6">
      <h2 className="font-rounded text-lg font-bold text-white">Test details</h2>
      {error && (
        <p role="alert" className="mt-3 text-sm text-amber-200">
          {error}
        </p>
      )}
      <form
        key={snapshot.revision}
        className="mt-4 grid gap-4 text-sm text-white/80 lg:grid-cols-2"
        onSubmit={async (event) => {
          event.preventDefault();
          if (busy) return;
          const data = new FormData(event.currentTarget);
          setBusy(true);
          setError(null);
          try {
            const result = await api.testPrep.editProfile(profile.id, {
              expected_revision: snapshot.revision,
              subject: String(data.get('subject')),
              test_date: String(data.get('date')),
              daily_minutes_available: Number(data.get('minutes')),
              study_days_per_week: Number(data.get('days')),
              timezone: String(data.get('timezone')),
              topics: String(data.get('topics'))
                .split('\n')
                .map((name) => name.trim())
                .filter(Boolean)
                .map((name) => profile.topics.find((t) => t.name === name) ?? { name, weight: 1, confidence: 5 }),
            });
            if (result.needs_plan) await api.testPrep.generatePlan(profile.id);
            onClose();
            await onSaved();
          } catch (err) {
            setError(err instanceof Error ? err.message : 'Could not save your changes.');
            await onSaved();
          } finally {
            setBusy(false);
          }
        }}
      >
        <p className="text-white/60 lg:col-span-2">
          Updating details rebuilds upcoming sessions. Your completed work stays in your record.
        </p>

        <label>
          Subject
          <input name="subject" required maxLength={100} defaultValue={profile.subject} className={inputClass} />
        </label>
        <label>
          Test date
          <input type="date" name="date" required defaultValue={profile.test_date} className={inputClass} />
        </label>

        <label className="lg:col-span-2">
          Topics — one per line
          <textarea
            name="topics"
            required
            rows={5}
            defaultValue={profile.topics.map((t) => t.name).join('\n')}
            className={inputClass}
          />
        </label>

        <label>
          Minutes per day
          <input
            type="number"
            name="minutes"
            min={5}
            max={480}
            required
            defaultValue={profile.daily_minutes_available}
            className={inputClass}
          />
        </label>
        <label>
          Days per week
          <input
            type="number"
            name="days"
            min={1}
            max={7}
            required
            defaultValue={profile.study_days_per_week}
            className={inputClass}
          />
        </label>

        <label className="lg:col-span-2">
          Study timezone
          <input name="timezone" required defaultValue={snapshot.timezone} className={inputClass} />
        </label>

        <div className="flex flex-wrap gap-3 lg:col-span-2">
          <button
            type="submit"
            disabled={busy}
            className={cn(
              'inline-flex min-h-[44px] items-center gap-2 rounded-2xl px-5 py-3',
              'bg-gradient-to-r from-lyo-600 to-lyo-400 font-semibold text-white',
              'shadow-lg shadow-lyo-600/25 transition hover:shadow-lyo-500/40 disabled:opacity-50',
            )}
          >
            {busy && <Loader2 className="h-4 w-4 animate-spin" aria-hidden />}
            {busy ? 'Saving your plan…' : 'Save and update schedule'}
          </button>
          <button
            type="button"
            onClick={onClose}
            disabled={busy}
            className="min-h-[44px] rounded-2xl border border-white/15 px-5 py-3 font-medium text-white/80 transition hover:bg-white/[0.07] disabled:opacity-50"
          >
            Cancel
          </button>
        </div>
      </form>
    </section>
  );
}
